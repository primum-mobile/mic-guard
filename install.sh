#!/bin/bash
# Install mic-guard as a login agent. Any arguments are passed to mic-guard,
# e.g.: ./install.sh --prefer "Shure MV7" --allow "AirPods"
set -euo pipefail

cd "$(dirname "$0")"
LABEL="local.mic-guard"
PREFIX="${PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin/mic-guard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/mic-guard.log"

[ -x build/mic-guard ] || make build

mkdir -p "$PREFIX/bin" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
install -m 755 build/mic-guard "$BIN"

xml_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' <<<"$1"; }
ARGS_XML="        <string>$(xml_escape "$BIN")</string>"
for arg in "$@"; do
    ARGS_XML+=$'\n'"        <string>$(xml_escape "$arg")</string>"
done

cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
$ARGS_XML
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "mic-guard installed and running."
echo "  binary: $BIN"
echo "  log:    $LOG"
echo "Input devices (* = current):"
"$BIN" --list
