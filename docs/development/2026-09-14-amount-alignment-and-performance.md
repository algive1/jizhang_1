# 金额右对齐与 Android 卡顿排查（2026-09-14）

## 用户要求

去掉金额输入框中的清空 X，结果右对齐；排查多个页面掉帧卡顿。

## 已确认的证据

1. 连接手机上 `com.algive.jizhang_app` 的 package flags 包含 DEBUGGABLE，当前为调试包。调试模式额外开销影响性能评估。
2. Android 的 `_openConnection()` 使用 `NativeDatabase(file)`，常规 SQL 在 UI isolate 执行。桌面原已使用 `NativeDatabase.createInBackground`。查询、写入和同步数据库操作会与页面绘制争用 UI 线程。
3. 该分支注释来自历史系统 SQLite 加载兼容处理。但当前 pubspec 已打包官方 sqlite3 native assets，9 月 7 日审计记录也已确认系统库加载问题由官方打包方案解决。
4. 手机系统 gfxinfo 的历史统计为 458 帧、44 个 janky frames、32 次 slow UI thread。这是 Android 窗口统计，不能直接当作 Flutter 全部帧的掉帧率，更不是某个页面的根因证明。未清除统计、未操作账本数据、未替换手机应用。

## 修改文件与逻辑

- `lib/features/bookkeeping/presentation/components/amount_input_view.dart`：删除清空 IconButton 及 onClear 参数；保留公式淡化、结果强调，结果对齐金额卡片右内边距。
- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`：删除失效的 onClear 传参；数字键盘退格仍可正常编辑输入。
- `lib/core/database/app_database.dart`：Android 与桌面统一使用 NativeDatabase.createInBackground，将常规 SQL 操作移出 UI isolate。未改数据库 schema、表字段、账本范围、保存事务或查询筛选条件。启动阶段迁移备份的既有逻辑不变。
- `test/quick_add_redesign_test.dart`：校验没有清空 X，结果右边界与金额卡片内边距对齐，更新真实 widget 截图。
- `test/widget_test.dart`：旧清空按钮点击断言改为按钮不存在。
- `test/background_database_test.dart`：使用真实临时 SQLite 文件及后台连接，验证建库种子、流通知、新增、更新、关闭重开持久化、软删除。

## 验证

- `flutter analyze`：通过。
- 记账、数据库仓库、种子、备份、首页新增交易回归：29 项通过。
- 后台文件数据库与最新金额布局回归：14 项通过（与上组有重复，不应相加宣称独立用例总数）。
- 人工查看最新 `docs/qa/quick-add-layout-2026-09-14/entry-393.png`，已无金额清空 X，结果右对齐。
- `flutter build apk --release`：通过，产物 `build/app/outputs/flutter-apk/app-release.apk`（约 83 MB）。有既有插件 Kotlin Gradle 与 deprecated API 提示，不阻塞构建。未安装到用户手机。

## 性能结论与边界

已修复一个跨页面的明确阻塞风险，但没有逐页 Flutter timeline/FrameTiming 对比数据，不能宣称所有卡顿已经解决。后台连接测试运行在桌面测试主机；Android 新版本的冷启动、记账和连续导航尚未真机验收。当前手机仍保留原调试版本。

后续先在真机使用 Release/Profile 模式验证数据库启动、正常记账与跨页面滚动，并采集 Flutter 帧耗时；若仍卡顿，再针对实际热点处理大量同日流水布局、图片解码或动画，避免没有测量依据的大规模重构。
