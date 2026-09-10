# 账本、预算与首页金额修复交接记录

日期：2026-09-10

## 已完成

- 预算设置弹窗改为由弹窗自身管理 `TextEditingController`，修复取消/返回时的焦点树生命周期错误；保存异常会显示提示，总预算调整会预填原金额。
- 预算分类编辑保留原 `categoryId`，归档分类仍可编辑；分类预算不会因当前无可用分类而覆盖总预算；首页移除未实现的“本周预算”入口。
- 个人、家庭、企业账本使用独立默认分类模板；类型切换在同一事务内更新账本和分类，保留改名、改图标、自定义子分类、历史交易和预算引用；共享账本不会被本地模板静默补种。
- 账本抽屉的标题、说明、管理、关闭按钮叠加到木质顶栏，书架行展示真实账本类型图标与副标题；只渲染真实账本，超过三本可打开全部列表，切换成功/失败分别提示。
- 支出趋势保留真实周/月/年范围，改为暖色分段控件及经过真实数据点的受限平滑曲线；趋势数据仍来自当前账本真实流水。
- 首页金额眼睛在普通和大字窄屏下保持单行占位符；隐藏时同步隐藏目标金额/节点金额，装饰不会遮挡内容，显示/隐藏/再次显示不改变卡片和操作位置。
- 分类图标统一以分类名称和持久化 `icon` key 解析，彩色/列表样式使用同一 glyph；交易按 `bookId + categoryId` 反查名称和图标，支持改名、自定义分类和同 ID 的多账本分类。
- `TransactionRecord.copyWith` 支持显式更新 `categoryName`，更换分类时清掉旧的派生名称和图标，避免自动归类或收件箱修正时短暂显示旧分类。
- 账本 bootstrap 会补齐已存在账本缺失的新模板分类；新建目标在当前账本已有目标之后追加排序序号，暂停目标独立展示，目标排序面板只调整首页可展示的 active 目标。

## 关键文件

- `lib/features/budgets/presentation/budget_page.dart`
- `lib/features/home/presentation/home_cards.dart`
- `lib/features/home/presentation/home_expense_trend.dart`
- `lib/features/books/presentation/book_selector.dart`
- `lib/core/database/database_seeder.dart`
- `lib/core/database/category_templates.dart`
- `lib/core/widgets/category_icon.dart`
- `lib/core/models/transaction_record.dart`
- `lib/features/transactions/data/transactions_repository.dart`
- `lib/features/goals/data/goal_repository.dart`
- `lib/features/goals/presentation/goals_page.dart`

## 验证

- `flutter analyze --no-pub`：通过，无 issues。
- `flutter test --no-pub`：147 项全部通过。
- 分类一致性专项：4 项通过，覆盖统一 glyph、自定义 icon key、账本作用域反查和 `copyWith` 派生字段。
- 目标仓储专项：5 项通过，覆盖新目标追加排序、里程碑、贡献、预测和重启持久化。
- 账本分类范围专项：7 项通过，增加已存在账本缺失模板的 bootstrap 修复。
- 首页金额隐藏专项：12 项通过，覆盖 320/393dp、1.0/1.6 倍文字、目标进度、显示→隐藏→显示和几何稳定性；截图位于 `docs/qa/home-reference-2026-09-10/`。
- 预算归档分类真实路由交互测试：2 项通过，包含 NaN 拒绝、修改金额、保留分类归属和总预算。
- 账本分类范围专项：6 项通过，覆盖三类模板、旧账本升级、用户归档保持、类型往返、共享账本和 watcher 刷新。
- 金额隐藏专项：12 项通过，覆盖 320/393dp、1.0/1.6 倍文字、目标进度、显示→隐藏→显示和几何稳定性；截图位于 `docs/qa/home-reference-2026-09-10/`。
- `flutter build apk --release --no-pub`：通过。产物 [app-release.apk](/Users/algive/jizhang_01/build/app/outputs/flutter-apk/app-release.apk)，75.6 MB，SHA-256 `b2f9a79080c4e86bee0eaebb746256e252e1b664ba8776ee9f36bb64ccc2c7d3`。

## 验收边界

- 组件截图和自动化测试已完成；本轮 Android 模拟器启动过程中出现渲染/快照启动不稳定，未把它写成物理手机验收。APK 已构建成功，正式真机仍需在目标设备上点击预算取消、账本切换和小眼睛做一次手工回归。
- Release 构建仍有 `speech_to_text` 关于未来 Built-in Kotlin 的 warning，不影响本次构建结果。
