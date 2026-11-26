#!/bin/bash
# Stop mic-guard and remove the login agent and binary.
set -euo pipefail

LABEL="local.mic-guard"
PREFIX="${PREFIX:-$HOME/.local}"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist" "$PREFIX/bin/mic-guard"
echo "mic-guard removed. (Log left at ~/Library/Logs/mic-guard.log)"
