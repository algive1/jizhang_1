# 好好记账

基于 Flutter 的个人记账 App，视觉方向为 Warm Soft Finance：暖米白、柔和鼠尾草绿、轻量卡片和高可读财务数据。当前阶段优先完成 Android，iOS 按产品安排暂缓。

## 当前能力

- 首页、流水、消费分析、目标详情、我的五类核心页面
- 四个一级导航：首页、流水、目标、我的
- 中央快速记账入口；手动记账支持金额、分类、备注并持久化到本地 Drift/SQLite
- 流水支持全部/支出/收入筛选、商户/分类搜索、分类筛选
- 流水支持编辑、分类修正和软删除，删除会同步撤销账户余额影响
- 目标里程碑由 `GoalMilestone` 数据动态生成
- 默认新账本不写入演示流水；演示数据仅在预览测试中显式启用
- 首页、流水、消费分析、目标详情、我的已完成 Android 原型截图验收
- Android 已配置中文应用名、自适应/圆形/单色主题图标和暖色启动页

## 开发

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

Android 模拟器一键构建、安装并启动：

```bash
./scripts/build_install_android.sh
```

默认启动可用 AVD、构建 release APK、覆盖安装并打开应用，同时把可直接安装的 APK 输出到 `dist/`；只打包手机安装包时执行 `./scripts/build_install_android.sh --package-only`。需要单独启动模拟器时执行 `./scripts/open_android_emulator.sh`。更多选项见 [`docs/development/ANDROID_LOCAL_RUN.md`](docs/development/ANDROID_LOCAL_RUN.md)。

开发文档统一从 [`docs/development/README.md`](docs/development/README.md) 进入；当前状态见 [`docs/development/CURRENT_STATUS.md`](docs/development/CURRENT_STATUS.md)，架构全景见 [`docs/development/ARCHITECTURE.md`](docs/development/ARCHITECTURE.md)。原型资源位于 `docs/design_refs/`。

最终 Android Release APK 位于 `build/app/outputs/flutter-apk/app-release.apk`。未提供正式 keystore 时会使用 debug key 生成仅供本地验收的 Release APK；上架前必须配置 `android/key.properties`。构建说明见 [`docs/development/release/ANDROID_RELEASE.md`](docs/development/release/ANDROID_RELEASE.md)。

## 源码打包

交付或备份整套源码（Flutter 客户端 + Node 共享账本服务 + Android/iOS 原生工程）：

```bash
./scripts/package_source.sh              # 生成 jizhang_app_source_<时间戳>.zip 到工程根目录
./scripts/package_source.sh --out ~/Desktop
./scripts/package_source.sh --list       # 只查看将被打包的文件
```

构建产物（`build/`、`dist/`、APK）、依赖缓存（`.dart_tool/`、`node_modules/`、`ios/Pods/`）、服务端运行时数据库和 QA 截图归档默认不入包；需要截图归档时加 `--with-qa-docs`。范围和验证记录见 [`docs/development/2026-09-18-source-package-delivery.md`](docs/development/2026-09-18-source-package-delivery.md)。

## 版本管理（Git）

工程根目录是唯一的 Git 工作区，分支 `main`，远端 `origin` 指向 <https://github.com/algive1/jizhang_1.git>。整套工程（Flutter 源码、Android/iOS 原生工程、Node 共享账本服务、测试、开发文档与 QA 截图归档）都随源码跟踪，不依赖 `git submodule`。

```bash
git status                      # 应保持干净：项目内容全部已跟踪
git add -A && git commit -m "..."   # 纳入新增源码/文档/资源
git push origin main            # 备份到远端
```

跟踪规则（详见 [`.gitignore`](.gitignore)）：

| 类别 | 是否跟踪 | 说明 |
| --- | --- | --- |
| `lib/`、`test/`、`android/`、`ios/`、`server/src`、`server/test`、`scripts/`、`assets/`、`docs/` | 跟踪 | 源码、测试、文档、设计与验收资源 |
| `build/`、`dist/`、`.dart_tool/`、`android/.gradle/`、`ios/Pods/`、`server/node_modules/` | 忽略 | 可重建的构建/依赖产物；安装包 `dist/*.apk` 不随仓库分发，需要分发时上传 GitHub Release |
| `jizhang_app/`、`jizhang_app_source_*.zip` | 忽略 | `scripts/package_source.sh` 产出的源码快照，可随时重建 |
| `android/key.properties`、`*.jks`、`*.keystore` | 忽略 | 签名材料不入库 |

`haohaojizhangœ/` 是另一个独立仓库（`algive1/haohaojizhang-.`），与本 App 无关，历史提交中以 gitlink 记录、不参与本工程构建。

远端仓库创建时自带的 `Initial commit`（`LICENSE` + 占位 README）与本地历史没有共同祖先，2026-09-18 用 `git merge origin/main --allow-unrelated-histories` 合并收口：README 以本文件为准，MIT `LICENSE` 保留。
