# 换平台开发交接说明

生成日期：2026-09-14  
项目：好好记账（`jizhang_app`）

## 这份压缩包包含什么

压缩包按当前工作区快照生成，包含 Flutter 主工程、Android/iOS 原生工程、Node.js 共享账本后端、`third_party` 本地插件覆盖、资源、测试、策略文件、构建脚本和 `docs/` 开发/设计/QA 资料。当前工作区中尚未提交的源码和文档改动也已保留。

为便于换平台恢复，压缩包不包含以下可重新生成或不应迁移的内容：`.git` 历史、`.dart_tool`、Flutter/Gradle/Android 构建缓存、`server/node_modules`、`server/dist`、`server/data` 本地 SQLite 数据、iOS `Pods`/symlinks/ephemeral、`dist` 下 APK、IDE 配置和系统临时文件。正式签名文件、支付证书和 API key 也不在包内。

## 换平台后的首次操作

1. 解压后进入项目根目录。
2. 安装 Flutter（Dart SDK 需满足 `pubspec.yaml` 的 `^3.13.2`），并准备 Android SDK/Java 17；iOS 开发需要 macOS、Xcode 和 CocoaPods。
3. 执行：

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```

4. 构建 Android：

   ```bash
   flutter build apk --debug
   # 或：./scripts/build_install_android.sh --package-only
   ```

5. 启动本地共享后端：

   ```bash
   cd server
   npm install
   npm run typecheck
   npm test
   npm run build
   npm run dev
   ```

   后端默认监听 `127.0.0.1:8787`，必要时使用 `PORT` 和 `LEDGER_DB_PATH` 覆盖配置。Android 模拟器联调前执行 `adb reverse tcp:8787 tcp:8787`。

## 需要在新平台重新配置的项目

- Android 正式发布：创建本地 `android/key.properties` 和 keystore；不要提交到仓库。
- 微信/支付宝：按运行环境注入商户号、证书、私钥、公钥和回调配置；密钥不能写进源码或 App。
- AI 服务：按 `server/src/assistant_ai.ts` 的运行时配置接入服务商 API key；当前压缩包不携带任何 key。
- iOS：在新机器执行 CocoaPods 依赖安装，并补齐签名、Bundle ID、开发团队和发布配置。
- 个人/共享数据：`server/data/shared-ledger.sqlite` 未迁移；如需迁移业务数据，请单独安全导出并核验，不要把运行数据库直接放入源码包。

## 当前已知状态

完整状态、架构、测试结果和未完成事项见 `docs/development/CURRENT_STATUS.md`。当前重点风险包括：Android 尚未配置正式 keystore；支付真实商户/公网 HTTPS 回调尚未联调；iOS 真机发布尚未验收；OCR、云端 ASR/LLM、短信、附件云存储等仍未完成。

## 安全提醒

本次交接包按“可继续开发”的源码快照制作，不包含用户在对话中提供的任何 API key。若这些 key 曾在其他机器、日志或终端中使用过，换平台前应在对应服务商后台轮换，并通过环境变量或受限密钥管理重新注入。
