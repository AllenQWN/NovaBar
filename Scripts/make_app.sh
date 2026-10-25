#!/bin/bash
# 将 NovaBar 编译并打包成 build/NovaBar.app（菜单栏应用）
# 用法：./Scripts/make_app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ 编译 ..."
"$(dirname "$0")/build.sh"

BIN=".build/release/NovaBar"
APP_DIR="build/NovaBar.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"

mkdir -p "$MACOS_DIR"
cp "$BIN" "$MACOS_DIR/NovaBar"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>NovaBar</string>
    <key>CFBundleDisplayName</key><string>NovaBar</string>
    <key>CFBundleIdentifier</key><string>app.novabar.NovaBar</string>
    <key>CFBundleVersion</key><string>1.0.0</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleExecutable</key><string>NovaBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>26.5</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Allen. All rights reserved.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_DIR"

echo "✅ 已生成 $APP_DIR"
echo "   启动: open build/NovaBar.app"
