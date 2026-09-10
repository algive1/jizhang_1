# 账本抽屉执行记录：切片 4：首页最近交易

日期：2026-09-11

## 问题原因

首页原本从完整的 `transactionsProvider` 内存列表中 `take(6)`，没有在数据库层限制数量，也没有按本地日历日期分组。首页展示层与完整流水查询耦合，未来流水量增大时会无谓加载全部记录；切换账本后也缺少一个独立的、可实时更新的最近交易查询入口。原查询还没有明确排除未来时间流水，可能让计划流水占用“最近交易”的名额。

## 本切片修改

- `TransactionDao.watchActive/getActive` 增加可选 `limit` 和 `onlyOccurred`，仍复用 `visibleBooksSql` 和 `bookId` 条件；最近查询先用 `occurredAt <= now` 排除未来流水，再按 `occurredAt`、`createdAt`、`id` 倒序并在 SQL 层执行 `LIMIT`。
- `TransactionRepository` 增加 `watchRecent/getRecent`，由 `homeRecentTransactionsProvider` 通过当前账本 Repository 实时订阅固定 10 条已发生流水；完整 `transactionsProvider` 保留给预算、统计和分析，避免改变统计口径。
- 首页最近交易按 `occurredAt.toLocal()` 的日历日期分组，使用现有 `TransactionDateFormatter` 显示分组标题；分组内复用 `TransactionTile`，只显示本地时分，不重复显示“今天/昨天”。
- `TransactionTile` 的首页宽屏行增加 `showDate` 参数，默认行为保持不变；最近交易分组模式传入 `false`，账户名、金额颜色、点击/长按操作入口全部保留。
- 首页跨日期刷新时同步失效最近交易 Provider；新增数据库限量、流查询、账本隔离、本地分组和首页可见性测试，并修正使用真实 Provider 流的测试容器销毁顺序。

## 验证

```text
flutter analyze
→ No issues found

flutter test test/home_recent_transactions_test.dart
→ All tests passed（3 个，含未来流水不占最近 10 条）

flutter test test/widget_test.dart
→ All tests passed（11 个）

flutter test --reporter compact
→ All tests passed（162 个）

flutter test test/transaction_detail_test.dart
→ All tests passed（5 个，含缩略图/缩放预览和无系统处理器提示）

flutter build apk --release
→ Built build/app/outputs/flutter-apk/app-release.apk（77,607,562 bytes）
→ SHA-256: 76576e3e8b1b34d11e4d4875f8387923cc9c179272704597d90f98bf5a445bc8

APK 内容检查
→ 包含 assets/flutter_assets/assets/images/bookshelf_empty_background_v1.png

adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
→ Success；已在 Pixel 7 Android emulator 打开流水列表并进入交易详情页

flutter build ios --no-codesign
→ 未进入编译：项目现有 iOS 配置返回 `Application not configured for iOS`
```

视觉检查：模拟器当前页面确认交易详情的标题、编辑/更多操作、金额、发生时间、账户、分类、记录人、同步状态、附件空状态和底部导航显示正常；状态栏图标在米白背景上保持可读。

## 未完成与风险

- 预算、趋势和分析仍依赖完整当前账本流水，这是统计所需，不属于首页最近交易的展示限量；后续大数据量优化应分别做 SQL 聚合，不能直接复用最近 10 条。
- 最近查询的 `occurredAt <= now` 截止时间在 SQL 查询创建/失效时计算；应用长时间停留在前台时，未来流水到点后不会自动触发一次查询刷新，当前会在日期刷新、账本变化或流水变化时重新计算。若产品要求精确到发生分钟自动出现，需单独增加最近未来流水的定时刷新。
- 交易详情当前读取旧的 `metadata.attachments` 路径；独立附件表、旧 metadata 迁移、附件随备份恢复仍属于阶段二。
