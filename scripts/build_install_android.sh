#!/usr/bin/env bash
# 构建 Android APK，安装到模拟器/设备并启动应用。
# 默认构建 release 包，产物可拷贝到 Android 手机直接安装。
#
# 用法：
#   ./scripts/build_install_android.sh
#   ./scripts/build_install_android.sh --package-only
#   ./scripts/build_install_android.sh --debug
#   ./scripts/build_install_android.sh --emulator pixel_7
#   ./scripts/build_install_android.sh --device emulator-5554
#   ./scripts/build_install_android.sh --no-pub-get

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADB_BIN="${ADB_BIN:-adb}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
BUILD_MODE="${ANDROID_BUILD_MODE:-release}"
DEVICE_ID="${ANDROID_DEVICE_ID:-}"
EMULATOR_ID="${ANDROID_EMULATOR_ID:-}"
RUN_PUB_GET=1
PACKAGE_ONLY=0
SPLIT_PER_ABI="${ANDROID_SPLIT_PER_ABI:-auto}"

usage() {
  sed -n '2,12p' "$0"
  cat <<'EOF'

选项：
  --debug              构建 debug APK
  --release            构建 release APK
  --package-only       只构建并输出可安装 APK，不启动模拟器或执行 adb 安装
  --split-per-abi      为每个 Android ABI 生成独立 APK
  --universal-apk      生成包含全部 ABI 的通用 APK
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
      shift
      ;;
    --package-only)
      PACKAGE_ONLY=1
      shift
      ;;
    --split-per-abi)
      SPLIT_PER_ABI=1
      shift
      ;;
    --universal-apk)
      SPLIT_PER_ABI=0
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

if [ "$SPLIT_PER_ABI" = "auto" ]; then
  if [ "$BUILD_MODE" = "release" ]; then
    SPLIT_PER_ABI=1
  else
    SPLIT_PER_ABI=0
  fi
fi
if [ "$SPLIT_PER_ABI" != "0" ] && [ "$SPLIT_PER_ABI" != "1" ]; then
  echo "❌ ANDROID_SPLIT_PER_ABI 只能是 0、1 或 auto。" >&2
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

BUILD_ARGS=(apk "--$BUILD_MODE")
if [ "$SPLIT_PER_ABI" -eq 1 ]; then
  BUILD_ARGS+=(--split-per-abi)
fi
echo "==> flutter build ${BUILD_ARGS[*]}"
"$FLUTTER_BIN" build "${BUILD_ARGS[@]}"

APK_DIR="$PROJECT_DIR/build/app/outputs/flutter-apk"
APK_PATH="$APK_DIR/app-${BUILD_MODE}.apk"
if [ "$SPLIT_PER_ABI" -eq 0 ] && [ ! -f "$APK_PATH" ]; then
  echo "❌ 未找到构建产物：$APK_PATH" >&2
  exit 1
fi

VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1)"
if [ -z "$VERSION" ]; then
  echo "❌ 无法从 pubspec.yaml 读取版本号。" >&2
  exit 1
fi

DIST_DIR="$PROJECT_DIR/dist"
mkdir -p "$DIST_DIR"

if [ "$SPLIT_PER_ABI" -eq 1 ]; then
  PACKAGE_PATH=""
  shopt -s nullglob
  SPLIT_APKS=("$APK_DIR"/app-*-"$BUILD_MODE".apk)
  shopt -u nullglob
  if [ "${#SPLIT_APKS[@]}" -eq 0 ]; then
    echo "❌ 未找到按 ABI 拆分的 APK。" >&2
    exit 1
  fi
  for apk in "${SPLIT_APKS[@]}"; do
    abi="${apk##*/app-}"
    abi="${abi%-${BUILD_MODE}.apk}"
    target="$DIST_DIR/jizhang_app-${VERSION}-${BUILD_MODE}-${abi}.apk"
    cp "$apk" "$target"
    echo "✅ ABI APK 已生成：$target"
  done

  if [ "$PACKAGE_ONLY" -eq 1 ]; then
    exit 0
  fi

  DEVICE_ABI="$("$ADB_BIN" -s "$DEVICE_ID" shell getprop ro.product.cpu.abi | tr -d '\r')"
  case "$DEVICE_ABI" in
    arm64-v8a|armeabi-v7a|x86_64) ;;
    *)
      echo "❌ 暂不支持自动选择设备 ABI：$DEVICE_ABI" >&2
      exit 1
      ;;
  esac
  PACKAGE_PATH="$DIST_DIR/jizhang_app-${VERSION}-${BUILD_MODE}-${DEVICE_ABI}.apk"
  if [ ! -f "$PACKAGE_PATH" ]; then
    echo "❌ 没有找到设备 ABI 对应的 APK：$PACKAGE_PATH" >&2
    exit 1
  fi
else
  PACKAGE_PATH="$DIST_DIR/jizhang_app-${VERSION}-${BUILD_MODE}.apk"
  cp "$APK_PATH" "$PACKAGE_PATH"
  echo "✅ 可直接安装的 APK 已生成：$PACKAGE_PATH"

  if [ "$PACKAGE_ONLY" -eq 1 ]; then
    echo "   手机连接 adb 后可执行：adb install -r \"$PACKAGE_PATH\""
    exit 0
  fi
fi

echo "==> 安装 APK：$PACKAGE_PATH"
"$ADB_BIN" -s "$DEVICE_ID" install -r "$PACKAGE_PATH"

echo "==> 启动应用：$APP_ID"
"$ADB_BIN" -s "$DEVICE_ID" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null

echo ""
echo "✅ 构建、安装并启动完成"
echo "   设备：$DEVICE_ID"
echo "   APK：$PACKAGE_PATH"
