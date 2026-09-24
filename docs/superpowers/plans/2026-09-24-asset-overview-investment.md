# 资产总览与投资计入开关实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复资产总览窄屏双卡布局与分布详情，展示计入统计的投资市值，并让投资持仓可选择是否进入首页账目净资产。

**Architecture:** 在每个 `InvestmentHolding` 上保存“计入首页净资产”布尔值，数据库与新建持仓默认 `false`。投资管理继续消费完整组合；首页和资产总览通过新的按币种聚合 provider 只消费已勾选持仓。分布图和详情共用同一资产条目列表；资产变化区间仍依赖账本历史，当前投资市值单独呈现。

**Tech Stack:** Flutter/Dart、Riverpod、Drift/SQLite、`flutter_test`。

---

## 文件职责

- `lib/core/database/app_database.dart`、`lib/core/database/app_database.g.dart`：持仓 inclusion 列、schema v22、兼容迁移和生成代码。
- `lib/features/investments/domain/investment_holding.dart`、`lib/features/investments/data/investment_repository.dart`：持仓/录入请求字段、数据库映射、添加持仓写入以及按币种聚合 provider。
- `lib/features/investments/presentation/investment_add_page.dart`：默认关闭的开关与点击提示。
- `lib/features/home/presentation/home_page.dart`、`lib/features/home/presentation/home_expense_trend.dart`：改用已勾选投资金额；只改 provider 使用点，保留现有用户修改及趋势口径。
- `lib/features/accounts/domain/asset_overview.dart`、`lib/features/accounts/presentation/asset_dashboard_charts.dart`、`lib/features/accounts/presentation/asset_overview_page.dart`：投资金额筛选、分布条目/占比、窄屏并排、当前投资金额和详情弹层。
- `test/investment_repository_test.dart`、`test/investment_flow_test.dart`、`test/home_asset_card_test.dart`、`test/home_asset_scope_test.dart`：默认值、持久化、录入提示、首页金额作用域。
- `test/asset_management_test.dart`、`test/asset_overview_layout_test.dart`、`test/asset_overview_interaction_test.dart`：分布金额/占比、并排布局、卡片跳转和详情弹层。

## Task 1：持仓 inclusion 的默认值与持久化

**Files:**
- Modify: `lib/core/database/app_database.dart`
- Generate: `lib/core/database/app_database.g.dart`
- Modify: `lib/features/investments/domain/investment_holding.dart`
- Modify: `lib/features/investments/data/investment_repository.dart`
- Test: `test/investment_repository_test.dart`
- Test: `test/account_management_schema_test.dart`

- [ ] **Step 1: 先写持仓字段回归测试**

在 repository 测试中新增：新建持仓不传参数时 `includeInHomeNetAssets` 为 `false`；显式传 `true` 后，重新从 repository 读取仍为 `true`；关闭首页计入标记不改变完整投资组合中的持仓和市值。增加 v21 升级夹具：写入一笔已开启的持仓、关闭数据库后移除新列并设 `user_version=21`，重开升级后断言原持仓仍存在且新列值为 `false`。

- [ ] **Step 2: 运行目标测试观察 RED**

运行 `flutter test --no-pub test/investment_repository_test.dart test/account_management_schema_test.dart`。预期新增断言因字段/数据库列或映射尚不存在而失败；若已有断言先失败，先确认其为本任务相关问题再继续。

- [ ] **Step 3: 添加 v22 列与兼容迁移**

在 `InvestmentHoldingEntries` 增加 `BoolColumn get includeInHomeNetAssets => boolean().withDefault(const Constant(false))()`；schema version 提升至 22；`onUpgrade` 仅对缺少该列的库执行 `migrator.addColumn`。对从 v18 以下升级、且在同一迁移中才创建 `investment_holdings` 的路径也要先检查列是否存在，避免重复添加。

- [ ] **Step 4: 映射 request、entity 和 domain 值**

给 `InvestmentHolding`、`copyWith`、`AddInvestmentRequest` 增加默认 `false` 的 `includeInHomeNetAssets`；创建数据库行时写入 `Value(request.includeInHomeNetAssets)`；读取持仓时从 Drift 行映射回 domain。`watchPortfolio` 仍包括所有非归档持仓。

- [ ] **Step 5: 生成 Drift 代码并复跑测试**

运行 `dart run build_runner build --delete-conflicting-outputs`，再运行 `flutter test --no-pub test/investment_repository_test.dart test/account_management_schema_test.dart`。预期新默认值、显式选择持久化、v21 升级默认值、schema 版本和完整投资组合行为均通过。

## Task 2：录入开关与首页计入 provider

**Files:**
- Modify: `lib/features/investments/data/investment_repository.dart`
- Modify: `lib/features/investments/presentation/investment_add_page.dart`
- Modify: `lib/features/home/presentation/home_page.dart`
- Modify: `lib/features/home/presentation/home_expense_trend.dart`
- Test: `test/investment_flow_test.dart`
- Test: `test/home_asset_card_test.dart`
- Test: `test/home_asset_scope_test.dart`

- [ ] **Step 1: 先写录入交互失败测试**

验证添加投资表单展示 `计入首页账目净资产` 且初始为关闭；点击旁边提示按钮后能看到完整提示 `关闭后，投资类金额仅在投资管理页面展示，不计入首页展示的账目净资产。`；保存默认表单创建的持仓后标记仍为 `false`。显式打开后保存的持仓标记为 `true`。

- [ ] **Step 2: 运行目标测试观察 RED**

运行 `flutter test --no-pub test/investment_flow_test.dart`。预期新增查找/状态断言因开关不存在而失败。

- [ ] **Step 3: 添加表单状态和点击提示**

在 `_InvestmentFormState` 初始化 `bool _includeInHomeNetAssets = false`；表单加入有语义标签的 `SwitchListTile`（或等价行式 switch）和至少 44dp 的提示按钮。提示点击显示以上原文；提交 `AddInvestmentRequest` 时传入该状态。

- [ ] **Step 4: 先写 inclusion 聚合与页面作用域测试**

加入组合中一笔默认关闭和一笔显式开启的持仓，断言完整 `investmentValueByCurrencyProvider` 包含两笔，而新建的 `includedInvestmentValueByCurrencyProvider` 只聚合已开启持仓并按币种隔离。验证 Home 首页资产卡/趋势读取 inclusion provider，投资管理页仍读取完整组合。

- [ ] **Step 5: 运行作用域测试观察 RED，再实现最小 provider 接线**

运行 `flutter test --no-pub test/home_asset_card_test.dart test/home_asset_scope_test.dart test/investment_repository_test.dart`。为 `includedInvestmentValueByCurrencyProvider` 增加只过滤 `position.holding.includeInHomeNetAssets` 的按币种求和；保留 `investmentValueByCurrencyProvider` 的全组合行为。让 `home_page.dart` 与 `home_expense_trend.dart` 使用新 provider，其他投资管理使用点不变。

- [ ] **Step 6: 复跑测试观察 GREEN**

运行 `flutter test --no-pub test/investment_flow_test.dart test/home_asset_card_test.dart test/home_asset_scope_test.dart test/investment_repository_test.dart`。预期默认关闭、开关提示、保存状态和完整投资管理数据均通过。

## Task 3：资产分布/变化卡片和详情

**Files:**
- Modify: `lib/features/accounts/domain/asset_overview.dart`
- Modify: `lib/features/accounts/presentation/asset_dashboard_charts.dart`
- Modify: `lib/features/accounts/presentation/asset_overview_page.dart`
- Test: `test/asset_management_test.dart`
- Test: `test/asset_overview_layout_test.dart`
- Test: `test/asset_overview_interaction_test.dart`

- [ ] **Step 1: 先写聚合和布局失败测试**

验证只有正余额且未排除的账户进入分布；已计入投资以单独的 `投资管理` 条目参与总额、donut、详情金额和百分比；详情各行合计与展示总资产一致；没有正值时无除零异常。320dp 与 393dp 页面中资产分布卡和资产变化卡的矩形同一行且无布局异常。

- [ ] **Step 2: 运行相关测试观察 RED**

运行 `flutter test --no-pub test/asset_management_test.dart test/asset_overview_layout_test.dart test/asset_overview_interaction_test.dart`。预期投资条目/百分比或 320dp 并排断言失败。

- [ ] **Step 3: 统一 compact 与 detail 的分布数据**

让两处从同一排序后条目列表读取：每个正余额且未排除的账户，加上正的 `overview.investmentValue` 对应的一条 `投资管理`；金额降序；百分比使用 `overview.assets` 作为分母，零总资产时安全显示。compact 卡显示投资金额；detail 每行显示名称、右对齐金额和占比。

- [ ] **Step 4: 修复窄屏卡片布局并展示投资金额**

移除 `_ChartPair` 在 380dp 以下改成 `Column` 的分支，所有目标屏宽保持 `Row`。按可用宽度压缩 donut 与文案，保持周期 selector 可点击；资产变化卡和变化详情都把当前计入投资市值单独列出，不把它伪装成区间变化。

- [ ] **Step 5: 复现并修复详情弹层黑色条纹**

先在 `asset_overview_interaction_test.dart` 的实际 modal 路由中捕获布局与像素参考，检查 route surface、系统安全区、rounded Material clipping 和滚动视口边界。仅在根因被复现后改动对应弹层背景/边界；保留圆角、外部关闭、可滚动详情和正确的遮罩，不对全局 modal 组件打补丁。

- [ ] **Step 6: 复跑资产总览测试观察 GREEN**

运行 `flutter test --no-pub test/asset_management_test.dart test/asset_overview_layout_test.dart test/asset_overview_interaction_test.dart`。预期窄屏并排、全部正资产及百分比、两个详情入口、modal 无异常均通过。

## Task 4：指挥层整体验收

**Files:** 仅审阅本计划涉及的目标文件和对应测试；不编辑无关现有工作。

- [ ] **Step 1: 运行完整目标测试组**

运行 `flutter test --no-pub test/investment_repository_test.dart test/investment_flow_test.dart test/home_asset_card_test.dart test/home_asset_scope_test.dart test/account_management_schema_test.dart test/asset_management_test.dart test/asset_overview_layout_test.dart test/asset_overview_interaction_test.dart`。预期所有目标测试通过。

- [ ] **Step 2: 对目标文件执行静态分析和差异检查**

运行 `flutter analyze --no-pub lib/core/database/app_database.dart lib/features/investments lib/features/home/presentation/home_page.dart lib/features/home/presentation/home_expense_trend.dart lib/features/accounts/domain/asset_overview.dart lib/features/accounts/presentation/asset_dashboard_charts.dart lib/features/accounts/presentation/asset_overview_page.dart test/investment_repository_test.dart test/investment_flow_test.dart test/home_asset_card_test.dart test/home_asset_scope_test.dart test/account_management_schema_test.dart test/asset_management_test.dart test/asset_overview_layout_test.dart test/asset_overview_interaction_test.dart` 和 `git diff --check`。预期 analyze 无问题且 diff check 退出码 0。

- [ ] **Step 3: 构建 Android Debug APK**

运行 `flutter build apk --debug --no-pub`。预期构建成功并生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **Step 4: 指挥层独立审阅状态与差异**

运行 `git status --short`、`git diff --`（含目标 tracked 文件）并核查未跟踪生成/测试文件。确认本任务只改动列明范围，已有改动仍保留；按项目约定不提交，不运行 reset、clean、merge 或 rebase。
