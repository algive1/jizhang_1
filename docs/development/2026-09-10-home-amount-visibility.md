# 首页金额显示状态记录

日期：2026-09-10

## 检查结果

首页金额眼睛只控制 `HomeSpendingGoalCard` 内的金额：可用金额、收支结余以及目标卡金额节点。首页月度汇总等其他区域没有接入该按钮，因此保持原有显示范围。

## 修复内容

- 大字 1.6 模式下隐藏首页卡片装饰插图与宣传文案，避免在 320dp/393dp 窄屏覆盖预算控件和金额。
- 大字模式将金额区改为自然高度，使用固定间距连接金额和收支结余，避免固定高度加 Spacer 产生大片空洞；金额与结余各自保留稳定的单行槽位，隐藏/显示不会改变卡片高度。
- 金额文本增加单行约束，长金额会整体缩放，不会拆成多行。
- 保留 0 金额与长金额的真实显示；隐藏后统一显示掩码，不泄露数值。
- 新增多尺寸真实 widget 截图和断言测试，包含有目标进度的金额隐藏联动，并验证切换前后按钮与卡片高度稳定。

## 验证

- `flutter analyze lib/features/home/presentation/home_cards.dart test/home_amount_visibility_test.dart`：通过。
- `flutter test test/home_amount_visibility_test.dart test/home_reference_interaction_test.dart`：通过。
- 测试尺寸：320×700、393×844，文本倍率 1.0 和 1.6，并包含目标进度。
- 截图：`docs/qa/home-reference-2026-09-10/home-amount-visible-320.0-1.0.png`、`home-amount-hidden-320.0-1.6.png` 及对应 393dp 图片。
- 已通过 `view_image` 审查可见/隐藏状态，未发现遮挡或金额泄漏。

## 交付提示

修改了首页 Dart UI 文件，集成前需要重新构建 APK 才能在 pixel_7 实机看到更新。
