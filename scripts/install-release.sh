#!/bin/bash
set -euo pipefail

APP_SOURCE="${1:-$(cd "$(dirname "$0")/.." && pwd)/Codex Usage Bar.app}"
APP_DIR="$HOME/Applications"
APP="$APP_DIR/Codex Usage Bar.app"
LABEL="com.local.codex-usage-bar"
AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST="$AGENT_DIR/$LABEL.plist"
DATA_DIR="$HOME/Library/Application Support/CodexUsageBar"
USER_ID="$(/usr/bin/id -u)"

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "App bundle not found: $APP_SOURCE" >&2
  exit 1
fi

CODEX_CLI="$(command -v codex || true)"
if [[ -z "$CODEX_CLI" ]]; then
  for candidate in \
    "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex" \
    "$HOME/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex" \
    "/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"; do
    if [[ -x "$candidate" ]]; then CODEX_CLI="$candidate"; break; fi
  done
fi

if [[ -z "$CODEX_CLI" ]]; then
  echo 'Codex CLI was not found. Install Codex or make `codex` available in PATH, then retry.' >&2
  exit 1
fi

# Stop the login item and any copy launched directly from a mounted disk image.
/bin/launchctl bootout "gui/$USER_ID" "$PLIST" >/dev/null 2>&1 || true
for PID in $(/usr/bin/pgrep -x CodexUsageBar || true); do
  OWNER="$(/bin/ps -p "$PID" -o uid= | /usr/bin/tr -d '[:space:]')"
  if [[ "$OWNER" == "$USER_ID" ]]; then /bin/kill -TERM "$PID" >/dev/null 2>&1 || true; fi
done
/bin/sleep 1

mkdir -p "$APP_DIR" "$AGENT_DIR" "$DATA_DIR"
rm -rf "$APP"
ditto "$APP_SOURCE" "$APP"

cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$APP/Contents/MacOS/CodexUsageBar</string></array>
  <key>EnvironmentVariables</key><dict><key>CODEX_CLI</key><string>$CODEX_CLI</string></dict>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$DATA_DIR/stdout.log</string>
  <key>StandardErrorPath</key><string>$DATA_DIR/stderr.log</string>
</dict>
</plist>
PLIST_EOF

/bin/launchctl bootstrap "gui/$USER_ID" "$PLIST"
echo 'Codex Usage Bar is installed and running. It will start automatically at login.'
