#!/usr/bin/env bash
# ============================================================
# jizhang_app — Android Release 安装包一键打包脚本
# 用法：
#   bash build_apk_release.sh
#   bash build_apk_release.sh --universal-apk
#
# 默认：按 ABI 拆分 release APK，避免把 arm64-v8a / armeabi-v7a /
#       x86_64 原生库全部塞进同一个手机安装包。
# 覆盖：如确实需要一个通用 APK，可传 --universal-apk。
# ============================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

exec "$PROJECT_DIR/scripts/build_install_android.sh" \
  --release \
  --package-only \
  --split-per-abi \
  "$@"
