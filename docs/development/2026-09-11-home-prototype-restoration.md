# 首页卡片原型还原（2026-09-11）

## 问题原因

原型图使用暖白画布、橄榄绿重点色、插画背景和分层卡片；原有首页主要是流式布局和简单渐变，今日可用区域留白偏大，目标区只有普通进度条，资产卡缺少右侧立体插画，趋势卡和悬浮记账按钮也比原型占用更多空间。目标节点和隐私金额小圆点属于既有交互视觉，本次按用户要求保持原样。

## 修改内容

- `lib/features/home/presentation/home_cards.dart`
  - 压缩今日可用区域的垂直留白，保留真实预算、结余、剩余天数和金额隐藏联动。
  - 调整客厅插画、叶片和文案的定位，长金额/大字号时自动释放插画占位。
  - 给目标区增加轻量的浅绿白色内层、边框和阴影，保留 `GoalMilestoneService` 的真实里程碑及原有小圆点节点。
- `lib/features/home/presentation/home_asset_card.dart`
  - 接入 `home_asset_scene.png` 无字背景，使用左侧渐变保证真实资产数据的可读性。
  - 增加半透明总资产/总负债内层面板，保留加载、错误、空数据、多币种和隐私状态。
- `lib/features/home/presentation/home_expense_trend.dart`
  - 复用现有趋势图组件，压缩趋势区域高度，保留周/月/年切换和点按/拖动交互。
- `lib/core/widgets/quick_add_button.dart`
  - 去掉原生 FAB 的黑色重阴影，改为柔和橄榄绿阴影，更接近原型。
- `lib/core/constants/app_assets.dart`
  - 注册 `homeAssetScene` 资源。
- `assets/images/home_asset_scene.png`
  - 新增无文字资产卡插画背景，金额、账户和按钮仍由 Flutter 真实数据绘制。
- `docs/reference/home-prototype-2026-09-11.png`
  - 保存本次原型图的稳定引用；生成提示词记录在 `docs/generated_assets/home_asset_scene_prompt.md`。

## 验证

- `flutter analyze --no-pub`：通过，无 issues。
- 首页相关定向测试（18 个）：通过。
- `flutter test --no-pub`：通过，199 个测试。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 视觉截图：
  - `docs/qa/home-reference-2026-09-10/home-upper.png`
  - `docs/qa/home-reference-2026-09-10/home-prototype-393x698.png`

## 说明与局限

- 本次工作区原本存在大量未提交业务和资源修改，未执行 reset 或覆盖无关改动。
- 目标卡小圆点、目标金额显示口径和隐私金额小点均保持既有行为；原型中的大圆点没有照搬。
- 没有原型分层源文件和原始字体，因此插画与比例已按 393dp 做高相似度还原，不能宣称像素级完全一致。
- 全量测试中的 Drift 多数据库提示和 `speech_to_text` 的 Kotlin Gradle Plugin 兼容性提示属于既有 warning，未导致失败。
