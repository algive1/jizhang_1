#!/usr/bin/env bash
# ============================================================
# jizhang_app — Android Release 安装包一键打包脚本
# 用法：在项目根目录执行  bash build_apk_release.sh
# 产物：dist/jizhang_app-<版本>-release.apk
# 说明：当前没有 android/key.properties 正式签名，
#       产物使用 debug 签名（可直接安装到手机，不可上架商店）。
# ============================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "==> 项目目录: $PROJECT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ 未找到 flutter 命令，请先安装 Flutter SDK 并加入 PATH"
  echo "   检查：flutter doctor"
  exit 1
fi

echo "==> flutter --version"
flutter --version

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build apk --release（首次构建较慢，请耐心等待）"
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK" ]; then
  echo "❌ 未找到构建产物: $APK"
  exit 1
fi

VERSION="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
mkdir -p dist
DEST="dist/jizhang_app-${VERSION}-release.apk"
cp "$APK" "$DEST"

echo ""
echo "✅ 打包完成"
echo "   产物：$DEST"
ls -lh "$DEST"
echo ""
echo "安装到已连接的手机：adb install -r \"$DEST\""
echo "（也可把该 APK 拷贝到手机直接安装）"
echo ""
echo "⚠️  正式发布前请在 android/key.properties 配置正式签名后重新打包，"
echo "    否则应用以 debug 证书签名，无法上架应用商店。"
