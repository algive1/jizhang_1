# 投资管理 MVP（2026-09-17）

本文是「好好记账」投资管理模块的移交文档，覆盖产品范围、文件清单、数据结构、数据流、Mock 行情位置、真实行情接入方式、缓存替换方式和**刻意未实现**的部分。

> 定位：投资管理是**个人资产管理能力**，不是证券交易软件。第一版目标 = 简单、稳定、低服务器成本、易扩展、与现有资产体系融合、视觉保持好好记账当前风格。

---

## 1. 一句话结论

资产总览的「分类统计」入口已改为「投资管理」；投资管理是一条完全本地优先、独立于消费流水的数据链：`InvestmentRepository` → `MarketDataProvider` → `QuoteCache` → 本地 Drift。股票 / 基金 / 债券 / 虚拟币共用同一套页面与组件，只靠 `assetType` 区分。

---

## 2. 修改了哪些文件

| 文件 | 改动 |
| --- | --- |
| `lib/core/database/app_database.dart` | 新增 4 张 Drift 表、`InvestmentDao`、`schemaVersion` 17→18、forward-only 迁移与索引 |
| `lib/core/database/app_database.g.dart` | `dart run build_runner build` 重新生成 |
| `lib/features/accounts/presentation/asset_dashboard_cards.dart` | `AssetShortcuts` 的 `onCategories` → `onInvestments`，文案「分类统计 / 收支分类」→「投资管理 / 股票·基金·债券」 |
| `lib/features/accounts/presentation/asset_dashboard_icons.dart` | 新增 `AssetGlyph.growth`（趋势线 + 3 个节点，非 K 线） |
| `lib/features/accounts/presentation/asset_overview_page.dart` | 入口回调改为 `context.push('/profile/investments')` |
| `lib/app/router/app_router.dart` | 新增 4 条投资管理路由 |
| `docs/development/ARCHITECTURE.md` | 路由表、数据库表、迁移链、Feature 状态同步更新 |

卡片尺寸、圆角、间距、图标容器尺寸、整体视觉风格**未改动**，只换了文案和图标字形。

## 3. 新增了哪些文件

```
lib/features/investments/
├── domain/
│   ├── investment_asset.dart        枚举 + 标的模型 + 共享行情 key
│   ├── investment_holding.dart      持仓、交易、平均成本算法
│   ├── investment_quote.dart        统一行情、走势点、区间枚举
│   └── investment_portfolio.dart    组合汇总、成本/收益计算、每日快照、趋势
├── data/
│   ├── investment_config.dart       全部 TTL 与阈值配置
│   ├── quote_cache.dart             QuoteCache / MemoryQuoteCache / RedisQuoteCache
│   ├── market_data_provider.dart    MarketDataProvider 抽象 + MockMarketDataProvider
│   └── investment_repository.dart   InvestmentRepository + Drift 实现 + providers
└── presentation/
    ├── investment_overview_page.dart    总览 + 五 Tab + 分类持仓
    ├── investment_detail_page.dart      单个投资详情
    ├── investment_add_page.dart         添加投资（搜索 / 手动）
    ├── investment_transaction_sheet.dart 交易记录弹窗
    ├── investment_summary_card.dart      InvestmentSummaryCard / InvestmentCategoryCard
    ├── holding_item.dart                 HoldingItem / HoldingMiniRow
    ├── investment_chart.dart             InvestmentChart / InvestmentRangeSelector
    ├── transaction_item.dart             TransactionItem
    ├── investment_widgets.dart           ProfitText / QuoteStatus / Chip / Avatar
    ├── investment_states.dart            空状态 / Skeleton / 错误 / 段落标题
    └── investment_type_picker.dart       类型选择弹窗

test/
├── investment_domain_test.dart       17 项：平均成本、收益、现金流方向、组合聚合、快照
├── investment_repository_test.dart   14 项：写入、买卖分红、手动估值、陈旧行情、快照幂等
├── investment_market_test.dart       16 项：缓存 TTL、行情 TTL 策略、Mock 确定性
└── investment_flow_test.dart         12 项：入口改造、路由、五 Tab、空状态、添加、交易记录
```

## 4. 新增的数据库表 / 字段

新增 4 张表，**没有修改任何既有表或列**（迁移 18 是纯新增，老用户账户/流水/余额零影响）。

| 表 | 关键列 |
| --- | --- |
| `investment_assets` | `id` `type` `symbol` `name` `market` `currency` `price_source` `manual_price` `created_at` `updated_at`；唯一索引 `(type, market, symbol)` |
| `investment_holdings` | `id` `book_id` `asset_id`→assets `account_id` `quantity` `average_cost` `note` `is_archived` `created_at` `updated_at` |
| `investment_transactions` | `id` `book_id` `holding_id`→holdings `type` `price` `quantity` `amount`(带符号) `transaction_date` `note` `created_at` |
| `investment_snapshots` | 主键 `(book_id, date)`；`investment_value` `stock_value` `fund_value` `bond_value` `crypto_value` |

枚举口径：`assetType` = `stock|fund|bond|crypto`；`transactionType` = `buy|sell|dividend|interest`；`priceSource` = `market|manual`。

## 5. 页面结构

```
资产总览 /profile/assets
└─ 顶部四宫格「投资管理」/profile/investments
   ├─ 总览 Tab
   │   ├─ InvestmentSummaryCard  投资资产 / 今日涨跌 / 累计收益 + 金额隐藏
   │   ├─ 四张 InvestmentCategoryCard  股票·基金·债券·虚拟币
   │   ├─ 投资资产趋势  近30天 / 近1年 / 全部
   │   └─ 投资资产变动（前 5 条）
   ├─ 股票 / 基金 / 债券 / 虚拟币 Tab（同一 _CategoryTab 组件）
   │   ├─ 分类汇总卡（总资产 / 累计收益 / 收益率 / 笔数）
   │   └─ 持仓列表 HoldingItem + 「+ 添加」
   │      └─ /holdings/detail/:holdingId
   │          ├─ 当前价格 / 今日涨跌 / 行情状态
   │          ├─ 当前市值 / 累计收益 / 收益率
   │          ├─ 持仓数据（平均成本、持有数量、持仓成本 + 分类扩展字段）
   │          ├─ 走势图 近1月/近3月/近1年/全部
   │          └─ 交易记录 TransactionItem + 「+ 记录」
   └─ /add?type=xxx
       ├─ 搜索添加：命中后进入买入表单
       └─ 手动添加：全部手填 + 可选当前估值 → priceSource = manual
```

复用组件：`InvestmentSummaryCard`、`InvestmentCategoryCard`、`HoldingItem`、`ProfitText`、`QuoteStatus`、`InvestmentChart`、`TransactionItem`。四类资产**没有**四份相似代码。

## 6. 数据流结构

```
页面 (presentation)
  │  只读 provider，不直接 fetch / 不直接碰 Drift
  ▼
investmentPortfolioProvider (StreamProvider)   ← 持仓变化自动重发
investmentHoldingProvider / investmentTransactionsProvider / investmentSnapshotsProvider
investmentSearchProvider / investmentHistoryProvider
  │
  ▼
InvestmentRepository  (abstract interface)
  └─ DriftInvestmentRepository   ← 当前实现（本地优先）
  └─ ApiInvestmentRepository     ← 预留，方法抛 UnimplementedError
  │
  ├──────────────► MarketDataProvider (abstract)
  │                  └─ MockMarketDataProvider   ← 当前实现
  │                  └─ 未来 HttpMarketDataProvider
  │
  └──────────────► QuoteCache (abstract)
                     └─ MemoryQuoteCache        ← 当前实现
                     └─ RedisQuoteCache         ← 预留
  │
  ▼
Drift / SQLite（investment_* 四张表）
```

**Stale-While-Revalidate 流程**

1. 结构化读取持仓 → 用缓存行情估值 → 立即发出（无缓存则回落到平均成本，绝不显示假 0）。
2. 后台按资产类别**批量**拉取 `getQuotes`（一个类别一次请求），写回缓存。
3. 成功 → 若价格或陈旧标记变化则再发一次；失败 → 保留旧值、标记 `isStale`，UI 显示「行情更新失败」。
4. `引用共享 key`：`quote:stock:CN:600519`、`quote:crypto:GLOBAL:BTC`，**不含 userId**，1000 个用户共享一份。

## 7. 当前 Mock 行情在哪里

`lib/features/investments/data/market_data_provider.dart`

- `MockMarketDataProvider`：内置 30 个真实代码的标的（茅台 600519、沪深300ETF 510300、23附息国债10 230023、BTC …）。
- 价格 = `basePrice × (1 + 按 symbol 相位 + 按天漂移的正弦)`，**同一 symbol 同一天价格恒定**，便于测试与手工验收复现；跨天会变，趋势不会是一条直线。
- 通过 `marketDataProviderProvider` 注入；`simulateFailure = true` 可手动触发「行情更新失败」路径。

## 8. 接真实行情 API 要替换哪个 Provider

只替换 **一处**：

```dart
// lib/features/investments/data/investment_repository.dart
final marketDataProviderProvider = Provider<MarketDataProvider>(
  (ref) => MockMarketDataProvider(),   // ← 换成真实实现
);
```

实现一个新的 `MarketDataProvider`（建议 `HttpMarketDataProvider`），只实现 4 个方法：
`search` / `getQuote` / `getQuotes` / `getHistory`，返回统一的 `InvestmentQuote`。

**API key 绝不能进客户端**：真实实现应当请求「好好记账」自己的服务器（例如 `GET /market/quotes?symbols=...`），由服务端持有 key、自带共享缓存并聚合批量请求。UI、Repository、Domain 一行都不用改。

同理，后端接入时只替换 `investmentRepositoryProvider`：

```dart
final investmentRepositoryProvider = Provider<InvestmentRepository>(
  (ref) => DriftInvestmentRepository(...),   // ← 换成 ApiInvestmentRepository
);
```

## 9. Memory Cache 如何切换 Redis

`lib/features/investments/data/quote_cache.dart` 定义了 `QuoteCache` 接口（`get` / `set` / `getMany` / `remove` / `clear`）。

切换步骤：

1. 实现 `RedisQuoteCache` 的 5 个方法（当前是显式 `UnimplementedError`，故意不静默假装可用）。
2. 把 `quoteCacheProvider` 改为返回 Redis 实现：

```dart
final quoteCacheProvider = Provider<QuoteCache>((ref) => MemoryQuoteCache());
// ↓
final quoteCacheProvider = Provider<QuoteCache>((ref) => RedisQuoteCache(client: redis));
```

3. 业务代码零改动。Key 已经按 `quote:<type>:<market>:<symbol>` 组织，天然是「按证券共享」而不是「按用户」。

TTL 全部集中在 `InvestmentConfig`，不在业务代码里散落硬编码：股票 4 分钟、基金 60 分钟、债券 20 分钟、虚拟币 2 分钟；非交易时段股票放宽到 2 小时、债券 6 小时、基金 12 小时，虚拟币不受交易时段影响。

## 10. 属于 MVP 的功能

- 入口改造：资产总览「分类统计」→「投资管理」
- 五个 Tab：总览 / 股票 / 基金 / 债券 / 虚拟币
- 投资总览：投资资产、今日涨跌、累计收益、四类金额与收益率、趋势、持仓变动
- 分类持仓页（四类共用一套页面）
- 单个投资详情：当前价格、今日涨跌、当前市值、累计收益、收益率、平均成本、持有数量、走势图
- 添加投资：搜索添加 + 手动添加（`priceSource = manual`，可后续手动改估值）
- 交易记录：买入 / 卖出 / 分红 / 利息
- 收益计算：简单平均成本（`持仓成本`、`当前市值`、`浮动收益`、`收益率`）
- 行情体系：`MarketDataProvider` 抽象 + `MockMarketDataProvider` + `QuoteCache` 抽象 + `MemoryQuoteCache`
- 每日快照：用户当天第一次打开投资管理时懒写入，无后台定时任务
- 金额隐藏：复用现有 `PrivacyAmount`，隐藏圆点不随大字号变大
- 状态处理：Skeleton / 空状态 / 行情失败 / 无网络 / 陈旧数据标记
- 复用资产管理账户体系作为「持有账户」

## 11. 故意没有实现的功能

按需求第二十八条，以下**全部未做**：

WebSocket 实时跳价、证券交易/买卖下单、K 线、分时图、Level 2、盘口、成交明细、新闻、财报、研报、AI 买卖建议、股票推荐、涨跌榜、热门榜、复杂税务、策略回测、微服务拆分、Kafka、行情时序数据库、高频行情 Worker。

另外这些是**有意识的取舍**，不是遗漏：

| 未做 | 原因 |
| --- | --- |
| 购买投资时扣减银行账户余额 | 会触碰被测试锁定的现有账户/流水守恒语义。当前已按正确口径建立数据结构与 Repository 接口，且**绝不把买入记为消费支出**，因此净资产不会凭空减少。打通方案见下节。 |
| 投资资产计入资产总览净资产 | 同上：`AssetOverview.netAssets` 公式被既有测试锁定，本轮不静默改变用户已验收的数字。 |
| 已实现收益（已卖出部分的兑现收益）单独展示 | 需要卖出配对成本算法，第一版先保证「当前持仓市值 + 浮动收益 + 收益率」正确。 |
| 债券票面利率 / 到期日、基金净值日期（真实值） | 数据源未提供时不做假字段；字段位置已留在详情页的扩展位。 |
| 真实行情 API 联调 | 需要服务端持有 key 与缓存，属部署阶段工作。**代码完成但未实际联调。** |
| Redis 接入 | `RedisQuoteCache` 已留接口，未实现具体客户端调用。 |
| iOS 构建验收 | 当前机器 `xcodebuild` 不可用，与本次改动无关。 |

## 12. 后续打通账户余额的建议方案（未实现）

当前事实：买入投资**不**产生 `transactions` 记录，所以买入不会增加消费支出、不会减少净资产。

要真正打通「银行卡 100,000 → 买股票 10,000 → 银行卡 90,000 + 股票 10,000，总资产仍 100,000」，建议按**资产转移**而不是收支来做：

1. 新增资产转移记录（或复用 `transactions.type = transfer` 的语义），来源账户 = 持有账户，目标 = 投资账户；
2. 在 `asset_overview` 聚合时把 `investment_holdings` 的市值计入「投资理财」资金形式；
3. 补一条守恒测试：买入前后 `净资产` 不变。

这三步会改动现有被测试锁定的公式，需要产品确认后再做，因此本轮**明确未做**。

## 13. 验证方式

```bash
dart run build_runner build          # 修改 Drift 表后必须重新生成
flutter analyze lib/                 # 0 issue
flutter test test/investment_*.dart  # 63 项通过

# 全量回归：排除 3 个会员页相关测试文件（既有失败，本轮未改动 membership）
flutter test <83 个测试文件>          # 354 项全部通过，EXIT=0

flutter build apk --debug
# → ✓ Built build/app/outputs/flutter-apk/app-debug.apk（无 warning / error）
```

> 全量 86 个文件直接跑会得到 5 项失败，全部位于本轮未改动的
> `membership_page.dart`（工作区中本就有 892 行未提交改动，且 2026-09-13
> 已记录其 `pumpAndSettle` 超时）。详见 `CURRENT_STATUS.md`。

手工验收路径：`我的 → 资产总览 → 投资管理 → 添加投资 → 搜索 600519 → 填数量 → 保存 → 股票 Tab → 点持仓进详情 → + 记录 卖出一笔`。

## 13.1 本轮由测试查出的真实缺陷（已修复）

`investment_responsive_test.dart` 在 320dp × 字号 1.6 下查出 3 处真实溢出，需求第二十五条与第二十四条明确要求「超大金额不得突破卡片」「金额隐藏不因大字号变大」，因此这些是必修项：

1. **持仓行尾部金额列无宽度约束**：`HoldingItem` / `HoldingMiniRow` 的右侧金额 `Column` 是 `Row` 的非弹性子项，`PrivacyAmount` 的 `FittedBox` 在无界宽度下不会缩放，超大市值直接撑破卡片。改为 `LayoutBuilder` + `ConstrainedBox(maxWidth: 行宽 × 46%)`。
2. **非弹性文本行**：分类汇总卡与详情页的「累计收益」行、交易记录行的日期、详情页涨跌列，在 1.6 字号下自然宽度超出半栏。相关子项改为 `Flexible`，涨跌列加 `ConstrainedBox(42%)`。
3. **`ProfitText` 无缩放能力**：`InvestmentAmountText` 有 `FittedBox` 而收益率文本没有，1.6 字号下 `↑ +33.45%` 自然宽度约 161px，超过 129px 可用宽度。现在 `ProfitText` 同样包一层 `scaleDown` 的 `FittedBox`，并新增 `alignment` 参数供右对齐场景使用。

## 14. 新开窗口继续这个任务的方法

对新会话直接说明：

> 继续「好好记账」投资管理模块。先读 `docs/development/2026-09-17-investment-management-mvp.md`，再读 `docs/development/ARCHITECTURE.md` 的 4/5/7 节。改动前先跑 `flutter analyze lib/` 和 `flutter test test/investment_flow_test.dart` 确认基线。本次要做的任务是：<具体任务>。

关键文件入口：`lib/features/investments/`（domain / data / presentation 三层）、`lib/app/router/app_router.dart` 的 investments 路由段、`lib/core/database/app_database.dart` 的 `InvestmentDao`。

改动 Drift 表的固定动作：升 `schemaVersion` → 在 `onUpgrade` 追加 `if (from < N)` 分支 → `dart run build_runner build` → 补升级测试。
