# 首页上半区实施记录（2026-09-10）

## 修改范围

- `lib/features/home/presentation/home_page.dart`：移除首页主流程中的旧月度汇总和净资产卡；加入真实组合卡、洞察卡、Pro 卡；更新背景、边距和头部路由入口。
- `lib/features/home/presentation/home_promotional_cards.dart`：新增 `HomeInsightCard`、`HomeProCard` 和几何绘制的 `HomeCrownIcon`。洞察数据来自 `homeInsightProvider`，Pro 云朵素材置于文字后方并降低透明度。
- `lib/core/constants/app_assets.dart`：登记 Pro 云朵素材。
- `lib/features/home/presentation/home_cards.dart`：组合卡窄屏使用真实布局约束判断；主金额和目标当前金额使用原型绿色，目标标题使用深色，并保留大字号可伸展布局。
- `test/widget_test.dart`、`test/home_books_month_test.dart`：同步新首页入口和组合卡高度语义。

## 验证

- `flutter analyze`：通过。
- `flutter test test/home_redesign_visual_test.dart test/widget_test.dart`：通过。
- `flutter test test/home_spending_goal_card_preview_test.dart test/home_books_month_test.dart test/home_reference_interaction_test.dart`：通过。
- 组合卡截图：`docs/qa/home-reference-2026-09-10/home-spending-goal-card.png`。

整页上半截图由主代理的 `home_reference_page_capture_test.dart` 负责生成和验收。
