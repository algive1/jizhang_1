# 首页金额隐藏范围与目标归档

日期：2026-09-11

## 问题原因

- 首页 `_amountHidden` 原先同时传给洞察、预算/目标卡、资产卡、支出趋势、分类支出和最近交易，导致小眼睛的作用范围超过了产品要求。
- 目标数据层已有级联删除 DAO，但 `GoalRepository` 没有目标级删除/状态操作，目标详情菜单也没有归档或恢复入口。

## 修改内容

- 新增按账本保存的首页金额可见性状态，配置键为 `home.amountsHidden.<bookId>`。
- 小眼睛现在只控制“今日可用”主金额和资产卡片的净资产、总资产、总负债。
- 目标当前金额、目标金额、阶段节点、收支结余副标题、洞察、趋势、分类、最近交易和计算依据保持显示。
- 隐藏占位符使用独立字号与字距，同时保留金额区域和卡片的布局高度。
- 新增 `GoalRepository.archive` 与 `restore`：归档只修改目标状态，保留目标、阶段节点和贡献记录；恢复时未完成目标回到 `active`，已达成目标回到 `completed`。
- 目标详情增加归档/恢复菜单和归档确认；目标页增加“已归档”区域。
- 归档目标不再计入 `active` 目标预留，因此会从“今日可用”的预留计算中移除。
- 没有改数据库结构，也没有暴露永久删除入口；共享账本沿用现有目标状态同步机制。

## 关键文件

- `lib/features/home/data/home_data.dart`
- `lib/features/home/presentation/home_page.dart`
- `lib/features/home/presentation/home_cards.dart`
- `lib/features/home/presentation/home_asset_card.dart`
- `lib/features/goals/data/goal_repository.dart`
- `lib/features/goals/presentation/goals_page.dart`
- `lib/features/goals/presentation/goal_detail_page.dart`

## 验证结果

- `flutter analyze`：通过，无 issues。
- `flutter test`：通过，197 项全部通过。
- 重点覆盖：按账本保存隐藏状态、隐藏范围与字号布局、目标归档/恢复、目标流刷新、共享数据回归、320/393dp 和大字号布局。
- 全量测试过程中出现项目既有的 Drift 多数据库 warning，但没有测试失败或 Flutter layout error。

## 当前风险

- 尚未在真实 Android 设备上手工确认字体渲染和小眼睛触摸体验；自动化测试已覆盖主要尺寸与文字缩放组合。
- 归档是可恢复的状态操作，不会立即清理目标历史数据；永久删除仍未提供。
