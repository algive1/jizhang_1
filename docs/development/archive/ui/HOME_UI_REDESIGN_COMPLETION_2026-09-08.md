# 首页重设计交接记录（2026-09-08）

## 已完成

- 首页改为问候头部、月度汇总、安心可花 × 目标组合主卡、洞察、支出趋势、分类支出、净资产入口和最近记录。
- 删除首页重复的大号“本月支出”卡；月度结余与净资产保持不同语义。
- 支出趋势接入真实流水，支持周／月／年，点按和拖动选中金额。
- 分类支出使用彩色图标卡片，点击可查看该分类的真实流水并复用编辑／删除操作。
- “值得关注”改为可关闭的轻量洞察条，关闭状态持久化。
- 预算组合卡支持无预算、超预算、无目标和有目标状态；计算依据可展开。
- 目标增加排序和每月预留设置，默认不计入安心可花；目标进度和旧表单更新会保留排序与预留。
- 数据库 schema 升至 8，增加目标 `sortOrder` 与 `monthlyReservationInCents`，提供从旧版本的前向迁移。
- 记一笔改为图标分类网格、滑动类型切换、分组信息区、语音 Banner 和底部渐变保存按钮；金额点击展开键盘。
- 增加小屏／大字体／键盘／预算目标组合／趋势交互测试。

## 关键文件

- `lib/features/home/presentation/home_page.dart`
- `lib/features/home/presentation/home_cards.dart`
- `lib/features/home/presentation/home_expense_trend.dart`
- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`
- `lib/features/goals/presentation/goal_planning_sheet.dart`
- `lib/features/goals/data/goal_repository.dart`
- `lib/features/budgets/data/budget_repository.dart`
- `lib/core/database/app_database.dart`
- `lib/core/widgets/sliding_segmented_control.dart`
- `docs/HOME_UI_DESIGN_SPEC_2026-09-08.md`

## 验证结果

- `flutter analyze`：通过，无问题。
- `flutter test`：通过，102 个测试通过。
- `flutter build apk --debug`：通过，生成 `build/app/outputs/flutter-apk/app-debug.apk`。
- 已在 Android 模拟器检查无预算首页和记一笔页面；有效截图为 `docs/qa/home-redesign-2026-09-08/home-android.png` 与 `docs/qa/home-redesign-2026-09-08/quick-add-android.png`。

## 已知边界

“今日安心可花”仍是按月度预算日均计算的可解释中间结果；未来计划支出、固定账单、周期消费和云端同步尚未纳入。目标预留只有用户明确设置后才生效，不会移动账户资金。

## 下一窗口入口

先阅读本文件和 `docs/HOME_UI_DESIGN_SPEC_2026-09-08.md`，再从 `home_page.dart` 的真实数据状态开始。若扩展计划支出或年度预算，先补 domain/repository 口径和测试，再改组合卡文案。
