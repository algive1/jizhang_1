#!/usr/bin/env bash
# 构建 Android APK，安装到模拟器/设备并启动应用。
# 默认构建 debug 包；正式 release 必须通过生产签名预检。
#
# 用法：
#   ./scripts/build_install_android.sh
#   ./scripts/build_install_android.sh --package-only
#   ./scripts/build_install_android.sh --debug
#   ./scripts/build_install_android.sh --release
#   ./scripts/build_install_android.sh --release-local
#   ./scripts/build_install_android.sh --emulator pixel_7
#   ./scripts/build_install_android.sh --device emulator-5554
#   ./scripts/build_install_android.sh --no-pub-get

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADB_BIN="${ADB_BIN:-adb}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
BUILD_MODE="${ANDROID_BUILD_MODE:-debug}"
LOCAL_RELEASE_SIGNING=0
DEVICE_ID="${ANDROID_DEVICE_ID:-}"
EMULATOR_ID="${ANDROID_EMULATOR_ID:-}"
RUN_PUB_GET=1
PACKAGE_ONLY=0

usage() {
  sed -n '2,12p' "$0"
  cat <<'EOF'

选项：
  --debug              构建 debug APK
  --release            构建正式签名 release APK（要求生产配置）
  --release-local      构建 debug 证书签名的本地 release 验收 APK
  --package-only       只构建并输出可安装 APK，不启动模拟器或执行 adb 安装
  --device <id>        安装到指定 adb 设备，例如 emulator-5554
  --emulator <id>      没有在线模拟器时启动指定 AVD，例如 pixel_7
  --no-pub-get         跳过 flutter pub get
  -h, --help           显示帮助
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ 未找到 $1，请先安装并加入 PATH。" >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --debug)
      BUILD_MODE="debug"
      shift
      ;;
    --release)
      BUILD_MODE="release"
      LOCAL_RELEASE_SIGNING=0
      shift
      ;;
    --release-local)
      BUILD_MODE="release"
      LOCAL_RELEASE_SIGNING=1
      shift
      ;;
    --package-only)
      PACKAGE_ONLY=1
      shift
      ;;
    --device)
      if [ "$#" -lt 2 ]; then
        echo "❌ --device 需要设备 ID。" >&2
        exit 1
      fi
      DEVICE_ID="$2"
      shift 2
      ;;
    --emulator)
      if [ "$#" -lt 2 ]; then
        echo "❌ --emulator 需要 AVD ID。" >&2
        exit 1
      fi
      EMULATOR_ID="$2"
      shift 2
      ;;
    --no-pub-get)
      RUN_PUB_GET=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "❌ 未知选项：$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ "$BUILD_MODE" != "debug" ] && [ "$BUILD_MODE" != "release" ]; then
  echo "❌ ANDROID_BUILD_MODE 只能是 debug 或 release。" >&2
  exit 1
fi

cd "$PROJECT_DIR"
require_command "$FLUTTER_BIN"
if [ "$PACKAGE_ONLY" -eq 0 ]; then
  require_command "$ADB_BIN"
fi

APP_ID="${APP_ID:-$(sed -n 's/^[[:space:]]*applicationId = "\([^"]*\)".*/\1/p' android/app/build.gradle.kts | head -1)}"
if [ -z "$APP_ID" ]; then
  echo "❌ 无法从 android/app/build.gradle.kts 读取 applicationId。" >&2
  exit 1
fi

if [ "$PACKAGE_ONLY" -eq 0 ] && [ -z "$DEVICE_ID" ]; then
  if [ -n "$EMULATOR_ID" ]; then
    "$SCRIPT_DIR/open_android_emulator.sh" "$EMULATOR_ID"
  else
    "$SCRIPT_DIR/open_android_emulator.sh"
  fi
  DEVICE_ID="$($ADB_BIN devices | awk '$1 ~ /^emulator-/ && $2 == "device" { device_id = $1 } END { print device_id }')"
elif [ "$PACKAGE_ONLY" -eq 0 ]; then
  DEVICE_STATE="$($ADB_BIN -s "$DEVICE_ID" get-state 2>/dev/null || true)"
  if [ "$DEVICE_STATE" != "device" ]; then
    echo "❌ 指定设备不可用：$DEVICE_ID" >&2
    "$ADB_BIN" devices >&2
    exit 1
  fi
fi

if [ "$PACKAGE_ONLY" -eq 0 ] && [ -z "$DEVICE_ID" ]; then
  echo "❌ 没有找到可安装的 Android 设备。" >&2
  "$ADB_BIN" devices >&2
  exit 1
fi

if [ "$PACKAGE_ONLY" -eq 0 ]; then
  echo "==> 目标设备：$DEVICE_ID"
fi
if [ "$RUN_PUB_GET" -eq 1 ]; then
  echo "==> flutter pub get"
  "$FLUTTER_BIN" pub get
fi

DART_ARGS=()
if [ -n "${SHARED_API_BASE_URL:-}" ]; then
  DART_ARGS+=("--dart-define=SHARED_API_BASE_URL=$SHARED_API_BASE_URL")
fi

if [ "$BUILD_MODE" = "release" ] && [ "$LOCAL_RELEASE_SIGNING" -eq 1 ]; then
  echo "==> 本地 Release 验收预检"
  bash "$SCRIPT_DIR/android_release_preflight.sh" --local
  echo "==> flutter build apk --release（debug certificate，仅本地验收）"
  ALLOW_DEBUG_RELEASE_SIGNING=true     "$FLUTTER_BIN" build apk --release "${DART_ARGS[@]}"
elif [ "$BUILD_MODE" = "release" ]; then
  echo "==> 正式 Release 预检"
  bash "$SCRIPT_DIR/android_release_preflight.sh" --production
  echo "==> flutter build apk --release（production signing）"
  "$FLUTTER_BIN" build apk --release "${DART_ARGS[@]}"
else
  echo "==> flutter build apk --debug"
  "$FLUTTER_BIN" build apk --debug "${DART_ARGS[@]}"
fi

APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-${BUILD_MODE}.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "❌ 未找到构建产物：$APK_PATH" >&2
  exit 1
fi

VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1)"
if [ -z "$VERSION" ]; then
  echo "❌ 无法从 pubspec.yaml 读取版本号。" >&2
  exit 1
fi

DIST_DIR="$PROJECT_DIR/dist"
if [ "$BUILD_MODE" = "release" ] && [ "$LOCAL_RELEASE_SIGNING" -eq 1 ]; then
  PACKAGE_SUFFIX="local-release-debug-signed"
else
  PACKAGE_SUFFIX="$BUILD_MODE"
fi
PACKAGE_PATH="$DIST_DIR/jizhang_app-${VERSION}-${PACKAGE_SUFFIX}.apk"
mkdir -p "$DIST_DIR"
cp "$APK_PATH" "$PACKAGE_PATH"
echo "✅ 可直接安装的 APK 已生成：$PACKAGE_PATH"

if [ "$PACKAGE_ONLY" -eq 1 ]; then
  echo "   手机连接 adb 后可执行：adb install -r \"$PACKAGE_PATH\""
  exit 0
fi

echo "==> 安装 APK：$PACKAGE_PATH"
"$ADB_BIN" -s "$DEVICE_ID" install -r "$PACKAGE_PATH"

echo "==> 启动应用：$APP_ID"
"$ADB_BIN" -s "$DEVICE_ID" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null

echo ""
echo "✅ 构建、安装并启动完成"
echo "   设备：$DEVICE_ID"
echo "   APK：$PACKAGE_PATH"
