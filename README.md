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

开发文档统一从 [`docs/development/README.md`](docs/development/README.md) 进入；当前状态见 [`docs/development/CURRENT_STATUS.md`](docs/development/CURRENT_STATUS.md)，架构全景见 [`docs/development/ARCHITECTURE.md`](docs/development/ARCHITECTURE.md)。原型资源位于 `docs/design_refs/`。

最终 Android Release APK 位于 `build/app/outputs/flutter-apk/app-release.apk`。未提供正式 keystore 时会使用 debug key 生成仅供本地验收的 Release APK；上架前必须配置 `android/key.properties`。构建说明见 [`docs/development/release/ANDROID_RELEASE.md`](docs/development/release/ANDROID_RELEASE.md)。
