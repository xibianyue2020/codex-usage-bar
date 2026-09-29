#!/bin/bash
set -euo pipefail

LABEL="com.local.codex-usage-bar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DATA_DIR="$HOME/Library/Application Support/CodexUsageBar"
APP="$HOME/Applications/Codex Usage Bar.app"
USER_ID="$(/usr/bin/id -u)"

if [[ -f "$PLIST" ]]; then
  /bin/launchctl bootout "gui/$USER_ID" "$PLIST" >/dev/null 2>&1 || true
  /bin/rm -f "$PLIST"
fi
for PID in $(/usr/bin/pgrep -x CodexUsageBar || true); do
  OWNER="$(/bin/ps -p "$PID" -o uid= | /usr/bin/tr -d '[:space:]')"
  if [[ "$OWNER" == "$USER_ID" ]]; then /bin/kill -TERM "$PID" >/dev/null 2>&1 || true; fi
done
if [[ -d "$APP" ]]; then
  /bin/rm -rf "$APP"
fi
echo "Codex Usage Bar has been removed from login items. Logs and support files remain at: $DATA_DIR"
