# 2026-09-12 Android 安装包交付

## 任务与处理

用户要求构建可安装到手机的安装包。项目为 Flutter，README 明确当前优先 Android，因此复用 `scripts/build_install_android.sh --package-only` 构建当前工作区的通用 Release APK。未修改业务代码、版本号或签名配置，包含工作区已有的未提交改动。

## 交付产物

- 路径：`dist/jizhang_app-1.0.0+1-release.apk`
- 应用：好好记账
- 包名：`com.algive.jizhang_app`
- 版本：`1.0.0+1`
- 大小：83,349,092 bytes（约 83.3 MB）
- 最低系统：Android 7.0（API 24）；target SDK 36
- ABI：`arm64-v8a`、`armeabi-v7a`、`x86_64`
- SHA-256：`ec16fdbfc107e193b63145863d03dac9290ca41b086765a274f4b9c9ac07f0cf`

## 验证结果

- `flutter analyze`：无问题。
- `flutter test`：230 项全部通过，包含现有 UI/widget 与截图测试。
- Release 构建：成功。
- `apksigner verify --verbose --print-certs`：通过，APK Signature Scheme v2，Android Debug 证书。
- `aapt dump badging`：确认包名、版本、最低系统、ABI 和启动 Activity。
- `adb devices`：无连接设备；本轮未做真机/模拟器安装启动、设备 UI 或第三方 API 实际联调，不应将自动测试通过视为真机验收完成。

## 安装与后续

把 APK 传到 Android 手机后点击安装，按系统提示允许该来源安装应用。也可连接设备后执行 `adb install -r "dist/jizhang_app-1.0.0+1-release.apk"`。

当前使用现有本地 debug 签名，适合安装体验，不是正式商店发布包；若旧应用签名不同，覆盖安装可能失败，应先核实签名与备份数据，勿自动卸载。iPhone 无法安装 APK，本轮未生成 iOS 安装包。

构建存在 `speech_to_text` 的 Kotlin Gradle Plugin 未来兼容性警告，不影响本次构建。后续升级 Flutter 时需处理插件迁移。

构建和检查日志位于本机 `/tmp/jizhang-package-{analyze,test,build}-20260912.log`，临时日志不保证长期保留。后续重新构建会覆盖同名 APK，校验值须重新记录。
