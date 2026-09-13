# 金额隐藏圆点样式修复

日期：2026-09-11

## 问题原因

金额隐藏态直接复用了正常金额的 `TextStyle`，因此大字号金额会把圆点一起放大；资产总览的自定义金额组件还会因为隐藏文本变短而改变金额行的尺寸。

## 修改内容

- 新增 `PrivacyAmount` 公共组件，显示态原样使用传入的金额文本和样式。
- 隐藏态统一使用固定 `13px`、`letterSpacing: 3`、`••••`，并禁用系统文字倍率对掩码的放大。
- 隐藏态通过正常金额文本测量结果保留金额区域的行高，避免卡片高度和上下内容跳动。
- 首页“今日可用”与“资产总览”统一接入该实现；保留现有正常金额字号、字重、颜色、字距、货币符号和格式。
- 沿用现有首页金额可见性范围和按账本保存逻辑，没有新增字号设置或改变卡片结构。
- 增加公共组件字号/行高测试，以及首页预算卡、资产卡切换前后的几何稳定性断言。

## 涉及文件

- `lib/core/widgets/privacy_amount.dart`
- `lib/core/widgets/money_text.dart`
- `lib/features/home/presentation/home_cards.dart`
- `lib/features/home/presentation/home_asset_card.dart`
- `test/privacy_amount_test.dart`
- `test/home_amount_visibility_test.dart`
- `test/home_asset_card_test.dart`

## 验证结果

- `flutter analyze`：通过，无 analyzer issues。
- `flutter test`：通过，198 项全部通过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 已通过首页隐藏态截图检查：圆点为小号、低调显示，预算卡装饰区域无覆盖。

## 当前风险

- 尚未在真实 Android 设备上手工确认字体渲染；自动化测试已覆盖首页 320/393dp 与 1.0/1.6 文字倍率。
- 全量测试中的 Drift 多数据库提示和 Debug 构建中的 Kotlin Gradle Plugin 提示均为项目/依赖现有 warning，本次没有新增失败。
