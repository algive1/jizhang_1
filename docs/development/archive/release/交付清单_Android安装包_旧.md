# 交付清单 — jizhang_app Android 安装包

- 生成时间：2026-09-08（会话内核对）
- 项目根目录：`/Users/algive/jizhang_01`
- 包名：`com.algive.jizhang_app`（`android/app/build.gradle.kts`）
- 版本：`1.0.0+1`（`pubspec.yaml`，versionName=1.0.0 / versionCode=1）

## 交付物

| 项目 | 路径 | 校验结果 |
| --- | --- | --- |
| Android Release 安装包（主交付物） | `build/app/outputs/flutter-apk/app-release.apk` | ✅ 存在，68,435,848 字节（≈65.3 MB），mtime 2026-09-08T02:18:07Z |
| 同款产物副本（Gradle 旧输出目录） | `build/app/outputs/apk/release/app-release.apk` | ✅ 存在 |
| 一键打包脚本（供后续重新打包） | `build_apk_release.sh` | ✅ 已生成（UTF-8） |
| 打包说明文档 | `打包安装包说明.md` | ✅ 已生成（UTF-8） |

## 打包方式（本次）

用户确认：**直接采用现有 Release APK，不重新构建**（最近未改代码的前提由用户确认）。
Release 配置在缺少 `android/key.properties` 时自动退回 debug 签名
（见 `android/app/build.gradle.kts` buildTypes.release），产物可 `adb install` 直接安装自用。

## 安装方法

```bash
cd /Users/algive/jizhang_01
adb install -r "build/app/outputs/flutter-apk/app-release.apk"
```

或将 APK 发送到手机后点击安装（需允许"安装未知来源应用"）。

## 备注

- 重新打包（含代码改动后）请执行：`bash build_apk_release.sh`，产物输出到 `dist/`。
- 正式上架商店前必须在 `android/key.properties` 配置正式签名并重新打包。
