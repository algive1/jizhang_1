#!/usr/bin/env bash
# 启动项目使用的 Android 模拟器，并等待它进入可安装状态。
# 用法：
#   ./scripts/open_android_emulator.sh
#   ./scripts/open_android_emulator.sh pixel_7
#   ANDROID_EMULATOR_ID=pixel_7 ./scripts/open_android_emulator.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADB_BIN="${ADB_BIN:-adb}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
EMULATOR_ID="${1:-${ANDROID_EMULATOR_ID:-}}"
BOOT_TIMEOUT_SECONDS="${ANDROID_EMULATOR_BOOT_TIMEOUT_SECONDS:-120}"

cd "$PROJECT_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ 未找到 $1，请先安装并加入 PATH。" >&2
    exit 1
  fi
}

require_command "$ADB_BIN"
require_command "$FLUTTER_BIN"

find_online_emulator() {
  "$ADB_BIN" devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }'
}

wait_for_ready_emulator() {
  echo "==> 等待模拟器完成启动（最多 ${BOOT_TIMEOUT_SECONDS}s）"
  local deadline="$(($(date +%s) + BOOT_TIMEOUT_SECONDS))"
  local device_id=""

  while [ "$(date +%s)" -lt "$deadline" ]; do
    device_id="$(find_online_emulator)"
    if [ -n "$device_id" ]; then
      local boot_completed
      boot_completed="$($ADB_BIN -s "$device_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | tr -d '[:space:]')"
      if [ "$boot_completed" = "1" ]; then
        echo "✅ Android 模拟器已就绪：$device_id"
        return 0
      fi
    fi
    sleep 2
  done

  echo "❌ 模拟器启动超时。当前 adb 设备列表：" >&2
  "$ADB_BIN" devices >&2
  return 1
}

ONLINE_EMULATOR="$(find_online_emulator)"
if [ -n "$ONLINE_EMULATOR" ]; then
  echo "✅ Android 模拟器已在运行：$ONLINE_EMULATOR"
else
  if [ -z "$EMULATOR_ID" ]; then
    EMULATOR_ID="$($FLUTTER_BIN emulators | awk '
      $1 ~ /^[[:alnum:]_.-]+$/ && $2 == "•" && emulator_id == "" { emulator_id = $1 }
      END { print emulator_id }
    ')"
  fi

  if [ -z "$EMULATOR_ID" ]; then
    echo "❌ 没有找到可启动的 Flutter Android emulator。" >&2
    echo "   请先执行：flutter emulators" >&2
    exit 1
  fi

  echo "==> 启动 Android 模拟器：$EMULATOR_ID"
  "$FLUTTER_BIN" emulators --launch "$EMULATOR_ID"
fi

wait_for_ready_emulator
