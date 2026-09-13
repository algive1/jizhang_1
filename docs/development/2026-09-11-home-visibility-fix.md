# 首页金额显示修复记录

日期：2026-09-11

## 问题原因

预算/目标卡的金额使用 `FittedBox`，但金额文本实际获得了整行的松约束；长金额因此会绘制到右侧家具插图和宣传文案区域。点击小眼睛后，掩码文本也沿用了这套区域，导致 `¥` 和圆点看起来挤压、错位。

## 修改内容

- 在 `HomeSpendingGoalCard` 中区分真实金额文本与隐藏掩码文本。
- 普通长度金额保留右侧装饰，同时给金额预留装饰区域。
- 金额长度超过装饰安全范围时自动隐藏装饰，金额使用完整宽度并保持单行缩放，避免任何重叠。
- 隐藏/显示仍只替换金额文本，不改变卡片、预算入口、计算入口和目标区域的几何位置。
- 扩展金额隐私测试，覆盖长金额与装饰安全边界；保留 320/393dp、1.0/1.6 倍文字和显示→隐藏→显示回归。
- 首页“值得关注”改为读取现有 `StatisticalAnalysisService` 的全天分类/行为洞察，不再直接用深夜消费金额充当提醒；有阈值的洞察会附带对应的查看或预算建议，无有效洞察时保持隐藏。
- 增加首页洞察 Provider 测试，验证全天分类变化、建议文本和阈值不足时的安静状态。

## 验证结果

- `flutter test test/home_amount_visibility_test.dart`：通过，4 项尺寸/字号组合通过。
- `flutter test test/home_insight_provider_test.dart`：通过，2 项全天洞察 Provider 测试通过。
- `flutter test test/home_insight_daily_test.dart`：通过，覆盖无洞察保持隐藏、每天一次、切换账本/重挂载、跨日展示及 320ms 展开动画。
- `flutter test test/home_header_cards_test.dart test/home_insight_daily_test.dart test/home_amount_visibility_test.dart test/home_reference_interaction_test.dart`：通过，10 项通过。
- `flutter analyze`：通过，无 issues。
- `flutter test`：通过，175 项通过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 已通过截图检查长金额显示和隐藏状态，右侧装饰不会覆盖金额。

## 当前限制

- 小眼睛的控制范围仍是预算/目标组合卡内的金额，支出趋势、分类和最近交易保持原有显示范围；如需全首页隐私开关，应另行设计统一状态并覆盖所有金额组件。
- Android 真机上的触摸和字体渲染仍需在目标设备做一次手工回归。
