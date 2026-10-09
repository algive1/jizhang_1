# Android 1.0.1 打包安装记录

日期：2026-10-06。

## 产物

- Release ARM64：`dist/jizhang_app-1.0.1+6021-release-arm64-v8a.apk`
- 包名：`com.algive.jizhang_app`
- APK 与设备版本均为 `versionName=1.0.1`、`versionCode=6021`
- 大小：67,816,518 bytes
- SHA-256：`2C8D4F1AB56C7BF5A9AFD7C087C5DE7E76B68AE1A0B07DAFF3CD6E4E9A0ADDB4`

## 版本规则

Windows `记账工具.bat` 与 `scripts/build_install_android.sh` 共用 `scripts/bump_build_version.dart`，编译前将末位版本号和构建号加 1，下一次为 `1.0.2+6022`。失败的编译也保留已分配版本，安装已有 APK 不递增。

`android/gradle.properties` 统一拆分包与通用包的构建号，避免切换包类型时发生降级。直接使用 Flutter CLI 时先运行版本脚本；本次也通过该脚本分配版本后构建。

## 验证

- 版本脚本实际连续输出 `1.0.1+6021`、`1.0.2+6022`，配置其余内容及 CRLF 保持一致；静态分析通过。
- Windows PowerShell 语法、Bash 语法及帮助入口通过；相关变更 `git diff --check` 通过。
- `flutter build apk --release --no-pub --target-platform android-arm64 --split-per-abi` 成功，Gradle 耗时 188.7 秒。
- 设备 `145a0a68`、型号 `23116PN5BC`：`adb install -r` 返回 `Success`，从 `1.0.0/6020` 覆盖升级。
- 原首次安装时间仍为 `2026-09-21 00:23:52`，未卸载或清空数据。
- `MainActivity` 启动返回 `Status: ok`，处于前台，首页和原有数据可见；应用进程持续运行，未发现 Flutter 运行错误或致命异常。

编译仍出现 KGP 迁移、Alipay iOS 插件及 Cupertino 字体相关提示。启动日志出现安全存储初始化回退，随后首页正常显示；本次未改动安全存储。

构建、安装、启动、设备版本日志及首页截图位于 `.agent/version-increment-20261006/`。本次为打包安装验收，业务回归沿用此前已通过的 121 项相关检查。
