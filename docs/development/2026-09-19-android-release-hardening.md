# Android 正式发布链路加固（2026-09-19）

## 目标

避免把“能安装的 Release APK”误认为“可上架正式包”，并把签名、生产 API、支付应用配置和构建产物校验统一成 fail-closed 流程。

## 本轮完成

- Android Gradle 不再默认使用 debug signing 兜底 Release。
- 没有 `android/key.properties` / 正式 keystore 时：
  - `assembleRelease` 失败；
  - `bundleRelease` 失败。
- 只有显式 `ALLOW_DEBUG_RELEASE_SIGNING=true` 才允许本地 debug-sign Release。
- 日常 `scripts/build_install_android.sh` 默认改为 Debug。
- 新增 `--release-local`，产物名称明确包含 `local-release-debug-signed`。
- `build_apk_release.sh` 默认变为生产发布脚本：
  - 生产预检；
  - flutter analyze；
  - 全量 flutter test；
  - 生产 AAB；
  - 生产 APK；
  - SHA-256 清单。
- 新增 `scripts/android_release_preflight.sh`。
- 生产预检拒绝：
  - 缺少正式签名；
  - key.properties / keystore 被 Git 跟踪；
  - 非 HTTPS / localhost / 模拟器 API；
  - 微信 App ID 占位值；
  - 微信 Universal Link 占位值。
- 新增手动 GitHub Workflow：`Android Production Build`。
- Workflow 使用 Secrets 临时生成签名文件，完成后无论成功失败都会删除。
- Workflow 只上传 Artifact，不自动创建 Tag / GitHub Release / 商店发布。
- 普通 CI 增加：
  - 三个 release shell 脚本 `bash -n`；
  - 本地预检必须通过；
  - 无生产密钥时生产预检必须失败；
  - Gradle Kotlin DSL 配置解析。

## GitHub 生产配置

Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Variables：

- `WECHAT_APP_ID`
- `WECHAT_UNIVERSAL_LINK`

Workflow 手动输入：

- `api_base_url`：生产 HTTPS API。

建议给 `production` Environment 设置 required reviewers。

## 当前仍未满足的正式发布条件

这些值不能由代码替你生成或猜测：

1. 正式 Android keystore 及其离线备份。
2. 已部署并验收的公网 HTTPS 好好记账后端。
3. 正式微信开放平台 App ID。
4. 正式微信 Universal Link 域名与服务端关联配置。
5. 微信/支付宝商户生产参数与回调。
6. 第一家应用商店提交前最终确认 Application ID。
7. 正式商店账号、隐私资料、截图、审核文案。
8. 当前版本的生产真机完整回归。

## 安全边界

- 不提交 keystore、key.properties 或密码。
- 不允许生产构建回退 debug certificate。
- 不把 API 地址写死成 localhost。
- 不自动上传商店。
- 不自动提高服务端最低支持版本。
- 更新策略应在新版商店审核/可下载后再提高 minimum version，避免把旧客户端提前锁死。
