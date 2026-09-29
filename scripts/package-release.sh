#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.2}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must use MAJOR.MINOR.PATCH format: $VERSION" >&2
  exit 1
fi
BUILD_DIR="$ROOT/.build/release-$VERSION"
DIST_DIR="$ROOT/dist"
APP="$BUILD_DIR/Codex Usage Bar.app"
DMG_ROOT="$BUILD_DIR/dmg-root"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
SOURCE="$ROOT/app/CodexUsageBar.swift"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/bin" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DMG_ROOT/scripts" "$DIST_DIR"

for ARCH in arm64 x86_64; do
  xcrun swiftc -O -sdk "$SDK" -target "$ARCH-apple-macos13.0" \
    -framework AppKit -framework Foundation "$SOURCE" \
    -o "$BUILD_DIR/bin/CodexUsageBar-$ARCH"
done
/usr/bin/lipo -create "$BUILD_DIR/bin/CodexUsageBar-arm64" "$BUILD_DIR/bin/CodexUsageBar-x86_64" \
  -output "$APP/Contents/MacOS/CodexUsageBar"
chmod 755 "$APP/Contents/MacOS/CodexUsageBar"

cat > "$APP/Contents/Info.plist" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>CodexUsageBar</string>
  <key>CFBundleIdentifier</key><string>com.local.codex-usage-bar</string>
  <key>CFBundleName</key><string>Codex Usage Bar</string>
  <key>CFBundleDisplayName</key><string>Codex Usage Bar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST_EOF
/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP"

ditto "$APP" "$DMG_ROOT/Codex Usage Bar.app"
cp "$ROOT/scripts/install-release.sh" "$DMG_ROOT/scripts/"
cp "$ROOT/scripts/uninstall.sh" "$DMG_ROOT/scripts/"
cat > "$DMG_ROOT/安装 Codex Usage Bar.command" <<'INSTALL_EOF'
#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/scripts/install-release.sh" "$HERE/Codex Usage Bar.app"
echo
read -r -p '按回车关闭此窗口…' _
INSTALL_EOF
cat > "$DMG_ROOT/卸载 Codex Usage Bar.command" <<'UNINSTALL_EOF'
#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/scripts/uninstall.sh"
echo
read -r -p '按回车关闭此窗口…' _
UNINSTALL_EOF
cat > "$DMG_ROOT/安装说明.txt" <<'GUIDE_EOF'
Codex Usage Bar 安装说明

1. 双击“安装 Codex Usage Bar.command”。
2. 如果 macOS 阻止打开，按住 Control 点按该文件，选择“打开”，再确认一次。
3. 如安装后菜单栏没有出现应用，在 Finder 中按 Shift-Command-G，输入 ~/Applications；按住 Control 点按“Codex Usage Bar.app”，选择“打开”，再确认一次。
4. 菜单栏出现用量后，应用已配置为每次登录自动启动。

需要 macOS 13 或更新版本，以及已登录的 Codex CLI 或 Codex Desktop。
应用以本地 Codex app-server 获取额度，不会读取或保存认证令牌。

卸载：双击“卸载 Codex Usage Bar.command”。
应用将从登录项移除；日志和应用支持文件保留在 ~/Library/Application Support/CodexUsageBar。

本版本未使用 Apple Developer ID 签名或公证。首次打开时如遇安全提示，请按上述方式手动确认。
GUIDE_EOF
chmod 755 "$DMG_ROOT/安装 Codex Usage Bar.command" "$DMG_ROOT/卸载 Codex Usage Bar.command"

DMG="$DIST_DIR/CodexUsageBar-v$VERSION-universal.dmg"
ZIP="$DIST_DIR/CodexUsageBar-v$VERSION-universal.zip"
rm -f "$DMG" "$ZIP"
ditto -c -k --sequesterRsrc "$DMG_ROOT" "$ZIP"
hdiutil create -volname "Codex Usage Bar $VERSION" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG" >/dev/null

echo "Created: $DMG"
echo "Created: $ZIP"
