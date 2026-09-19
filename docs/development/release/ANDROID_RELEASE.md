# Android 构建与正式发布

更新时间：2026-09-19

## 基本信息

- Application ID：`com.algive.jizhang_app`
- Version：以 `pubspec.yaml` 为准，当前为 `1.0.0+1`
- 正式发布脚本：`bash build_apk_release.sh`
- GitHub 手动生产构建：`Android Production Build`
- AAB：`dist/jizhang_app-<version>-release.aab`
- APK：`dist/jizhang_app-<version>-release.apk`
- SHA-256：`dist/jizhang_app-<version>-SHA256SUMS.txt`

> 第一次提交任一应用商店前，需要人工确认 Application ID 已经是最终值。这里不会自动替换包名。

## 三种构建必须区分

### 1. 日常开发 / 模拟器 / 真机调试

默认使用 Debug：

```bash
./scripts/build_install_android.sh
./scripts/build_install_android.sh --package-only
```

该脚本不再默认构建 Release。

### 2. 本地 Release 性能验收

只有在需要验证 Release 模式性能、混淆/优化行为或真机表现时使用：

```bash
./scripts/build_install_android.sh --release-local
# 或
bash build_apk_release.sh --local-debug-signing
```

产物会明确命名为：

```text
*-local-release-debug-signed.apk
```

它使用 debug certificate，**禁止提交应用商店**。

### 3. 正式生产 Release

必须准备：

- `android/key.properties`
- 私有 keystore
- 生产 HTTPS `SHARED_API_BASE_URL`
- 正式微信 App ID
- 正式微信 Universal Link
- 正确版本号与 build number

执行：

```bash
export SHARED_API_BASE_URL="https://api.your-domain.com"
bash build_apk_release.sh
```

正式脚本会依次执行：

1. `flutter pub get`
2. 生产发布预检
3. `flutter analyze`
4. 全量 `flutter test`
5. `flutter build appbundle --release`
6. `flutter build apk --release`
7. 生成 SHA-256 清单

任何一步失败都不会生成“可发布成功”的结论。

## 正式签名

`android/key.properties` 示例仅说明字段名，不要把真实内容提交 Git：

```properties
storeFile=/absolute/or/relative/path/to/release-upload.jks
storePassword=...
keyAlias=...
keyPassword=...
```

仓库已忽略：

- `android/key.properties`
- `*.jks`
- `*.keystore`

Gradle 规则：

- 存在正式 keystore：Release 使用正式签名。
- 不存在正式 keystore：正式 `assembleRelease` / `bundleRelease` 直接失败。
- 只有显式设置 `ALLOW_DEBUG_RELEASE_SIGNING=true` 时，才允许本地 debug-sign Release。

生产 keystore 一旦用于正式发布，应至少保留两份离线备份，并单独保存密码与 alias。不要只保存在开发电脑或 GitHub Secrets。

## 生产后端

客户端大量联网能力依赖编译期：

```text
SHARED_API_BASE_URL
```

正式发布预检要求：

- 必须存在；
- 必须为 `https://`；
- 不得为 `127.0.0.1`、`localhost` 或 `10.0.2.2`。

构建时脚本自动传入：

```bash
--dart-define=SHARED_API_BASE_URL=<production-url>
```

如果没有生产公网 HTTPS 后端，不应生成正式商店包。

## 微信配置

当前 `pubspec.yaml` 仍保留开发占位值时，正式预检会故意失败：

```yaml
wechat_kit:
  app_id: YOUR_WECHAT_APP_ID
  universal_link: https://YOUR_DOMAIN.example/...
```

正式发布前必须替换成真实配置。

## GitHub 手动生产构建

Workflow：

```text
.github/workflows/android-production-build.yml
```

在 GitHub 的 `production` Environment / Repository 中配置：

### Secrets

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

### Variables

- `WECHAT_APP_ID`
- `WECHAT_UNIVERSAL_LINK`

触发 Workflow 时还必须输入生产 `api_base_url`。

Workflow 会临时：

1. 解码 keystore；
2. 生成 `android/key.properties`；
3. 把非秘密的微信 App ID / Universal Link 注入工作区 `pubspec.yaml`；
4. 调用与本地相同的正式发布脚本；
5. 上传签名 AAB、APK、SHA-256 清单为 GitHub Artifact；
6. 无论成功失败都删除 runner 上的临时签名文件。

Workflow **不会自动创建 Tag、GitHub Release 或提交应用商店**。最终发布仍需要人工确认。

建议给 GitHub `production` Environment 设置 required reviewers，使正式构建本身也需要人工批准。

## 版本规则

每次提交应用商店前必须提高 build number：

```yaml
version: 1.0.1+2
```

同一商店渠道不要重复使用已上传的 build number。

版本更新服务中的 latest/minimum version 也要与实际已发布版本对应；不能先把服务端 minimum version 提高，再延迟发布客户端，否则会错误触发强制更新。

## 发布前检查

正式包至少确认：

- Git 工作区对应预期 Commit。
- Production CI 全绿。
- 正式签名，不是 debug certificate。
- AAB 与 APK 的 SHA-256 已保存。
- 生产 API HTTPS 可访问。
- 注册 / 登录 / 会员 / 云同步在生产后端可用。
- 微信 / 支付宝生产配置正确。
- 首次安装和覆盖升级都验证。
- 数据库迁移、备份恢复、记账、编辑、删除、自动记账验证。
- 强制更新与可选更新行为验证。
- 弱网 / 无网时本地记账不被阻塞。
- Push / 广告若尚未接真实供应商，应保持安全降级，不宣传为已上线功能。

## 当前状态

仓库现在已经禁止“没有生产 keystore 却悄悄生成 debug-sign Release”的旧行为。

但这并不等于已经具备正式上架条件：当前仍需要配置生产 keystore、生产 HTTPS 后端以及真实微信应用配置，并完成生产环境真机验收。
