#!/bin/bash
# 直接用 swiftc 编译 NovaBar（绕过 SwiftPM）。
#
# 为什么不用 swift build：本机 Command Line Tools (6.4.0.34.1) 环境下，
# 1) SwiftPM 清单编译会往系统临时目录写模块缓存（受限终端不可写）；
# 2) 27.0 SDK 缺少 arm64 swiftmodule 切片且 SwiftUI 宏插件（SwiftUIMacros）缺失。
# 因此改用 26.5 SDK 直接编译（其 SwiftUI 仍是传统属性包装器，无需宏插件），
# 模块缓存也留在项目内，不依赖任何项目外路径。
set -euo pipefail
cd "$(dirname "$0")/.."

SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
CACHE="$PWD/.build/modulecache265"
mkdir -p "$CACHE" .build/release

SWIFTC_FLAGS=(-O -swift-version 5 -sdk "$SDK" -target arm64-apple-macosx26.5 -module-cache-path "$CACHE")

echo "→ 编译 NovaBar（菜单栏应用）..."
swiftc "${SWIFTC_FLAGS[@]}" -parse-as-library \
  Sources/NovaBarKit/CursorSessionStore.swift \
  Sources/NovaBarKit/CursorUsage.swift \
  Sources/NovaBar/NovaBarApp.swift \
  Sources/NovaBar/UsageViewModel.swift \
  Sources/NovaBar/MenuContentView.swift \
  Sources/NovaBar/LoginView.swift \
  Sources/NovaBar/SettingsView.swift \
  -o .build/release/NovaBar

echo "→ 编译 NovaBarCLI（数据链路调试工具）..."
swiftc "${SWIFTC_FLAGS[@]}" \
  Sources/NovaBarKit/CursorSessionStore.swift \
  Sources/NovaBarKit/CursorUsage.swift \
  Sources/NovaBarCLI/main.swift \
  -o .build/release/NovaBarCLI

echo "✅ 编译完成"
echo "   菜单栏应用: .build/release/NovaBar"
echo "   调试工具  : .build/release/NovaBarCLI"
