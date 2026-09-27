# 钱迹页面自动记账实现对照与验收记录

参考样本是本地钱迹 4.5.3b7 的静态反编译结果。详细 matcher 与字段证据见 [PARSER_SPEC](../.agent/qianji_parser_audit/PARSER_SPEC.md) 和其中三份逐页笔记。本项目在 Kotlin 中重新实现页面规则，使用现有候选、去重和人工确认链。下表的“方向”是钱迹 raw billType 经其编辑页映射后的结果：支出 E、收入 I、转账 T；`条件` 表示页面文本决定方向。

**数量更正**：源 APK 注册了 7 个 profile、56 个 `pageType → parser` 映射。美团 `MeiTuanGrouponDetail` 的 matcher 被注册在它之前的 `MeiTuanVoucherDetail` 完全覆盖，按源程序的 first-match 顺序无法独立命中。故 56 是已注册映射数，不是已证明可独立命中的页面数。测试保留此遮蔽结果。

## 逐页静态规则对照

以下各组的行顺序就是 profile 中的 matcher 顺序。字段栏只列关键字段；完整正则、控件条件、邻接关系见审计笔记。`QIANJI_<pageType>` 存入候选 `scene`，便于在 pending store 和账本元数据中追溯来源页面。

### 微信 `com.tencent.mm`（12 个映射，另有无 parser 的密码页）

| # | pageType | 关键门槛 / 字段 | 方向 |
|---:|---|---|---|
| 1 | `WechatPersonalRedPacketSend` | 红包标题、等待领取金额；金额、备注 | E |
| 2 | `WechatGroupRedPacketDetail` | 领取计数、元、返回/更多图像；邻近金额、备注 | 被抢光标记存在时 I，否则 E |
| 3 | `WechatPersonalRedPacketReceive` | 红包标题、两位金额；金额、备注 | I |
| 4 | `WechatPersonalRedPacketReceive2` | 红包标题、元、返回/更多图像；邻近金额、备注 | I |
| 5 | `WeChatTransferDetail` | 转账标题、状态、时间、支付方式；金额、对方、时间 | E |
| 6 | `WeChatTransferInDetail` | 商家转账标题、付款商家、收款方式、时间；金额、商家 | I |
| 7 | `WeChatBillDetail` | 状态、时间、金额；金额、商户、付款方式；转入标题/收入金额/提现金额决定 raw type | 条件 E/I/T |
| 8 | `WeChatTransferDetailWaiting` | 排除微信主 Tab，待收/已收标题、金额、时间；对方、时间 | 条件 E/I |
| 9 | `WechatWithdrawSuccess` | 零钱提现、申请、金额、到账卡；金额、到账账户 | T |
| 10 | `WechatWithdrawDetail` | 提现标题、状态、申请/到账时间；金额、银行 | T |
| 11 | `WechatChargeDetail` | 充值标题、充值完成、时间、方式；金额、付款账户 | T |
| — | `WechatPayPassword` | 四个支付键盘 view ID、密码提示、完成、金额；源 registry 无 parser，拦截且不产候选 | — |
| 12 | `WeChatPaySuccess` | 支付/充值成功、金额、两组小程序排除条件；商户、方式、时间 | E |

### 支付宝 `com.eg.android.AlipayGphone`（16 个映射）

| # | pageType | 关键门槛 / 字段 | 方向 |
|---:|---|---|---|
| 1 | `AlipayBillDetail` | 状态、时间、金额；交易对方、方式、备注；收益/收款/提现/充值/金额符号决定类型 | 条件 E/I/T |
| 2 | `AlipayPaySuccess` | 支付成功、金额、金额标题或 TextView 完成；方式、备注 | E |
| 3 | `AlipayTransfer` | 转账成功、交易方式、收款方、金额；收款方、方式 | E |
| 4 | `AlipayTransferOut` | 转出成功、金额、到账账户、完成；到账账户 | T |
| 5 | `AlipayTransferIn` | WebView、转入成功、金额、完成/返回控件；金额 | T |
| 6 | `AlipayCharge` | 充值成功、付款方式、金额；订单/实付金额、方式 | E |
| 7 | `AlipayChargeDetail` | 余额明细、充值、时间、对方账户；金额、时间、账户 | T |
| 8 | `AlipayWithdraw` | 提现成功、金额、到账卡、完成；金额、账户 | T |
| 9 | `AlipayWithdrawDetail` | 余额明细、提现、时间、方式、对方账户；金额、时间 | T |
| 10 | `AlipaySendRedPacket` | 发红包、领取计数、退回提示；红包金额、备注 | E |
| 11 | `AlipayQRCodeReceiveDetail` | 账单详情、已收款、收款时间；金额、付款方备注 | I |
| 12 | `AlipayYuLiBaoIncomeDetail` | 收益/收益到账、发放账户、余额、金额；金额、来源 | I |
| 13 | `AlipayYuLiBaoTransferOutSuccess` | Image 结果、转出成功、收款账号、金额；账户 | T |
| 14 | `AlipayYuLiBaoTransferOutDetail` | WebView 详情、成功转出、两端账户、金额；时间 | T |
| 15 | `AlipayYuLiBaoTransferInDetail` | WebView 详情、成功转入、两端账户、余额、金额；时间 | T |
| 16 | `AlipayYuLiBaoTransferInSuccess` | 转入成功、付款方式、收益提示；金额、方式 | T |

### 拼多多 `com.xunmeng.pinduoduo`（3 个映射）

| # | pageType | 关键门槛 / 字段 | 方向 |
|---:|---|---|---|
| 1 | `PddOrderDetail` | 时间、订单状态、操作入口、商品名、金额；净价/优惠、时间、备注 | E |
| 2 | `PddPayFirstDialog` | 先用后付成功、待收货、自动付款金额；未来扣款额、待收货备注 | E |
| 3 | `PddWalletBillDetail` | 钱包账单、支付成功、单号、严格两位金额；商户、方式、优惠 | E |

### 云闪付 `com.unionpay`（5 个映射）

| # | pageType | 关键门槛 / 字段 | 方向 |
|---:|---|---|---|
| 1 | `UnionpayBillDetail` | 账单详情、客服控件、状态、订单金额/时间；方式、备注 | E |
| 2 | `UnionpayPaySuccess` | 支付成功、付款方式、完成、金额 | E |
| 3 | `UnionpayTransferSuccess` | 转账成功、详情、继续转账、金额 | T |
| 4 | `UnionpayTransferDetail` | 账单详情、客服控件、转账金额、收款方式、时间 | T |
| 5 | `UnionpayMessageOrderDetail` | 消息详情、卡号、时间、类别、金额；消费/入账/取款映射 | 条件 E/I/T |

### 京东 `com.jingdong.app.mall`（6 个映射）

| # | pageType | 关键门槛 / 字段 | 方向 |
|---:|---|---|---|
| 1 | `JingDongWalletBillDetail` | WebView 账单、状态、订单数、金额；方式、时间、退款提示 | E |
| 2 | `JingDongWalletBillDetailV2` | WebView 账单、交易/退款文本；金额、优惠、状态提示 | E |
| 3 | `JingDongAihuishouOrderDetail` | 回收成功、合计收款、订单号；金额、收款方式 | I |
| 4 | `JingDongOrderDetail` | 订单状态、数量、实付/合计、单号；金额、时间 | E |
| 5 | `JingDongOrderWeb` | WebView 订单、状态、总额/实付、单号、时间；金额 | E |
| 6 | `JingDongPaySuccess` | TextView 支付成功、组合支付方式/金额；优惠 | E |

### 美团 `com.sankuai.meituan`（10 个映射，按 APK 实际顺序）

| # | pageType | 关键门槛 / 字段 | 方向 |
|---:|---|---|---|
| 1 | `MeiTuanOrderDetail` | 已消费、实付、订单信息/编号/时间；金额、备注 | E |
| 2 | `MeiTuanVoucherDetail` | 已使用或待到店使用、实付、使用须知/日期/时间；金额 | E |
| 3 | `MeiTuanVoucherSuccessDetail` | 买单成功、实付款、编号、消费时间；金额、优惠、商户 | E |
| 4 | `MeiTuanGrouponDetail` | 已使用、团购详情、实付、须知/日期/时间/订单信息；被 #2 遮蔽 | E（不能独立命中） |
| 5 | `MeiTuanMovieDetail` | 放映/开场、取票、订单、实付金额；金额、时间 | E |
| 6 | `MeiTuanChargeOrderDetail` | 充电宝归还、时长、订单金额、再次租借；金额 | E |
| 7 | `MeiTuanBikeOrderDetail` | 已支付金额、申诉/报修、时间、骑行时长 | E |
| 8 | `MeiTuanPaySuccess` | WebView 支付成功、带金额成功文本 | E |
| 9 | `MeiTuanWalletBillDetail` | 钱包账单、扣款或退款状态、方式、时间；金额、退款提示 | E |
| 10 | `MeiTuanDeliveryDetail` | 订单完成、送达提示、合计/实付款；金额、优惠 | E |

### 抖音 `com.ss.android.ugc.aweme`（4 个映射）

| # | pageType | 关键门槛 / 字段 | 方向 |
|---:|---|---|---|
| 1 | `DouyingTransferWaiting` | 转账详情、待收款、时间/附言、24 小时退回提示；金额、对方 | E |
| 2 | `DouyingTransferReceived` | 转账详情、已收款、收/转账时间；金额、收款人 | E |
| 3 | `DouyingWalletBillDetail` | WebView 详情、支付成功、单号、严格金额；商户、优惠、方式 | E |
| 4 | `DouyingPaySuccess` | FlattenUIText 支付成功、方式、时间、金额；备注 | E |

## 端到端链路与差异

- `AutoBookkeepingAccessibilityService` 在七包事件上逐个窗口保留 DFS 节点顺序，传入 `PaymentSceneDetector`。微信也会扫描红包/转账详情；微信 LauncherUI 与云闪付主 Activity 被 profile gate 排除。手动扫描缺失 Activity 类名时云闪付允许解析，是本项目手动入口的适配。
- Detector 先运行七 profile 页面解析器。已命中页面即使用首个 page parser 的候选或拒绝结果，不回落到 legacy 泛化解析；完全未命中时保留旧解析器。现有微信“支付成功 + 待某人确认收款”的简短转账布局继续由已有交易状态 parser 优先处理，避免旧功能退化。这一窄例外不同于钱迹纯首个页面匹配链。
- 候选沿用 `PaymentCandidate → BillFingerprint → AutoBookkeepingPendingStore → 浮层/通知 → Flutter 确认页 → 账本`。本项目要求正金额和可显示的商户；钱迹共享层可给缺金额 0、缺商户空值。因此缺金额/歧义会拒绝，缺商户的页面使用平台名作可编辑显示名。缺页面时间使用观察时间；钱迹可写 0。京东钱包来源按包名写 `JD`，修正钱迹继承链可能写 `PDD` 的问题。
- PDD 与抖音 7 页均未显式写 raw billType，钱迹共享层默认为 0，本实现也按其下游映射为支出。先用后付、待收款、退款状态仍可进入人工确认候选，备注中保留状态；这反映样本 parser 的输出，并不证明真实交易已结算。提现的 `fee`/`feeAmount` 键错配没有逐字复制，优惠作为本项目原价/优惠字段表示，手续费没有独立账本字段，故费用展示尚非逐字段等价。
- 目前没有连接的 Android 设备，也没有钱迹及七个第三方 App 的运行期页面树样本。静态规则与合成节点 fixture 能验证注册、首匹配、主要字段和方向；跨 App 版本/OEM 的真实识别率、截图证据及实际记账行为不能由此证明完全相同。

## 验收命令

运行记录与结果持续更新在 [PROGRESS.md](../.agent/qianji_parser_implementation/PROGRESS.md)。

本机最后一轮 `:app:testDebugUnitTest :app:assembleDebug :app:lintDebug` 退出码为 0，58 个单元测试全部通过；`flutter analyze lib --no-pub` 通过。Debug 安装包位于 `build/app/outputs/apk/debug/app-debug.apk`。`adb devices` 无连接设备。

## 真实设备验收尚缺的证据

需要在同一台 Android 设备上安装本项目 Debug 包、钱迹样本及目标 App，开启两者必要的无障碍权限。对七个 profile 的页面分别采集脱敏节点树、钱迹识别结果、本项目待确认候选及最终账本结果，逐笔比较 pageType、金额、方向、时间、商户、账户、备注和状态。尤其要覆盖微信红包/转账、支付宝账单、拼多多先用后付、抖音待收款、退款、缺字段、重复页面，以及美团团购规则被券规则遮蔽的情况。当前缺少这些运行期输入，因此该验收项尚未通过。
