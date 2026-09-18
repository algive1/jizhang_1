# 投资账务联动（买入 / 卖出 ↔ 账户余额 与 净资产）

日期：2026-09-17  
范围：`InvestmentRepository`、`AssetOverview`、交易类型与统计口径

## 结论

投资买卖不再是“账外行为”：买入会把资金从出资账户划出，卖出会把钱划回，
同时投资市值计入资产总览净资产。买入与卖出都不计入消费支出、也不计入收入，
因此净资产在买卖前后保持不变——这正是「资产转换」的定义。

## 背景

在此之前，投资模块只写自己的 `investment_transactions`，`transactions` 表里没有对应行，
造成两处账实不符：

1. 买入后银行卡余额不变，相当于凭空多出一份资产；
2. 投资市值完全不计入净资产，资产总览只反映账户余额。

## 改动

### 1. 交易类型新增 `assetSale`

`assetPurchase`（资产购买）此前已存在，但没有任何地方创建它；卖出需要一个方向相反的类型。

- `lib/core/models/transaction_record.dart`：枚举新增 `assetSale`；
  新增 `isAssetTransfer`（买入或卖出）与 `isConsumptionExpense`（剔除资产转换的消费支出）
- `lib/core/models/account_balance_effect.dart`：`assetSale` 记 `{source: +cents}`
- `lib/core/database/book_scope_migration.dart`：迁移类型白名单加入 `assetSale`
- `lib/features/intelligence/data/merchant_rule_repository.dart`：资产转换不参与商户默认分类
- `server/src/contract.ts`：共享同步协议的流水类型枚举加入 `assetSale`
- 记一笔、交易详情：新增「资产卖出」文案

### 2. 投资成交镜像到主流水

`DriftInvestmentRepository._mirrorTrade` 在买入 / 卖出时写一条主流水：

| 投资动作 | 主流水类型 | 余额方向 |
| --- | --- | --- |
| 买入 | `assetPurchase` | 出资账户减少 |
| 卖出 | `assetSale` | 出资账户增加 |

- 流水 id 为 `investment-mirror-<投资成交 id>`，重试不会重复入账
- 未选择出资账户、或账户已不存在时不镜像（不阻断投资录入）
- 币种随成交一起传递，避免与出资账户币种不一致

### 3. 投资市值计入净资产

- `AssetOverview` 新增 `investmentValue`，计入 `assets` / `netAssets`，
  并在 `byForm` 中归入 `AssetForm.investment`
- `investmentValueByCurrencyProvider` 按币种汇总持仓市值
- 首页资产卡与资产总览页共用同一口径；资产总览内部的资产卡也传入同一数值
- 只有投资、没有任何账户的币种同样会单独成组

### 4. 统计口径

- 首页月支出、消费日历改用 `isConsumptionExpense`，买入不再被算作消费
- 资产总览「资产变动」筛选补上「资产卖出」

## 验证

```text
flutter analyze lib/
→ No issues found

flutter test（投资 + 资产 + 首页 + 日历 + 统计 + 共享同步子集，共 106 项）
→ All tests passed

cd server && npm run typecheck && npm test
→ 10 项服务端测试全部通过
```

新增 / 更新用例：

- `test/investment_repository_test.dart`
  - 有出资账户的买入写入 `assetPurchase` 且账户余额减少
  - 卖出写入 `assetSale`、账户余额回补，且不计收入
  - 未填出资账户的成交不写主流水
  - 出资账户不存在时保持不镜像、不抛错
  - 资产转换既不是消费也不是收入
- `test/asset_management_test.dart`
  - 投资市值计入净资产与 `AssetForm.investment`
  - 只有投资、没有账户的币种也会单独成组

## 遗留

1. **分红 / 利息**：目前只写投资成交记录，现金实际到账但账户余额不变。
   是否补一条 `income` 流水需要产品确认（会改变收入统计）。
2. **存量持仓不回溯**：本次只对改动生效后的新成交联动，历史成交不会补写主流水，
   因此历史持仓对应的资金账户余额与成交记录并不一致。
3. **未选择出资账户的成交**仍不会产生资金流动，属于已知取舍。
