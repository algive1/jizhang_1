# 账本抽屉、会员入口与收支趋势样式联动记录

日期：2026-09-11

## 问题原因

- 账本抽屉的顶部标题、副标题、管理按钮和关闭按钮使用了相互独立的绝对定位，窄屏或较大系统字体下会发生重叠。
- 账本条目此前主要是高饱和色块，缺少原型中的浅色封面、叠放书脊、图标面板、叶片装饰和选中状态层次。
- 首页会员入口使用了独立的皇冠绘制样式，和通知、搜索按钮的圆形控件不统一；抽屉顶部没有对应入口。
- 首页和分析页各自维护趋势图绘制器，曲线、网格、填充、选中提示和间距不一致。

## 本次修改

- `lib/features/books/presentation/book_selector.dart`
  - 将抽屉顶部操作收敛到同一行布局，标题和副标题使用 `Flexible`、`FittedBox`、省略策略，管理按钮和关闭按钮保留独立可点击区域。
  - 增加与首页一致的 `MembershipButton`。
  - 重做账本行的封面视觉：按个人、家庭、企业账本区分柔和底色和强调色，加入三层书脊、图标面板、叶片装饰、阴影与选中勾选。
  - 保留原有账本选择、长按管理、新建账本和关闭行为。
- `lib/core/widgets/membership_button.dart`
  - 新增统一的会员圆形入口，复用应用主色体系，支持 tooltip 和外部点击回调。
- `lib/features/home/presentation/home_page.dart`
  - 首页会员按钮改为共享组件，并统一通知、搜索按钮的尺寸、间距和圆形样式。
- `lib/features/home/presentation/home_promotional_cards.dart`
  - 保留 `HomeCrownIcon` 兼容名称，但内部改为统一的 Material 会员图标，移除独立绘制器。
- `lib/core/widgets/cashflow_trend_chart.dart`
  - 新增共享趋势图组件和绘制器，统一虚线网格、平滑曲线、支出面积填充、选中竖线、提示气泡和坐标标签。
- `lib/features/home/presentation/home_expense_trend.dart`
  - 首页趋势改用共享组件，保留首页按月份聚合和交互选择逻辑。
- `lib/features/analysis/presentation/cashflow_cards.dart`
  - 收支趋势卡片改用共享组件，同时保留收入、支出双序列和当前分析范围的数据逻辑；卡片容器、图例和摘要调整为首页的温和视觉语言。
- `test/book_selector_ui_test.dart`、`test/product_visual_regression_test.dart`
  - 增加会员入口和趋势组件的回归断言。

## 交互与联动核对

- 首页：会员、通知、搜索三个入口均为统一尺寸的圆形控件。
- 个人账本抽屉：顶部出现会员按钮，账本标题、管理、关闭按钮不再互相覆盖；选择账本、关闭抽屉和管理账本逻辑保持可用。
- 账本封面：个人、家庭、企业三种类型均使用原型方向的浅色封面和书脊层次，选中状态有绿色勾选。
- 趋势：首页趋势和分析页收支趋势共用同一绘制组件，曲线、网格、填充、选中反馈保持一致。

## 验证结果

- `flutter analyze`：通过，无 issues。
- `flutter test test/book_selector_ui_test.dart test/widget_test.dart`：通过。
- `flutter test test/statistical_analysis_service_test.dart test/product_visual_regression_test.dart`：通过。
- `flutter test test/home_reference_page_capture_test.dart`：通过，已重新生成首页和账本抽屉 QA 截图。
- `git diff --check`：通过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。

## 风险与后续

- 本次未连接实体 Android 设备，尚未覆盖不同厂商系统字体、刘海和真实触控环境；代码级布局、Widget 测试和截图已完成验证。
- 抽屉顶部副标题在窄屏会按设计省略，避免重新产生控件重叠。
- 叶片装饰目前使用 Material 图标近似原型纹理，若后续提供正式插画资源，可只替换装饰层，不影响账本数据和交互。
