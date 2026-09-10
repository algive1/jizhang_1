# Android 构建与交付

更新时间：2026-09-09

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

本轮验证的 APK 为 72,799,794 bytes，SHA-256 为：
`ea4762b9b8964bb6ebb015e4f1e79a6c9bad53747059e2dae878bf17d924d81c`。

Release APK 已安装到 `emulator-5554`（Pixel 7 模拟器），并打开首页、立体书架抽屉和系统桌面图标；没有物理 Android 设备验收。

启动图标的统一源是项目内的 `assets/images/icon.png`，内容来自本轮指定的桌面 `icon.png`；Android 各密度资源和 iOS AppIcon 均由该源生成。

构建过程有 `speech_to_text` 使用 Kotlin Gradle Plugin 的未来兼容性 warning，但本轮 Release APK 已成功生成；后续插件升级时需迁移到 Built-in Kotlin。

## 签名说明

当前没有 `android/key.properties` 正式签名配置，Release 会退回 debug signing。该 APK 适合本地安装和验收，不适合提交应用商店。正式发布前必须配置生产 keystore、签名密码和 alias，并重新构建验证。

## 发布前检查

- 确认 `android/key.properties` 不进入版本库。
- 重新执行 `flutter analyze`、`flutter test` 和 `flutter build apk --release`。
- 在目标 Android 版本和 ABI 上验证首次安装、升级安装、数据库迁移、记账、编辑、删除和重启持久化。
- 发布说明必须区分“本地已验证”和“外部服务尚未联调”。
