// mic-guard — keep Bluetooth devices from hijacking your microphone on macOS.
//
// When a Bluetooth speaker or headset connects, macOS makes it the default
// input, which also drops its playback to low-quality call audio. mic-guard
// watches the default input device and, the moment a Bluetooth device takes
// over, switches back to your preferred microphone (or the built-in one).
//
// Event-driven via CoreAudio property listeners: no polling, no microphone
// access, no network.
//
// Usage: mic-guard [--prefer NAME]... [--allow NAME]... [--list] [--version]
//   --prefer NAME  Microphone to switch back to (substring, case-insensitive).
//                  Repeat for a fallback order; the built-in mic is the last resort.
//   --allow NAME   Bluetooth device that may stay the input (e.g. "AirPods").
//   --list         Print input devices and exit.
//
// SPDX-License-Identifier: MIT
import CoreAudio
import Foundation

let version = "1.0.0"
let system = AudioObjectID(kAudioObjectSystemObject)

// MARK: - CoreAudio helpers

func addr(_ selector: AudioObjectPropertySelector,
          _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                               mElement: kAudioObjectPropertyElementMain)
}

func allDevices() -> [AudioDeviceID] {
    var a = addr(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &a, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
}

func transport(_ d: AudioDeviceID) -> UInt32 {
    var a = addr(kAudioDevicePropertyTransportType)
    var t: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(d, &a, 0, nil, &size, &t)
    return t
}

func hasInput(_ d: AudioDeviceID) -> Bool {
    var a = addr(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput)
    var size: UInt32 = 0
    return AudioObjectGetPropertyDataSize(d, &a, 0, nil, &size) == noErr && size > 0
}

func name(_ d: AudioDeviceID) -> String {
    var a = addr(kAudioObjectPropertyName)
    var n: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(d, &a, 0, nil, &size, &n) == noErr, let s = n else { return "?" }
    return s.takeRetainedValue() as String
}

func defaultInput() -> AudioDeviceID {
    var a = addr(kAudioHardwarePropertyDefaultInputDevice)
    var d: AudioDeviceID = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    AudioObjectGetPropertyData(system, &a, 0, nil, &size, &d)
    return d
}

func setDefaultInput(_ d: AudioDeviceID) -> OSStatus {
    var a = addr(kAudioHardwarePropertyDefaultInputDevice)
    var id = d
    return AudioObjectSetPropertyData(system, &a, 0, nil,
                                      UInt32(MemoryLayout<AudioDeviceID>.size), &id)
}

func isBluetooth(_ d: AudioDeviceID) -> Bool {
    let t = transport(d)
    return t == kAudioDeviceTransportTypeBluetooth || t == kAudioDeviceTransportTypeBluetoothLE
}

func transportLabel(_ d: AudioDeviceID) -> String {
    switch transport(d) {
    case kAudioDeviceTransportTypeBuiltIn: return "built-in"
    case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "bluetooth"
    case kAudioDeviceTransportTypeUSB: return "usb"
    case kAudioDeviceTransportTypeVirtual: return "virtual"
    case kAudioDeviceTransportTypeAggregate: return "aggregate"
    default: return "other"
    }
}

func log(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    print("\(stamp) \(message)")
    fflush(stdout)
}

// MARK: - Arguments

var prefer: [String] = []
var allow: [String] = []
var args = CommandLine.arguments.dropFirst()
while let arg = args.popFirst() {
    switch arg {
    case "--prefer", "--allow":
        guard let value = args.popFirst() else {
            FileHandle.standardError.write("mic-guard: \(arg) needs a device name\n".data(using: .utf8)!)
            exit(2)
        }
        if arg == "--prefer" { prefer.append(value.lowercased()) } else { allow.append(value.lowercased()) }
    case "--list":
        let current = defaultInput()
        for d in allDevices() where hasInput(d) {
            print("\(d == current ? "*" : " ") \(name(d))  [\(transportLabel(d))]")
        }
        exit(0)
    case "--version":
        print("mic-guard \(version)")
        exit(0)
    case "-h", "--help":
        print("""
        mic-guard \(version) — keep Bluetooth devices from taking over your microphone.

        Usage: mic-guard [--prefer NAME]... [--allow NAME]... [--list]
          --prefer NAME  Microphone to switch back to (substring match). Repeatable.
          --allow NAME   Bluetooth device allowed to stay the input. Repeatable.
          --list         Show input devices (* = current default) and exit.
        """)
        exit(0)
    default:
        FileHandle.standardError.write("mic-guard: unknown option \(arg) (try --help)\n".data(using: .utf8)!)
        exit(2)
    }
}

// MARK: - Guard

func matches(_ d: AudioDeviceID, _ patterns: [String]) -> Bool {
    let n = name(d).lowercased()
    return patterns.contains { n.contains($0) }
}

func fallbackMic(among devices: [AudioDeviceID]) -> AudioDeviceID? {
    let inputs = devices.filter { hasInput($0) && !isBluetooth($0) }
    for pattern in prefer {
        if let d = inputs.first(where: { name($0).lowercased().contains(pattern) }) { return d }
    }
    return inputs.first { transport($0) == kAudioDeviceTransportTypeBuiltIn }
}

func enforce() {
    let current = defaultInput()
    guard current != 0, isBluetooth(current), !matches(current, allow) else { return }
    guard let target = fallbackMic(among: allDevices()) else {
        log("\(name(current)) took the input, but no non-Bluetooth microphone is available")
        return
    }
    let status = setDefaultInput(target)
    log(status == noErr
        ? "\(name(current)) -> \(name(target))"
        : "failed to switch \(name(current)) -> \(name(target)) (OSStatus \(status))")
}

let queue = DispatchQueue(label: "mic-guard")
for selector in [kAudioHardwarePropertyDefaultInputDevice, kAudioHardwarePropertyDevices] {
    var a = addr(selector)
    AudioObjectAddPropertyListenerBlock(system, &a, queue) { _, _ in enforce() }
}
queue.async { enforce() }
dispatchMain()
