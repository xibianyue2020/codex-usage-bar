# Codex Usage Bar

[简体中文](README.md)

A macOS menu bar utility that shows the remaining Codex 5-hour and weekly usage, along with their reset times.

## Features

- Shows the remaining 5-hour and weekly usage percentages in the menu bar.
- Click the item to see each usage window, reset time, and last update time.
- Refreshes every 60 seconds, with a manual refresh option.
- Reads usage through the local `codex app-server` `account/rateLimits/read` method. It does not read, copy, or store authentication tokens.
- Can run as a macOS login item and includes an optional Codex session-start hook.

## Requirements

- macOS
- Xcode Command Line Tools (`xcrun swiftc`)
- The Codex CLI installed and signed in, with `codex` available in your shell `PATH`

## Install

Run this from the repository directory:

```bash
bash scripts/install.sh
```

The script builds the menu bar app and registers it as a login item for the current macOS user. The app appears in the macOS menu bar, outside the Codex window.

To also launch it when a Codex session starts, install this directory as a local plugin. Codex will ask you to review and trust the plugin hook. The login item and plugin hook can be enabled together; the app avoids launching a duplicate process.

## Uninstall

```bash
bash scripts/uninstall.sh
```

This stops the app and removes its login item. The compiled app and logs remain in `~/Library/Application Support/CodexUsageBar`; remove that directory separately if you want a full cleanup.

## License

[MIT License](LICENSE)
