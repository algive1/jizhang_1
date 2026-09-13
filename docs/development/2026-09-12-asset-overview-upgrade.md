# 资产总览页面升级（2026-09-12）

## 目标

按用户确认的资产总览原型图升级 `/profile/assets`，保留现有 Drift、Riverpod、GoRouter 和账户管理业务。

## 修改内容

- `lib/features/accounts/presentation/asset_overview_page.dart`：重排页面为顶部标题、净资产卡、快捷入口、账户资产、资产分布、资产变化、负债管理和近期资产变动；顶部“全部账本”可切换全部可见账本或具体账本；保留新增账户、账户详情、编辑、校准、归档/恢复和转账入口。
- `lib/features/accounts/presentation/asset_dashboard_cards.dart`：新增暖米白卡片、资产插画净资产卡、快捷入口和账户卡的视觉组件。
- `lib/features/accounts/presentation/asset_dashboard_charts.dart`：新增资产分布环图、负债进度条和支持负资产的账面净资产趋势图。
- `lib/features/accounts/domain/asset_history.dart`：根据当前账户余额与流水倒推历史账面资产，按 7 天、30 天和 1 年生成曲线；未来日期流水存在时不显示误导性历史曲线。
- `lib/core/models/account_balance_effect.dart`：集中定义流水对账户余额的有符号影响，复用于持久化更新和资产历史计算。
- `lib/features/accounts/data/account_repository.dart`：提供包含归档账户、去重资产账本范围的 dashboard provider；共享主账本的账本不会重复计算。
- `lib/features/transactions/data/transactions_repository.dart`：复用统一余额影响函数，保持收入、支出、转账、还款和校准的既有余额规则。
- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`：支持从资产总览直接打开预选“转账”类型的记账表单。

顶部插画使用现有本地 `assets/images/home_asset_scene.png`，作为净资产卡的装饰层，文字、金额、可见性按钮和资产趋势按钮仍是独立真实 UI。

## 数据说明

账户余额、归档状态、账户数量和币种来自本地账户仓储；资产分布来自账户的 `AssetForm`；趋势和近期变动来自可见账本的真实流水。多币种分组显示，不进行汇率换算。原型中的示例金额、涨跌幅、账户名和固定日期没有写入代码。

## 验证

- `flutter analyze lib/features/accounts lib/features/bookkeeping/presentation/quick_add_sheet.dart test/asset_overview_layout_test.dart`：通过。
- `flutter test test/asset_management_test.dart test/home_asset_scope_test.dart test/widget_test.dart test/profile_reference_test.dart`：全部通过。
- `flutter test test/asset_overview_layout_test.dart`：320、393、430 宽度，1.6 倍字体，滚动到底部均通过，无 `RenderFlex overflow`。

## 已知限制

资产趋势是账面余额趋势，不包含未接入的市场估值或投资行情；存在未来日期流水时，页面明确隐藏趋势曲线，避免把计划流水当成历史资产变化。
