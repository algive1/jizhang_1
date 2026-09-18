# 资产详情弹窗布局调整（2026-09-14）

## 需求

资产总览中点击资产分布、资产变化后的详情弹窗，去掉卡片内部重复标题，只保留弹窗标题并居中。资产变化详情的“近 7 天 / 近 30 天 / 近 1 年”三个按钮放到变化金额右侧，与金额同一行并调整为更易点击的尺寸。

## 修改

- `lib/features/accounts/presentation/asset_dashboard_charts.dart`
  - `AssetDistributionDetail` 和 `AssetTrendDetail` 移除卡片内部的 `AssetSectionHeading`，主页面上的“资产分布”和“资产变化”标题保持不变。
  - `AssetTrendPeriodSelector` 增加详情态尺寸：三个按钮宽 58dp、高 36dp；主页面卡片继续使用原紧凑尺寸。
  - 详情态把金额与区间按钮放在同一行，百分比说明移到金额行下方；三个按钮位于右侧并与金额垂直居中。
  - 存在未来日期流水时仍显示区间按钮，提示内容位于左侧，避免筛选入口消失。
- `lib/features/accounts/presentation/asset_overview_page.dart`
  - `_AssetSheetFrame` 使用居中标题层和右侧关闭按钮，标题不再因关闭按钮宽度发生视觉偏移。
- `lib/features/accounts/domain/asset_history.dart`
  - “未来流水”按本地日历日期判断。今天稍后的时间点仍属于今天的趋势，只有日期晚于今天才禁用历史曲线，避免种子数据/日内流水让趋势详情误显示不可用。
- `test/asset_overview_interaction_test.dart`
  - 验证两个详情标题各只出现一次、趋势弹窗标题居中、金额与按钮左右关系和垂直对齐，并增加 320dp 窄屏回归。

## 验证

- `flutter analyze lib/features/accounts/domain/asset_history.dart lib/features/accounts/presentation/asset_dashboard_charts.dart lib/features/accounts/presentation/asset_overview_page.dart test/asset_overview_interaction_test.dart`：通过。
- `flutter test test/asset_overview_interaction_test.dart`：2 项全部通过。
- 资产相关回归：`asset_overview_interaction_test.dart`、`asset_overview_layout_test.dart`、`asset_visual_qa_test.dart`、`home_asset_card_test.dart`、`home_asset_scope_test.dart`、`asset_management_test.dart`，全部通过。

## 交接提醒

- 本轮只调整详情弹窗的标题和趋势控件，不改变资产计算、账户余额、趋势数据或点击导航链路。
- 资产总览的视觉截图测试会覆盖主页面；详情弹窗的标题唯一性和按钮几何关系通过 widget 断言验证。
