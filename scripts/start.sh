#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="$HOME/Library/Application Support/CodexUsageBar"
APP="$DATA_DIR/CodexUsageBar"
SOURCE="$PLUGIN_ROOT/app/CodexUsageBar.swift"

mkdir -p "$DATA_DIR"
if [[ ! -x "$APP" || "$SOURCE" -nt "$APP" ]]; then
  /usr/bin/xcrun swiftc -O -framework AppKit -framework Foundation "$SOURCE" -o "$APP"
fi

if ! /usr/bin/pgrep -f "$APP" >/dev/null 2>&1; then
  CODEX_CLI="$(command -v codex || true)"
  if [[ -n "$CODEX_CLI" ]]; then
    CODEX_CLI="$CODEX_CLI" nohup "$APP" >/dev/null 2>&1 &
  else
    nohup "$APP" >/dev/null 2>&1 &
  fi
fi
