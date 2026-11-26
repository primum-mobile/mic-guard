# mic-guard

**Stop Bluetooth speakers and headsets from hijacking your microphone on macOS.**

Connect a Bluetooth speaker and macOS quietly makes it your microphone. Your
dictation, voice-coding tool or call suddenly listens through a tinny speakerphone
mic across the room — and the speaker's playback drops to low-quality call audio
while it's in use.

macOS has no setting to say "never use this device as an input". mic-guard adds
one: a tiny background agent that switches the input straight back to your real
microphone the moment a Bluetooth device takes over.

Made for people who talk to their computer all day: dictation, voice coding,
speech-to-text, podcasting, calls.

```
2026-11-26T18:20:41Z magic animal -> MacBook Air Microphone
```

## How it works

- Listens for CoreAudio "default input changed" and "devices changed" events —
  no polling, zero CPU while idle.
- If the new default input is a Bluetooth device, it sets the default input back
  to your preferred mic (or the built-in one).
- Never opens or records from any microphone, never touches the network, runs as
  your user (no admin rights). Under 200 lines of Swift — read it in
  [`Sources/main.swift`](Sources/main.swift).

## Install

Requires macOS 11+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/primum-mobile/mic-guard.git
cd mic-guard
./install.sh
```

This builds mic-guard for your Mac (Apple silicon or Intel), installs it to `~/.local/bin/mic-guard` and starts
it as a login agent.

### Options

Pass options to `./install.sh` (run it again any time to change them):

```bash
# Switch back to your USB mic instead of the built-in one (falls back to built-in)
./install.sh --prefer "Shure MV7"

# Several in order of preference
./install.sh --prefer "Yeti" --prefer "MacBook"

# Let a Bluetooth headset stay the input (e.g. for calls on AirPods)
./install.sh --allow "AirPods"
```

Names are case-insensitive substrings. See your device names with:

```bash
~/.local/bin/mic-guard --list
```

## Uninstall

```bash
./uninstall.sh
```

## Notes

- Only the **system default** input is managed. An app with a specific mic
  chosen in its own settings (Zoom, OBS, …) is unaffected.
- There can be a brief moment of call-quality audio as a speaker connects, before
  the switch back. If playback still sounds thin afterwards, reconnect the speaker
  once.
- Continuity (iPhone) microphones are not Bluetooth audio devices and are left alone.
- Log: `~/Library/Logs/mic-guard.log`.

## License

MIT
