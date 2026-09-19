#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

MODE="production"
case "${1:-}" in
  --production|"")
    MODE="production"
    ;;
  --local)
    MODE="local"
    ;;
  -h|--help)
    cat <<'EOF'
用法：
  ./scripts/android_release_preflight.sh --production
  ./scripts/android_release_preflight.sh --local

--production  正式发布预检：要求生产签名、HTTPS 后端和非占位支付配置。
--local       本地验收预检：只检查工程基础配置，不要求生产密钥。
EOF
    exit 0
    ;;
  *)
    echo "❌ 未知参数：$1" >&2
    exit 2
    ;;
esac

fail() {
  echo "❌ $*" >&2
  exit 1
}

VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]] ||
  fail "pubspec.yaml version 必须是 x.y.z+build 格式，当前：${VERSION:-未设置}"

APP_ID="$(sed -n 's/^[[:space:]]*applicationId = "\([^"]*\)".*/\1/p' android/app/build.gradle.kts | head -1)"
[ -n "$APP_ID" ] || fail "无法读取 Android applicationId"

echo "==> Android 发布预检"
echo "    模式：$MODE"
echo "    版本：$VERSION"
echo "    Application ID：$APP_ID"

if [ "$MODE" = "local" ]; then
  echo "✅ 本地验收预检通过"
  exit 0
fi

KEY_PROPERTIES="android/key.properties"
[ -f "$KEY_PROPERTIES" ] || fail "缺少 android/key.properties，正式 Release 禁止回退到 debug 签名"

read_property() {
  local key="$1"
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$KEY_PROPERTIES" | tail -1
}

STORE_FILE="$(read_property storeFile)"
STORE_PASSWORD="$(read_property storePassword)"
KEY_ALIAS="$(read_property keyAlias)"
KEY_PASSWORD="$(read_property keyPassword)"

[ -n "$STORE_FILE" ] || fail "android/key.properties 缺少 storeFile"
[ -n "$STORE_PASSWORD" ] || fail "android/key.properties 缺少 storePassword"
[ -n "$KEY_ALIAS" ] || fail "android/key.properties 缺少 keyAlias"
[ -n "$KEY_PASSWORD" ] || fail "android/key.properties 缺少 keyPassword"

if [[ "$STORE_FILE" = /* ]]; then
  RESOLVED_STORE_FILE="$STORE_FILE"
else
  RESOLVED_STORE_FILE="android/app/$STORE_FILE"
fi
[ -f "$RESOLVED_STORE_FILE" ] || fail "正式 keystore 不存在：$RESOLVED_STORE_FILE"

if git ls-files --error-unmatch "$KEY_PROPERTIES" >/dev/null 2>&1; then
  fail "android/key.properties 被 Git 跟踪，签名配置不得提交仓库"
fi

TRACKED_KEYS="$(git ls-files '*.jks' '*.keystore' || true)"
[ -z "$TRACKED_KEYS" ] || fail "仓库中发现被 Git 跟踪的 keystore：$TRACKED_KEYS"

API_BASE_URL="${SHARED_API_BASE_URL:-}"
[ -n "$API_BASE_URL" ] || fail "正式发布必须设置 SHARED_API_BASE_URL"
[[ "$API_BASE_URL" == https://* ]] || fail "SHARED_API_BASE_URL 正式环境必须使用 HTTPS"
[[ "$API_BASE_URL" != */ ]] || fail "SHARED_API_BASE_URL 末尾不能带 /，避免生成双斜杠 API 路径"
case "$API_BASE_URL" in
  *127.0.0.1*|*localhost*|*10.0.2.2*)
    fail "SHARED_API_BASE_URL 不能指向本机或 Android 模拟器"
    ;;
esac

grep -q 'app_id:[[:space:]]*YOUR_' pubspec.yaml &&
  fail "pubspec.yaml 仍包含占位微信 App ID"
grep -q 'universal_link:.*YOUR_' pubspec.yaml &&
  fail "pubspec.yaml 仍包含占位微信 Universal Link"
grep -q 'universal_link:.*\.example/' pubspec.yaml &&
  fail "pubspec.yaml 微信 Universal Link 仍指向 example 域名"

WECHAT_APP_ID="$(sed -n 's/^[[:space:]]*app_id:[[:space:]]*//p' pubspec.yaml | head -1)"
WECHAT_LINK="$(sed -n 's/^[[:space:]]*universal_link:[[:space:]]*//p' pubspec.yaml | head -1)"
[ -n "$WECHAT_APP_ID" ] || fail "缺少 wechat_kit.app_id"
[[ "$WECHAT_LINK" == https://* ]] || fail "wechat_kit.universal_link 必须使用 HTTPS"

echo "✅ 正式发布预检通过"
