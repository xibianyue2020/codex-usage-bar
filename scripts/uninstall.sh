#!/bin/bash
set -euo pipefail

LABEL="com.local.codex-usage-bar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DATA_DIR="$HOME/Library/Application Support/CodexUsageBar"

if [[ -f "$PLIST" ]]; then
  /bin/launchctl bootout "gui/$(/usr/bin/id -u)" "$PLIST" >/dev/null 2>&1 || true
  /bin/rm -f "$PLIST"
fi
/usr/bin/pkill -f "$DATA_DIR/CodexUsageBar" >/dev/null 2>&1 || true
echo "Codex Usage Bar has been removed from login items. App files remain at: $DATA_DIR"
