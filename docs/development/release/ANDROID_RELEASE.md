# Android 构建与交付

更新时间：2026-09-18

## 基本信息

- Application ID：`com.algive.jizhang_app`
- Version：以 `pubspec.yaml` 为准，当前为 `1.0.0+1`
- 推荐脚本：`bash build_apk_release.sh`
- Release 输出：`build/app/outputs/flutter-apk/app-release.apk`
- 脚本复制输出：`dist/jizhang_app-1.0.0+1-release.apk`

## 构建与安装

```bash
cd /Users/algive/jizhang_01
bash build_apk_release.sh
adb install -r "dist/jizhang_app-1.0.0+1-release.apk"
```

手动构建：

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## 当前验收产物

2026-09-18 本轮验证的 APK 为 94,051,561 bytes，SHA-256 为：
`6ac8d2c5dfb188659e9b2dc68f4d604c6fd027434e8cd822aa7c1492d9c66564`。

APK 已通过 `adb install -r` 安装到实体 Android 设备 `145a0a68`（型号 `23116PN5BC`），安装后启动 `com.algive.jizhang_app/.MainActivity`，并确认当前 Activity 处于前台。未清理应用数据。

启动图标的统一源是项目内的 `assets/images/icon.png`，内容来自本轮指定的桌面 `icon.png`；Android 各密度资源和 iOS AppIcon 均由该源生成。

构建过程有 Android Gradle Plugin / Kotlin Built-in Kotlin 迁移和 `speech_to_text` 相关未来兼容性 warning，但本轮 Release APK 已成功生成；后续插件升级时需迁移到 Built-in Kotlin。

## 签名说明

当前没有 `android/key.properties` 正式签名配置，Release 会退回 debug signing。该 APK 适合本地安装和验收，不适合提交应用商店。正式发布前必须配置生产 keystore、签名密码和 alias，并重新构建验证。

## 发布前检查

- 确认 `android/key.properties` 不进入版本库。
- 重新执行 `flutter analyze`、`flutter test` 和 `flutter build apk --release`。
- 在目标 Android 版本和 ABI 上验证首次安装、升级安装、数据库迁移、记账、编辑、删除和重启持久化。
- 发布说明必须区分“本地已验证”和“外部服务尚未联调”。
