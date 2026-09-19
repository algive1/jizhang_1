#!/usr/bin/env bash
# Android 正式发布 / 本地 Release 验收打包脚本。
#
# 正式发布（默认）：
#   SHARED_API_BASE_URL=https://api.example.com bash build_apk_release.sh
#   - 必须通过生产预检
#   - 必须使用 android/key.properties 正式签名
#   - 执行 analyze + 全量 flutter test
#   - 同时生成 AAB、APK 和 SHA-256 清单
#
# 本地 Release 性能/真机验收：
#   bash build_apk_release.sh --local-debug-signing
#   - 明确允许 debug 证书签 Release
#   - 只生成带 local-release 标识的 APK，绝不能用于上架
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
LOCAL_DEBUG_SIGNING=0

case "${1:-}" in
  "")
    ;;
  --local-debug-signing)
    LOCAL_DEBUG_SIGNING=1
    ;;
  -h|--help)
    sed -n '1,18p' "$0"
    exit 0
    ;;
  *)
    echo "❌ 未知参数：$1" >&2
    exit 2
    ;;
esac

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "❌ 未找到 Flutter：$FLUTTER_BIN" >&2
  exit 1
fi

VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1)"
[ -n "$VERSION" ] || { echo "❌ 无法读取 pubspec.yaml version" >&2; exit 1; }

DART_ARGS=()
if [ -n "${SHARED_API_BASE_URL:-}" ]; then
  DART_ARGS+=("--dart-define=SHARED_API_BASE_URL=$SHARED_API_BASE_URL")
fi

echo "==> flutter --version"
"$FLUTTER_BIN" --version
echo "==> flutter pub get"
"$FLUTTER_BIN" pub get

mkdir -p dist

if [ "$LOCAL_DEBUG_SIGNING" -eq 1 ]; then
  echo "==> 本地 Release 验收模式（debug certificate）"
  bash scripts/android_release_preflight.sh --local

  ALLOW_DEBUG_RELEASE_SIGNING=true     "$FLUTTER_BIN" build apk --release "${DART_ARGS[@]}"

  APK="build/app/outputs/flutter-apk/app-release.apk"
  [ -f "$APK" ] || { echo "❌ 未找到构建产物：$APK" >&2; exit 1; }
  DEST="dist/jizhang_app-${VERSION}-local-release-debug-signed.apk"
  cp "$APK" "$DEST"

  echo ""
  echo "✅ 本地 Release 验收包生成完成"
  echo "   $DEST"
  echo "⚠️  此包使用 debug 证书，只能用于本地性能/真机验收，禁止上架。"
  exit 0
fi

echo "==> 正式发布预检"
bash scripts/android_release_preflight.sh --production

echo "==> flutter analyze"
"$FLUTTER_BIN" analyze

echo "==> flutter test"
"$FLUTTER_BIN" test --reporter compact

echo "==> 构建正式 AAB"
"$FLUTTER_BIN" build appbundle --release "${DART_ARGS[@]}"

echo "==> 构建正式 APK"
"$FLUTTER_BIN" build apk --release "${DART_ARGS[@]}"

AAB="build/app/outputs/bundle/release/app-release.aab"
APK="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$AAB" ] || { echo "❌ 未找到 AAB：$AAB" >&2; exit 1; }
[ -f "$APK" ] || { echo "❌ 未找到 APK：$APK" >&2; exit 1; }

AAB_NAME="jizhang_app-${VERSION}-release.aab"
APK_NAME="jizhang_app-${VERSION}-release.apk"
cp "$AAB" "dist/$AAB_NAME"
cp "$APK" "dist/$APK_NAME"

CHECKSUM_FILE="dist/jizhang_app-${VERSION}-SHA256SUMS.txt"
if command -v sha256sum >/dev/null 2>&1; then
  (
    cd dist
    sha256sum "$AAB_NAME" "$APK_NAME"
  ) >"$CHECKSUM_FILE"
elif command -v shasum >/dev/null 2>&1; then
  (
    cd dist
    shasum -a 256 "$AAB_NAME" "$APK_NAME"
  ) >"$CHECKSUM_FILE"
else
  echo "❌ 系统缺少 sha256sum / shasum，无法生成校验清单" >&2
  exit 1
fi

echo ""
echo "✅ Android 正式发布产物生成完成"
echo "   AAB：dist/$AAB_NAME"
echo "   APK：dist/$APK_NAME"
echo "   SHA-256：$CHECKSUM_FILE"
cat "$CHECKSUM_FILE"
