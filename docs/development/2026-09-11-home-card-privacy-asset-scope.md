# 首页卡片、隐私开关与主账本资产范围

## 问题原因

首页卡片之前使用单层浅色渐变，资产总览的总资产/总负债缺少独立的内层面板，账户数量也没有和趋势卡控件形成右侧对齐。预算/目标卡共用一个金额状态，目标时间线的金额还没有独立隐私控制。账本模型没有记录资产来源，因此切换账本后账户和余额只能按当前账本隔离读取。

## 修改方案

- 资产总览增加更接近原型的半透明指标面板、边框、阴影和分隔线；账户数量保留在标题行右侧，与趋势卡控件同一右边界。
- 今日可用与目标卡的内层卡片改为不透明的浅绿底、边框和轻阴影，保留原有目标小圆点尺寸和节点逻辑，没有照搬原型有问题的大圆点。
- 支出趋势移除标题上方的“本月预算”，周/月/年切换移动到“支出趋势”标题同行。
- 新增 `HomeCardVisibility`，按账本分别保存今日可用、目标、资产总览三组独立开关。目标开关同时遮罩标题金额和时间线金额；支出趋势不再跟随今日可用开关。
- `books.asset_source_book_id` 记录资产来源。默认 `book-personal` 是主账本；新建账本提供“使用主账本资产”开关，账本管理中也可切换，账户、账户列表和流水校验会解析到相应资产账本。
- 数据库 schema 从 11 升到 12，并补充服务端共享账本 schema/迁移和首次共享 payload，避免共享 mutation 因未知字段失败。

## 关键文件

- `lib/features/home/presentation/home_asset_card.dart`
- `lib/features/home/presentation/home_cards.dart`
- `lib/features/home/presentation/home_expense_trend.dart`
- `lib/features/home/data/home_data.dart`
- `lib/features/home/presentation/home_page.dart`
- `lib/core/models/book.dart`
- `lib/core/database/app_database.dart` 和生成文件
- `lib/features/books/data/book_repository.dart`
- `lib/features/books/presentation/book_selector.dart`
- `lib/features/accounts/data/account_repository.dart`
- `lib/features/transactions/data/transactions_repository.dart`
- `lib/features/sharing/application/shared_book_sync_service.dart`
- `server/src/contract.ts`、`server/src/store.ts`、`server/src/app.ts`

## 验证结果

- `flutter analyze --no-pub`：通过。
- `flutter test --no-pub`：204 个测试全部通过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- `server/npm test`：2 个共享服务测试全部通过。
- `server/npm run build`：TypeScript 编译通过。
- `test/home_reference_page_capture_test.dart`：首页截图已重新生成并人工检查资产指标、目标边界和趋势控件位置。

## 风险与后续

主账本 ID 当前固定为种子账本 `book-personal`，这是应用启动默认账本的既有稳定 ID。若未来允许用户更换主账本，需要把 `asset_source_book_id` 从固定常量改为用户级设置并增加迁移策略。现有账本从共享资产切换为独立资产后，历史流水仍保留原账户 ID；再次切回共享资产可恢复对应账户余额，若长期保持独立状态，历史流水展示依赖账户名称回退逻辑。
