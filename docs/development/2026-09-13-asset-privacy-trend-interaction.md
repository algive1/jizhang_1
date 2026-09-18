# 资产总览隐私范围与趋势交互修复

日期：2026-09-13

## 问题原因

1. 资产总览页的 `_hidden` 状态原本沿着页面调用链传入资产分布、资产变化、负债、近期资产变动和详情弹窗，导致隐藏范围超出“顶部资产卡片 + 账户资产卡片”。资产分布隐藏分支还会用短占位内容替换图表，造成卡片高度变小。
2. 资产变化卡片使用横向 `SingleChildScrollView`，拖动时是在移动一张更宽的画布，而不是像首页趋势图一样选择最近数据点；详情页只有 `CustomPaint`，没有点击/横向拖动选点逻辑。
3. 趋势详情固定只绘制首、中、末三个日期标签，近 30 天会产生较大的视觉日期间隔。数据本身仍按日生成；近 1 年继续按周采样以控制点数。

## 修改内容

- `lib/features/accounts/presentation/asset_overview_page.dart`
  - 将隐藏状态作用域收窄到 `HomeAssetCard` 和 `_AccountSection`。
  - 资产分布、资产变化、负债管理、近期资产变动及详情弹窗不再接收隐藏状态。

- `lib/features/accounts/presentation/asset_dashboard_charts.dart`
  - 移除资产分布的隐藏占位分支，保持面板高度稳定。
  - 新增 `AssetTrendPlot`，卡片和详情共用固定画布、点击/左右拖动选点、当前点高亮和金额气泡。
  - 趋势图不再横向滚动画布；详情页显示选中日期与账面净资产。
  - 日期标签改为自适应：近 7 天显示每日标签，近 30 天和近 1 年显示均匀分布的多个标签。
  - 保留并验证近 7 天、近 30 天、近 1 年区间按钮。

- `lib/features/accounts/presentation/asset_liability_section.dart`
  - 负债金额、负债率和负债账户不再受资产总览隐藏按钮影响。

- `test/asset_overview_interaction_test.dart`
  - 覆盖隐藏范围、资产分布卡片尺寸稳定、详情区间按钮、详情趋势拖动选点和分析文案。

## 验证结果

- `flutter analyze`：通过，无新增 warning。
- 资产交互测试：通过。
- 资产布局测试（320 / 393 / 430）：通过。
- 共享趋势图测试：通过。
- `flutter build apk --debug`：通过。
- APK 已安装到 `emulator-5554`（`pixel_7` AVD），并完成资产总览页面的隐藏状态与趋势详情视觉检查。

全量测试曾受到既有的会员页/首页测试超时与环境并发影响，出现的失败不涉及本次资产页修改；资产相关定向测试均通过。

