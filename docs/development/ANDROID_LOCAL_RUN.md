# Android 本地模拟器一键运行

项目包名：`com.algive.jizhang_app`

## 一键构建、安装并启动

在项目根目录执行：

```bash
cd /Users/algive/jizhang_01
./scripts/build_install_android.sh
```

脚本默认会：

1. 复用已运行的 Android 模拟器；如果没有运行中的模拟器，则启动第一个可用 AVD。
2. 执行 `flutter pub get`。
3. 执行 `flutter build apk --release`。
4. 使用 `adb install -r` 覆盖安装 APK，并保留应用数据。
5. 启动 `MainActivity`。

可直接拷贝到 Android 手机安装的产物：

```text
dist/jizhang_app-1.0.0+1-release.apk
```

## 只生成手机安装包

如果只是要把 APK 发到手机，不需要启动模拟器：

```bash
./scripts/build_install_android.sh --package-only
```

生成后把 `dist/` 下的 APK 传到手机，点击即可安装；也可以在手机开启 USB 调试后执行：

```bash
adb install -r "dist/jizhang_app-1.0.0+1-release.apk"
```

## 只启动并等待模拟器

```bash
./scripts/open_android_emulator.sh
```

当前开发机可用的 AVD 是 `pixel_7`，也可以显式指定：

```bash
./scripts/open_android_emulator.sh pixel_7
```

查看本机 AVD：

```bash
flutter emulators
```

## 常用选项

构建并安装 Release APK：

```bash
./scripts/build_install_android.sh --release
```

构建 Debug APK 并安装到模拟器：

```bash
./scripts/build_install_android.sh --debug
```

指定 AVD：

```bash
./scripts/build_install_android.sh --emulator pixel_7
```

指定已经连接的 Android 设备：

```bash
./scripts/build_install_android.sh --device emulator-5554
```

跳过依赖解析，适合依赖没有变化时加快执行：

```bash
./scripts/build_install_android.sh --no-pub-get
```

首次从 Git 检出项目后，如果执行权限尚未保留，可执行：

```bash
chmod +x scripts/open_android_emulator.sh scripts/build_install_android.sh
```

## 后续给 Codex 调用

后续需要重新编译并安装到当前模拟器时，直接调用：

```bash
cd /Users/algive/jizhang_01
./scripts/build_install_android.sh --no-pub-get
```

脚本会自动检测在线模拟器，不依赖固定的 `emulator-5554` 设备序列号。

## 注意事项

- 默认是 release 构建，适合发到 Android 手机安装；需要 Flutter 调试和热重载时使用 `--debug`。
- `--release` 仍使用当前项目配置的本地签名策略；正式上架前需要配置正式 keystore。
- `adb install -r` 会覆盖安装但保留本地数据；不同签名导致冲突时，需要先手动卸载旧包，脚本不会自动删除应用数据。
- 如果提示没有可用 AVD，请先用 Android Studio 创建模拟器，或执行 `flutter emulators --create`。
