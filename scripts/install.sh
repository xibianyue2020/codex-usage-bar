#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$HOME/Library/Application Support/CodexUsageBar"
AGENT_DIR="$HOME/Library/LaunchAgents"
LABEL="com.local.codex-usage-bar"
APP="$DATA_DIR/CodexUsageBar"
PLIST="$AGENT_DIR/$LABEL.plist"
CODEX_CLI="$(command -v codex || true)"

if [[ -z "$CODEX_CLI" ]]; then
  echo 'Codex CLI was not found. Install or expose codex in PATH, then retry.' >&2
  exit 1
fi

mkdir -p "$DATA_DIR" "$AGENT_DIR"
/usr/bin/xcrun swiftc -O -framework AppKit -framework Foundation "$PLUGIN_ROOT/app/CodexUsageBar.swift" -o "$APP"

cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$APP</string></array>
  <key>EnvironmentVariables</key><dict><key>CODEX_CLI</key><string>$CODEX_CLI</string></dict>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$DATA_DIR/stdout.log</string>
  <key>StandardErrorPath</key><string>$DATA_DIR/stderr.log</string>
</dict>
</plist>
PLIST_EOF

/bin/launchctl bootout "gui/$(/usr/bin/id -u)" "$PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$PLIST"
echo "Codex Usage Bar is installed and running in the macOS menu bar."
