# 首页账本标题、Android 图标与启动海报

## 需求结果

- 默认个人账本在首页显示“我的账本”。
- 默认家庭账本显示“家庭账本”。
- `BookType.enterprise` 对外显示“公司账本”，数据库类型仍为 `enterprise`。
- 用户自定义账本取名称前两个 Unicode code point，显示为“前两个字 + 的账本”，例如“旅行的账本”。
- 首页和账本抽屉顶部使用统一标题；账本列表和 Quick Add 继续显示完整名称。
- Android 应用图标替换为用户提供的松鼠图片，并生成普通、圆形、自适应和单色资源。
- Android 启动页加入用户提供的竖版启动海报；Flutter 启动阶段使用 `BoxFit.contain`，保证完整海报不被屏幕比例裁切。
- iOS 应用图标未修改。

## 实现记录

- 新增 `lib/core/formatters/book_title_formatter.dart`，通过系统默认名称判断默认账本，不增加数据库字段。
- 新增 `lib/core/widgets/startup_poster.dart`，数据库初始化期间展示启动海报。
- Android 自适应图标改为独立的 `ic_launcher_app_foreground` 和 `ic_launcher_app_monochrome`；Android 12 系统过渡使用新图标，Flutter 首帧展示完整海报。
- 启动海报源文件：`assets/images/startup_poster.png`。
- Android 图标源文件：`docs/generated_assets/android_app_icon_source.png`。

## 验证结果

- `flutter analyze`：通过，无问题。
- `flutter test`：通过，191 项测试全部通过。
- `flutter build apk --debug`：通过。
- `flutter build apk --release`：通过。
- Release APK：`build/app/outputs/flutter-apk/app-release.apk`。
- APK 包名：`com.algive.jizhang_app`。
- APK `minSdk`：24；`targetSdk`：36。
- `apksigner verify`：通过，APK Signature Scheme v2 有效。
- Release APK SHA-256：`665cd11fff2d8ad97d1e29cb6260fa5c3f3f5ddcca9b65239a9db38256d9cff8`。
- 已检查生成的 Android 彩色、单色图标和启动海报资源；当前环境的 Android 模拟器启动后未保持在线，未完成 `adb` 真机/模拟器截图验证。

## 后续注意

- Android 12 及以上系统的原生 SplashScreen 会先显示系统约束的背景与图标，进入 Flutter 首帧后展示完整竖版海报；这是系统启动页机制限制，不是海报裁剪错误。
- Release 构建在未提供 `android/key.properties` 时使用本机 debug signing，适合直接安装测试；正式发布前应配置正式签名证书。
