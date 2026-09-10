# 账本抽屉执行记录：切片 4：首页最近交易

日期：2026-09-11

## 问题原因

首页原本从完整的 `transactionsProvider` 内存列表中 `take(6)`，没有在数据库层限制数量，也没有按本地日历日期分组。首页展示层与完整流水查询耦合，未来流水量增大时会无谓加载全部记录；切换账本后也缺少一个独立的、可实时更新的最近交易查询入口。

## 本切片修改

- `TransactionDao.watchActive/getActive` 增加可选 `limit`，仍复用 `visibleBooksSql` 和 `bookId` 条件，按 `occurredAt`、`createdAt`、`id` 倒序后在 SQL 层执行 `LIMIT`。
- `TransactionRepository` 增加 `watchRecent/getRecent`，由 `homeRecentTransactionsProvider` 通过当前账本 Repository 实时订阅固定 10 条；完整 `transactionsProvider` 保留给预算、统计和分析，避免改变统计口径。
- 首页最近交易按 `occurredAt.toLocal()` 的日历日期分组，使用现有 `TransactionDateFormatter` 显示分组标题；分组内复用 `TransactionTile`，只显示本地时分，不重复显示“今天/昨天”。
- `TransactionTile` 的首页宽屏行增加 `showDate` 参数，默认行为保持不变；最近交易分组模式传入 `false`，账户名、金额颜色、点击/长按操作入口全部保留。
- 首页跨日期刷新时同步失效最近交易 Provider；新增数据库限量、流查询、账本隔离、本地分组和首页可见性测试，并修正使用真实 Provider 流的测试容器销毁顺序。

## 验证

```text
flutter analyze
→ No issues found

flutter test test/home_recent_transactions_test.dart
→ All tests passed（2 个）

flutter test test/widget_test.dart
→ All tests passed（11 个）

flutter test --reporter compact
→ All tests passed（156 个）

flutter build apk --release
→ Built build/app/outputs/flutter-apk/app-release.apk（77,246,250 bytes）
→ SHA-256: 8f02cf23a18227d2e5fe591f9247c35149bb75d788732d9e9b4743405afd5213

APK 内容检查
→ 包含 assets/flutter_assets/assets/images/bookshelf_empty_background_v1.png

adb devices
→ 没有连接 Android 设备，因此未进行安装和真机截图验收
```

视觉检查：重新生成并检查了 `docs/qa/home-reference-2026-09-10/home-lower.png`，确认“最近交易”出现日期分组标题，行内时间不再重复日期，账户名与金额列仍对齐。

## 未完成与风险

- 预算、趋势和分析仍依赖完整当前账本流水，这是统计所需，不属于首页最近交易的展示限量；后续大数据量优化应分别做 SQL 聚合，不能直接复用最近 10 条。
- 最近交易继续遵循现有 active transaction 语义，未来时间流水不会被本切片额外过滤；如产品确认计划流水不应出现在首页，需要单独定义并测试该业务规则。
- 交易详情统一入口、附件缩略图/预览/系统打开和缺失文件状态仍未实现。
