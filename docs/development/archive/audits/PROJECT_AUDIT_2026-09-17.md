# 好好记账 —— 全项目工程审计报告

> 审计类型：只读审计（**本轮未修改任何业务代码**）
> 审计对象：`/Users/algive/jizhang_01`
> 审计日期：2026-09-17
> 审计依据：页面代码 / 路由 / Provider / Service / Repository / API / Drift 表 / 原生配置 / 第三方 SDK / 实际调用链
> 明确声明：本报告**不依据 README 或页面名称**判断完成度；所有结论均给出文件路径与行号。

---

## 0. 本次审计的验证证据（可复现）

| 检查项 | 命令 | 结果 |
| --- | --- | --- |
| 客户端静态分析 | `flutter analyze --no-pub` | **2 issues**（均为测试文件未使用 import，`test/investment_flow_test.dart:10`、`test/investment_repository_test.dart:8`），无 error |
| 客户端测试 | `flutter test --reporter expanded --concurrency=1` | 🔴 **255 通过 / 6 失败 / 套件未跑完**（卡在 `membership_page_ui_test.dart`，单测试 10 分钟超时）。详见 §0.1 |
| 服务端类型检查 | `cd server && npm run typecheck` (`tsc --noEmit`) | **通过，无输出** |
| 服务端测试 | `cd server && npm test` | **10/10 通过，0 失败**（含真实 HTTP 双端同步、冲突、权限、隔离、支付验签） |
| 代码规模 | — | Dart 206 个文件 / 86,123 行（其中 `app_database.g.dart` 生成代码 31,420 行，手写约 54,700 行）|
| 服务端规模 | — | TypeScript 8 个文件 / **1,127 行**（含 `payment.ts` 396 行、`store.ts` 294 行）|
| 原生规模 | — | Android Kotlin **1,689 行**（`autobookkeeping` 包约 1,000 行）|
| 数据库规模 | — | Drift 表 **26 张** + 同步原始表 **6 张** + 服务端表 **7 张** |

### 0.1 测试执行状态

**实测：`flutter test` 基线不绿，且测试套件无法跑完。**

```
flutter test --reporter expanded --concurrency=1
→ 255 通过 / 6 失败 / 14 分钟仍未结束（手动终止）
→ 卡点：membership_page_ui_test.dart 单测试 10 分钟超时，阻塞其后的所有测试
```

其中**失败 1 是真实用户可见的 UI 缺陷**：会员页头部 `_MemberHeader` 在 320dp 小屏上 **RenderFlex 溢出 6.6px**，根因位于 `lib/features/membership/presentation/membership_page.dart:360` 的高度预算 `height: 68 + (scale - 1) * 64` 与 `:376` 的内层 `Column` 内容高度不匹配。

**详细失败清单、根因分析与修复建议见 §18「本轮验证记录」。**

> 这一发现推翻了 `docs/development/CURRENT_STATUS.md`（2026-09-14）"230 个测试全部通过"的结论，并直接决定：**修好测试基线是所有后续开发的前置条件**（否则无法判断是否引入回归）。

---

## 1. 架构总览（先看这一节，后面所有结论都建立在此之上）

### 1.1 这不是一个「前后端 App」，而是一个「本地优先 App + 局域网共享后端」

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter App (lib/, 54.7k 手写行)                            │
│                                                             │
│  ┌───────────────────────────┐   ┌───────────────────────┐  │
│  │ 本地核心（占 95%+）        │   │ 联网能力（条件开启）    │  │
│  │                           │   │                       │  │
│  │ Drift / SQLite (26 表)    │   │ SharedApi             │  │
│  │  ├ 账户/分类/流水/预算     │   │  └ baseUrl 默认        │  │
│  │  ├ 目标/分期/周期账单      │   │    http://127.0.0.1:8787│ │
│  │  ├ 投资(本地+假行情)       │   │                       │  │
│  │  └ 智能/收件箱/广告事件    │   │ 3 个功能依赖它：        │  │
│  │                           │   │  1) 共享账本同步        │  │
│  │ 无登录也可完整使用          │   │  2) 会员/catalog/支付   │  │
│  │ currentActor='user-local' │   │  3) AI 助手/语音 AI     │  │
│  └───────────────────────────┘   └───────────┬───────────┘  │
└──────────────────────────────────────────────┼──────────────┘
                                               │
                    编译期开关 SHARED_API_BASE_URL（--dart-define）
                                               │
                       ┌───────────────────────▼──────────────┐
                       │ Node 22 + Fastify 5 + better-sqlite3 │
                       │ server/src  （1,127 行）              │
                       │                                      │
                       │ Auth（用户名密码/session）            │
                       │ 共享账本（快照/游标/幂等 mutation/冲突）│
                       │ 会员 catalog + 微信/支付宝支付+验签    │
                       │ AI 助手策略 + DeepSeek 转发           │
                       └──────────────────────────────────────┘
```

### 1.2 决定一切的关键机制：**编译期开关**

```dart
// lib/features/sharing/data/shared_api.dart:14-20
SharedApi({String? baseUrl})
  : baseUrl = baseUrl ?? const String.fromEnvironment(
      'SHARED_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8787',   // ← 默认值
    )
```

这个开关在 **5 处**决定功能是否存在：

| 文件:行 | 行为 |
| --- | --- |
| `lib/features/sharing/data/shared_api.dart:17` | 所有网络请求的 baseUrl |
| `lib/features/membership/data/membership_repository.dart:158-160` | `baseUrl.isEmpty → LocalOnlyMembershipRepository()`（**永远返回 free**） |
| `lib/features/membership/data/membership_catalog.dart:87-93` | `url.isEmpty → 读 assets/config/membership_catalog.json` |
| `lib/features/assistant/application/assistant_engine.dart:44-49` | `baseUrl.isEmpty \|\| session==null → 本地规则引擎` |
| `lib/features/assistant/application/assistant_policy.dart:32-41` | 同上，远程策略不生效 |

**结论：以当前仓库默认配置构建出的 APK，云端能力（会员、AI、共享）全部降级为本地实现或不可用。**
这不是 bug，是设计；但**发布前必须显式传入 `--dart-define=SHARED_API_BASE_URL=https://...`**，否则商店包会是一个「永远免费、AI 只有关键词、无法共享」的版本。这条容易被漏掉，列入 P0。

另外 `shared_api.dart:21-26` 有一层强制保护：

```dart
if (uri.scheme != 'https' &&
    !(uri.scheme == 'http' && ['127.0.0.1','localhost','10.0.2.2'].contains(uri.host))) {
  throw ArgumentError('共享服务仅允许 HTTPS 或本机联调地址');
}
```

→ 生产必须 HTTPS。这一条与 `android/app/src/main/res/xml/network_security_config.xml`（全局禁明文，仅放行回环）一致，属于**正面设计**。

### 1.3 身份系统真相：`'user-local'` 是一个字符串常量

```dart
// lib/core/database/app_database.dart:704
String currentActor = 'user-local';

// lib/core/database/database_seeder.dart:7-14
abstract final class SeedIds {
  static const personalBook = 'book-personal';
  static const localUser    = 'user-local';
}
```

- 每一行业务数据都带 `user_id / created_by / updated_by`，全部来自 `currentActor`。
- **唯一的切换点**：`lib/features/sharing/data/session_repository.dart:65`（登录后 `setSyncActor(user.id)`）与 `:102`（登出后 `setSyncActor('user-local')`）。
- 没有本地用户表、没有 profile 记录、没有多用户数据分区、没有账号切换。

一句话：**这个 App 的「用户系统」实际上是共享账本的会话系统，不是账户系统。** 详见 §5。

---

## 2. 完整项目功能树

图例：**✅ 完整** ｜ **🟡 基本** ｜ **🟠 部分** ｜ **🔵 仅UI** ｜ **🟣 后端有前端未接** ｜ **⚪ 占位** ｜ **🔴 缺失** ｜ **❓ 无法确认**

```
好好记账
├── 用户系统
│   ├── 本地身份（隐式游客）              ✅ currentActor='user-local'，无需登录即可完整记账
│   ├── 注册 / 登录（用户名+密码）        🟡 仅存在于 /profile/family 页内，为共享账本服务
│   ├── 登出                             ✅ session_repository.dart:89-96
│   ├── 登录态持久化                     ✅ flutter_secure_storage，key='shared_ledger_session_v1'
│   ├── Access Token                     ✅ 32字节随机不透明 token，sha256 存库
│   ├── Refresh Token / Token 刷新        🔴
│   ├── Token 失效处理（401 自动登出）    🟠 server 会 401，但客户端只抛异常不清理会话
│   ├── 手机号登录 / 短信验证码           🔴
│   ├── 邮箱登录                         🔴
│   ├── 第三方登录（微信/Apple）          🔴 SDK 存在但仅用于支付，无登录
│   ├── 找回密码 / 修改密码               🔴
│   ├── 账号注销 / 用户数据删除           🔴
│   ├── 设备管理 / 多设备登录             🟠 服务端允许多 session，但无列表/踢出
│   ├── Profile（头像/昵称）              🔴 只有 username 只读展示
│   └── 游客数据转正式账号                🔴 登录只切 actor，不迁移 owner_user_id
│
├── 首页 (/)                              ✅ lib/features/home/presentation/home_page.dart:901行
│   ├── 当前账本 + 书架抽屉切换           ✅ book_selector.dart:2232行
│   ├── 月度收支 / 今日安心可花           ✅
│   ├── 目标计划卡片                      ✅
│   ├── 资产总览卡片                      ✅
│   ├── 收支趋势 / 分类支出               ✅
│   ├── 最近流水（限10条，排除未来）       ✅ transactionDao.watchActive(onlyOccurred:true)
│   ├── 会员入口                          ✅ MembershipButton → /profile/membership
│   ├── AI 助手入口                       ✅ → /assistant
│   ├── 消息/通知入口                     ✅ → /profile/payment-notifications
│   └── 首页推广位（homePromo）           🔵 PlacementSurface.homePromo 有配置，**0 调用点**
│
├── 记一笔（中央 + 号）                   ✅ quick_add_sheet.dart:2192行
│   ├── 支出/收入/转账/债务（借入借出还款）✅
│   ├── 一级分类 5列网格 + 二级横滑       ✅
│   ├── 金额计算器表达式（+ − × ÷）        ✅
│   ├── 账户 / 报销 / 账本 / 附件 / 图片   ✅
│   ├── 日期 / 定期付 / 更多（商户/计划内/标签）✅
│   ├── 语音记账入口                      🟡 真实识别，但解析为纯正则（见 §11.3）
│   ├── AI 记账入口                       🟠 仅本地规则 + 关键词回复
│   ├── 图片/OCR 记账                     🔴 assistant_page.dart:98 明示"识别开发中"，未上传
│   └── 再记（连续记账）                  ✅
│
├── 自动记账（Android 独有）              🟡 真实原生实现，见 §2.1
│   ├── 微信无障碍读屏 + 规则解析         ✅ AutoBookkeepingAccessibilityService.kt:189行
│   ├── 悬浮窗确认卡片（不静默写入）       ✅ AutoBillOverlayService.kt:162行
│   ├── 支付通知监听（微信/支付宝/云闪付）🟡 PaymentNotificationListenerService.kt:54行
│   ├── 后台 Flutter Engine + 幂等落库     ✅ AutoBookkeepingBridge.kt / auto_bookkeeping_background.dart
│   ├── 自动记账日志页                    ✅ /profile/autobookkeeping/logs
│   └── iOS 支持                          🔴 Dart 侧直接抛 StateError('自动记账仅支持 Android')
│
├── 账本管理（books）
│   ├── 个人 / 家庭 / 企业账本            ✅
│   ├── 新建 / 重命名 / 归档              ✅ book_repository.dart:361行
│   ├── 书架抽屉 UI                       ✅
│   ├── 额度：Free 10 / Pro 20 / Family 50 ✅ 但服务端另限"自建共享账本 ≤ 3"
│   └── 共享账本（邀请/成员/角色/同步）    🟡 见 §2.2
│
├── 账户 / 资产管理
│   ├── 账户增删改 / 归档 / 拖拽排序       ✅ account_management_page.dart
│   ├── 余额校准                          ✅ 生成 adjustment 流水
│   ├── 账户识别后四位（唯一约束）         ✅ app_database.dart:985-991
│   ├── 资产总览 / 资产负债 / 净资产        ✅ asset_overview_page.dart:951行
│   ├── 资金形式（assetForm）              ✅
│   └── 资产趋势图                        ✅ asset_dashboard_charts.dart:942行
│
├── 投资管理                              🔴 **行情全为假数据**，见 §11.1
│   ├── 股票/基金/债券/虚拟币 四类         ✅ 表结构与UI真实
│   ├── 持仓 / 成本 / 交易记录             ✅ investment_transactions 真实持久化
│   ├── 当前价格 / 今日涨跌 / 总收益        🔴 MockMarketDataProvider 正弦波合成价格
│   ├── 行情缓存                          🔴 MemoryQuoteCache（RedisQuoteCache 是 UnimplementedError 桩）
│   └── 服务端 /investment/* 接口          🔴 ApiInvestmentRepository 全为 _unimplemented()
│
├── 预算                                  ✅ budget_page.dart:500行
│   ├── 月度总预算 / 分类预算              ✅ 唯一约束(bookId,monthKey,categoryId)
│   ├── 使用率 / 日均可用                  ✅
│   └── 与流水实时扣减                     ✅ 派生计算
│
├── 目标                                  ✅
│   ├── 列表 / 新建 / 排序                 ✅ goals_page.dart
│   ├── 详情 / 编辑 / 封面上传             ✅ goal_detail_page.dart:1129行
│   ├── 阶段节点（milestones）             ✅ 达成自动标记 completed_at
│   ├── 贡献 / 取出 / 调整                 ✅ goal_contributions
│   ├── 完成庆祝                          ✅
│   └── 预测（月度预留）                   ✅ monthlyReservationInCents
│
├── 趋势分析（/analysis）                  ✅ analysis_page.dart:603行
│   ├── 周期切换 / 币种切换                ✅
│   ├── 现金流趋势 / 分类构成              ✅ cashflow_cards.dart:330行
│   ├── 消费习惯（时段/周末）              ✅ TransactionFeatureService
│   ├── 消费热力图                        ✅ _SpendingHeatmap
│   ├── 大额交易检测（中位数×5，夹在500~3000）✅ LargeTransactionDetector
│   ├── 本地洞察 / 基线对比                ✅
│   └── 会员高级报表                      🟠 权益枚举存在，客户端无强制
│
├── 消费日历（/transactions/calendar）     ✅ consumption_calendar_page.dart:525行
│   └── 跨账本视图                        ✅ allTransactionsProvider
│
├── 搜索（/transactions/search）           ✅ transaction_search_page.dart:293行
│
├── 周期账单（/profile/recurring-bills）   ✅ recurring_bill_repository.dart:409行
│   ├── 周期规则（含自定义天数）            ✅ schedule_json
│   ├── 到期自动补流水（幂等）              ✅ 启动/回前台 + Android AlarmManager
│   ├── 提醒通知                          ✅ RecurringBillNotificationScheduler.kt:120行
│   └── 暂停 / 结束                        ✅
│
├── 信用卡分期（/profile/installments）    ✅ installment_plan_repository.dart:376行
│   ├── 分期计划 / 详情                    ✅
│   └── 按还款日批量执行到期期间            ✅
│
├── 报销管理（/transactions/reimbursements）✅ reimbursement_page.dart:326行
│   ├── 待报销 / 已报销                    ✅
│   ├── 报销回款流水（关联原流水）           ✅ 服务端校验金额≤原流水
│   └── 编辑/撤销回款                      ✅
│
├── 退款                                  ✅ refund_service.dart
│
├── 消息中心 / 通知
│   ├── 支付通知记账页                    ✅ payment_notification_page.dart
│   ├── 周期账单提醒                      ✅
│   ├── 自动记账结果通知                  ✅ AutoBookkeepingNotificationController.kt:148行
│   └── 远程推送（Push Token）             🔴 无任何 push SDK
│
├── AI / 智能能力
│   ├── 商户分类记忆                      ✅ 真实规则匹配（exact/keyword，无模糊）
│   ├── 指纹去重                          ✅ 硬编码置信度阈值
│   ├── 账单收件箱（inbox_items）           ✅ bill_inbox_page.dart:334行
│   ├── 经济事件关联（economic_events）     ✅ economic_event_repository.dart
│   ├── 记账助手（/assistant）              🟠 本地关键词匹配为主
│   ├── 服务端 LLM（DeepSeek）              🟣 代码真实，但无 DEEPSEEK_API_KEY → 503
│   └── 语音 AI 兜底解析                   🔴 AiParsingGateway 无实现，ai 参数从未注入
│
├── 云同步                                🟠 仅"共享账本"同步，**个人数据不上云**
│   ├── SQLite 触发器 → sync_outbox        ✅ shared_sync_schema.dart:178行
│   ├── 版本冲突检测（expectedVersion）     ✅
│   ├── ID 映射（sync_id_map）              ✅ shared_id_map.dart:83行
│   ├── 断网重试 / 退避                    ✅ _failures / _retryAfter
│   ├── 权限校验（SQL 层 ACL）              ✅ visibleBooksSql / 触发器 RAISE(ABORT)
│   └── 个人账本备份到云端                 🔴
│
├── 导入导出（/profile/data）
│   ├── CSV 流水导出                      ✅ transaction_csv.dart
│   ├── 完整 SQLite 备份导出               ✅ local_backup_service.dart
│   └── 备份恢复（安全暂存+重启切换）       ✅ AppDatabase.applyPendingRestore
│
├── 会员系统（/profile/membership）
│   ├── 三档套餐（月/季/年）               ✅ 服务端 catalog + 客户端离线兜底
│   ├── 会员页 UI / 权益 / FAQ             ✅ membership_page.dart:495行
│   ├── 订单记录页                        ✅ membership_records_page.dart
│   ├── 服务端会员状态查询                 ✅ GET /membership/current
│   └── 权益强制执行（客户端）              🔴 ensureMembershipFeatureAvailable 0 调用点
│
├── 支付系统
│   ├── 微信 App 支付（APIv3 签名）         ✅ 服务端真实实现
│   ├── 支付宝 App 支付（RSA2）             ✅ 服务端真实实现
│   ├── 回调验签（RSA/AES-GCM/金额/appid）  ✅ 真实且严谨
│   ├── 商户配置                          🔴 全部为 YOUR_* 占位
│   ├── 退款                              🔴 无任何退款路由
│   └── 主动查单/对账                      🔴 无
│
├── 广告系统                              🔴 **无任何广告 SDK**，见 §6
│   ├── 广告位模型/策略/事件表              🟡 骨架完整
│   ├── AdProvider                        ⚪ 唯一实现 UnconfiguredAdProvider（恒 false）
│   ├── 远程广告配置                       🔴 BundledPlacementConfigRepository 为 const 硬编码
│   ├── 开屏 / 插屏 / 激励 / 信息流         🔴 无 SDK、无页面、无路由
│   ├── 内部推广卡（目标页）                🟡 PlacementSlot 唯一调用点
│   └── 会员去广告                         ✅ adFree 权益 → PlacementPolicy:38
│
├── 用户统计 / 埋点                       🔴 **完全不存在**，见 §7
├── 崩溃上报                              🔴 无 Crashlytics/Sentry/自定义上报
├── 远程配置 / Feature Flag               🔴
├── 公告 / 活动配置                       🔴
├── 维护模式 / 最低版本限制                🔴
├── APP 更新系统                          🔴 **完全不存在**，见 §8
├── 设置                                  🟡 我的页内底部弹窗（profile_page.dart:302-367），无独立设置页
├── 数据与隐私
│   ├── 隐私政策 / 用户协议                🔴 仅占位文案："正式会员服务协议详情尚未配置"
│   ├── 第三方 SDK 清单                    🔴
│   ├── 权限说明                           🟠 系统权限弹窗有，App 内无说明页
│   └── 数据删除入口                       🔴 无（只有备份/恢复，无清空）
├── 系统基础设施
│   ├── Drift migration（v1→v18，18个版本） ✅ app_database.dart:744-934，含迁移前自动备份
│   ├── 软删除                            ✅ deletedAt
│   ├── 外键约束                          ✅ PRAGMA foreign_keys = ON
│   ├── 数据库索引                        ✅ 13+ 处 CREATE INDEX
│   ├── 后台 isolate 数据库连接            ✅ NativeDatabase.createInBackground
│   └── 统一错误码 / API 错误处理           🟠 Fastify setErrorHandler 有，客户端无统一拦截器
│
└── 其他实际扫描出的模块
    ├── 企业账本模板（工资薪酬等）          ✅ category_templates.dart:590行
    ├── 附件管理（transaction_attachments） ✅ 独立表 + 旧 metadata 迁移
    ├── 商品/服务类别模板                  ✅
    └── luna 数据完整性测试                ✅ test/luna_data_integrity_test.dart
```

### 2.1 自动记账：真实原生栈（这是一个被低估的亮点）

`AndroidManifest.xml` 声明了 3 个真实后台组件：

```xml
<!-- android/app/src/main/AndroidManifest.xml:38-55 -->
<service android:name=".PaymentNotificationListenerService"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" .../>
<service android:name=".autobookkeeping.accessibility.AutoBookkeepingAccessibilityService"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE" .../>
<service android:name=".autobookkeeping.overlay.AutoBillOverlayService"
    android:foregroundServiceType="specialUse" .../>
```

解析是**确定性规则**，不是 ML（`WeChatPaymentParser.kt:9-42`），且**拒绝猜测**：

```kotlin
// WeChatPaymentParser.kt:40
if (winners.size != 1) return null // Ambiguous amounts require a better rule, never guess.
```

**不会静默写入**——悬浮层自身文案（`AutoBillOverlayService.kt:52`）与确认页强制选择账本/账户/分类后才调用真实记账服务。

局限（必须如实说明）：
- 仅支持**微信**（`PaymentRule.kt:5` `val app = "com.tencent.mm"`），依赖硬编码的 Activity 类名（`WalletPayUI`/`WalletOrderInfo` 等），**微信改版即失效**。
- iOS **完全没有**（Dart 侧 `auto_bookkeeping_settings.dart:75` 抛 `StateError`）。
- 无短信读取（未声明 `RECEIVE_SMS`）。
- `CategoryResolver.kt` 里声明的 `AiCategoryProvider` 接口**无任何实现或引用**；分类逻辑是硬编码品牌词典（麦当劳/肯德基/瑞幸/星巴克→餐饮，滴滴→交通）。

### 2.2 共享账本同步：架构真实且严谨，但仅服务"共享账本"

```dart
// lib/core/database/shared_sync_schema.dart:130-140（节选）
CREATE TRIGGER sync_transactions_insert AFTER INSERT ON transactions
  WHEN (SELECT suppress FROM sync_control WHERE id=1)=0 AND EXISTS(SELECT 1 FROM sync_books WHERE book_id=NEW.book_id)
  BEGIN
    SELECT CASE WHEN NOT EXISTS(...access=1) THEN RAISE(ABORT,'共享账本当前不可写，请登录并验证成员权限') END;
    SELECT CASE WHEN NOT (manager OR memberAllowed) THEN RAISE(ABORT,'没有修改这项共享数据的权限') END;
    INSERT INTO sync_outbox(...) VALUES(...);
  END
```

亮点：**权限校验下沉到 SQLite 触发器层**，任何走 DAO 的写入都无法绕过 ACL；`expectedVersion` 做乐观锁冲突检测；服务端 `store.ts:116-167` 有幂等回执（`operations` 表）与批量原子性。

服务端 `store.ts:90` 还有额度限制：`check(owned<3,'已达到三个自建共享账本上限',409)` —— 与客户端的 Free 10 / Pro 20 额度**语义不一致**（前者指"自建共享账本"，后者指"全部账本"），需要产品确认是否为有意设计。

---

## 3. 页面 → 功能 → 后端 对应关系

> 说明：**"调用 API"列中的 `/api/v1/...` 全部指共享后端**。绝大多数页面不调用任何 API——这是本地优先架构的正常结果，不是缺陷。

| 页面 | 页面入口 | 页面功能 | 当前状态 | 调用 API | 数据表 | 本地存储 | 第三方服务 | 问题 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 首页 `/` | 底部Tab | 月度收支/今日可花/目标/资产/趋势/分类/最近流水 | ✅ | 无 | transactions, accounts, budgets, goals | Drift | 无 | homePromo 推广位 0 调用点 |
| 记账助手 `/assistant` | 首页按钮 | 关键词问答 + 本地规则记账 | 🟠 | `POST /assistant/authorize`、`/assistant/chat`（需 define+登录） | 读本地 | Drift | DeepSeek（无 key→503） | 图片/OCR 明示未实现 |
| 流水 `/transactions` | 底部Tab | 全部/支出/收入/搜索/日历/收件箱/报销入口 | ✅ | 无 | transactions | Drift | 无 | — |
| 流水搜索 `/transactions/search` | 流水页 | 商户/分类/备注搜索 | ✅ | 无 | transactions | Drift | 无 | — |
| 账单收件箱 `/transactions/inbox` | 流水页 | 分类不确定/疑似重复/缺账户 | ✅ | 无 | inbox_items, transactions | Drift | 无 | — |
| 报销管理 `/transactions/reimbursements` | 流水页 | 待报销/已报销汇总 | ✅ | 无 | transactions | Drift | 无 | — |
| 消费日历 `/transactions/calendar` | 首页/我的 | 月历日金额（跨账本） | ✅ | 无 | transactions | Drift | 无 | — |
| 交易详情 `/transactions/:id` | 多入口 | 详情/编辑/分类修正/附件/删除 | ✅ | 无 | transactions, transaction_attachments | Drift + 文件 | open_filex | — |
| 收支分析 `/analysis` | 流水Tab | 现金流/分类/习惯/热力图/洞察 | ✅ | 无 | transactions | Drift | 无 | 全量内存计算 |
| 目标列表 `/goals` | 底部Tab | 进行中/已完成/新建/排序 | ✅ | 无 | goals, goal_milestones | Drift | 无 | **唯一** PlacementSlot 调用点 |
| 目标详情 `/goals/:id` | 目标列表 | 编辑/节点/存取/调整/预测/庆祝 | ✅ | 无 | goals, goal_milestones, goal_contributions | Drift + 文件 | 无 | — |
| 我的 `/profile` | 底部Tab | 会员/家庭/数据/通知/资产/分类/预算入口 | ✅ | 无 | 读多表 | Drift | 无 | 设置无独立页 |
| 数据与安全 `/profile/data` | 我的 | CSV导出 / SQLite备份 / 恢复 | ✅ | 无 | 全库 | Drift + 文件 | file_picker | 无"清空数据"入口 |
| 资产总览 `/profile/assets` | 我的/首页 | 资产/负债/净资产/资金形式/校准 | ✅ | 无 | accounts, transactions | Drift | 无 | — |
| 账户管理 `/profile/accounts` | 资产总览 | 增删改/归档/排序/校准 | ✅ | 无 | accounts | Drift | 无 | — |
| 账户详情 `/profile/accounts/:id` | 资产总览 | 单账户流水/趋势 | ✅ | 无 | accounts, transactions | Drift | 无 | — |
| 分类管理 `/profile/categories` | 我的 | 一/二级增删改/排序/隐藏 | ✅ | 无 | categories | Drift | 无 | — |
| 预算管理 `/profile/budgets` | 我的/首页 | 月度总预算/分类预算/使用率 | ✅ | 无 | budgets | Drift | 无 | — |
| 会员中心 `/profile/membership` | 我的/首页 | 套餐/权益/FAQ/支付/协议 | 🟡 | `GET /membership/catalog`、`POST /membership/orders`、`GET /membership/current` | — | 无 | wechat_kit, alipay_kit | 商户配置全占位；协议文案占位 |
| 会员订单记录 `/profile/membership/records` | 会员页 | 订单列表 | 🟡 | `GET /membership/orders` | — | 无 | 同上 | — |
| 家庭/企业共享 `/profile/family` | 我的/首页 | **登录/注册**/建共享账本/邀请/成员/同步/冲突 | 🟡 | `/auth/*`、`/books*`、`/invitations/accept` | books, sync_* | Drift + secure_storage | 无 | 登录藏在此页；family_* 5张表是死表 |
| 支付通知记账 `/profile/payment-notifications` | 我的 | 通知权限/开关/待处理通知 | 🟡 | 无 | app_settings | Drift | 原生 MethodChannel | Alipay/云闪付下游链路未验证 |
| 自动记账 `/profile/autobookkeeping` | 我的 | 权限引导/开关/诊断 | 🟡 | 无 | app_settings | Drift | 无障碍+悬浮窗 | 仅 Android+仅微信 |
| 自动记账日志 `/profile/autobookkeeping/logs` | 自动记账页 | 识别日志 | ✅ | 无 | — | 原生 SharedPreferences | 无 | — |
| 自动记账确认 `/profile/autobookkeeping/confirm` | **仅原生深链** | 确认候选并落库 | ✅ | 无 | transactions | Drift | 无 | Flutter 内无入口，靠 `AutoBillOverlayService.kt:121` |
| 周期账单 `/profile/recurring-bills` | 我的 | 周期配置/自动记账/暂停 | ✅ | 无 | recurring_bills, transactions | Drift | AlarmManager | — |
| 信用卡分期 `/profile/installments` | 我的 | 分期计划/批量执行 | ✅ | 无 | installment_plans, transactions | Drift | 无 | — |
| 分期详情 `/profile/installments/:id` | 分期列表 | 每期还款登记 | ✅ | 无 | 同上 | Drift | 无 | — |
| 投资总览 `/profile/investments` | 资产总览 | 四类持仓/市值/收益 | 🔴 | 无 | investment_* | Drift | **Mock 行情** | 价格是假数据 |
| 投资持仓 `/profile/investments/holdings/:type` | 投资总览 | 分类持仓 | 🔴 | 无 | 同上 | Drift | Mock | 同上 |
| 投资详情 `.../detail/:holdingId` | — | 单个持仓详情 | 🔴 | 无 | 同上 | Drift | Mock | **路由参数不匹配，页面无法打开**（见 §11.4） |
| 新增投资 `/profile/investments/add` | 投资总览 | 新增持仓/交易 | 🔴 | 无 | investment_* | Drift | Mock | 行情假数据 |
| 启动页（Splash） | — | — | ⚪ | — | — | — | — | **无路由、无页面**；AdFormat.splash 是死代码 |

---

## 4. 后端功能树（server/）

### 4.1 全部 API 端点（共 24 个）

| 模块 | Method + Path | 文件:行 | Service/逻辑 | 数据表 | 鉴权 | 前端是否真实调用 |
| --- | --- | --- | --- | --- | --- | --- |
| Health | `GET /health` | `app.ts:48` | 静态 | — | 无 | ❌ 未调用 |
| Auth | `POST /api/v1/auth/register` | `app.ts:49-60` | scrypt hash | users, sessions | 无（限流10/min） | ✅ `family_page.dart:194` |
| Auth | `POST /api/v1/auth/login` | `app.ts:61-68` | scrypt + timingSafeEqual | users, sessions | 无（限流15/min） | ✅ |
| Auth | `GET /api/v1/auth/me` | `app.ts:69` | authenticate | users, sessions | Bearer | ❌ **前端从未调用** |
| Auth | `POST /api/v1/auth/logout` | `app.ts:70-73` | 删当前 session | sessions | Bearer | ✅ |
| Books | `GET /api/v1/books` | `app.ts:75` | `store.list` | books, members | Bearer | ✅ sync service:70 |
| Books | `POST /api/v1/books` | `app.ts:76-80` | `store.create`（快照导入+重算） | 全部 | Bearer | ✅ |
| Books | `GET /api/v1/books/:id/snapshot` | `app.ts:82` | `store.snapshot` | entities, changes | Bearer + role | ✅ |
| Books | `GET /api/v1/books/:id/changes` | `app.ts:83-86` | 游标增量（LIMIT 500） | changes | Bearer + role | ✅ |
| Books | `POST /api/v1/books/:id/mutations` | `app.ts:87-90` | 幂等+乐观锁+重算 | 全部 | Bearer + writable | ✅ |
| Members | `GET /api/v1/books/:id/members` | `app.ts:91-94` | 成员列表 | members, users | Bearer + role | ✅ |
| Members | `PATCH /api/v1/books/:id/members/:userId` | `app.ts:95-99` | 改角色 | members | owner | ✅ |
| Members | `DELETE /api/v1/books/:id/members/:userId` | `app.ts:100-103` | 移除成员 | members | owner/admin | ✅ |
| Invite | `POST /api/v1/books/:id/invitations` | `app.ts:104` | 生成邀请码(7天) | invitations | manager | ✅ |
| Invite | `GET /api/v1/books/:id/invitations` | `app.ts:105-108` | 邀请列表 | invitations | manager | ✅ |
| Invite | `DELETE /api/v1/books/:id/invitations/:id` | `app.ts:109-113` | 撤销 | invitations | manager | ✅ |
| Invite | `POST /api/v1/invitations/accept` | `app.ts:114` | 接受邀请 | members, invitations | Bearer | ✅ |
| Logs | `GET /api/v1/books/:id/logs` | `app.ts:115-118` | 操作日志(100条) | changes, users | Bearer + role | ❓ 未在 lib/ 中找到调用 |
| Catalog | `GET /api/v1/membership/catalog` | `membership_catalog.ts:27` | zod 校验的配置 | membership_catalog | 无 | ✅ `membership_catalog.dart:98` |
| Catalog | `PUT /api/v1/admin/membership/catalog` | `membership_catalog.ts:28-37` | 管理端写入 | membership_catalog | **Admin Token(≥32, timingSafeEqual)** | N/A（运营接口） |
| Payment | `POST /api/v1/membership/orders` | `payment.ts:326-349` | 服务端定价+真实下单 | membership_orders | Bearer | ✅ `payment_service.dart:22` |
| Payment | `GET /api/v1/membership/orders` | `payment.ts:350-354` | 本人订单50条 | membership_orders | Bearer | ✅ |
| Payment | `GET /api/v1/membership/orders/:id` | `payment.ts:355-361` | 归属校验 | membership_orders | Bearer | ✅ |
| Payment | `GET /api/v1/membership/current` | `payment.ts:362-365` | 会员快照+权益 | membership_subscriptions | Bearer | ✅ |
| Notify | `POST /api/v1/payments/wechat/notify` | `payment.ts:366-381` | **验签+AES-GCM解密+金额校验** | membership_orders/subscriptions | 微信平台签名 | N/A（渠道回调） |
| Notify | `POST /api/v1/payments/alipay/notify` | `payment.ts:382-393` | **RSA2验签+appid+金额校验** | 同上 | 支付宝公钥 | N/A |
| Assistant | `POST /api/v1/assistant/authorize` | `assistant_policy.ts:121` | 配额+限流+幂等 | assistant_* | Bearer | ✅ `assistant_policy.dart:59` |
| Assistant | `POST /api/v1/assistant/chat` | `assistant_policy.ts:125` | 调 DeepSeek | assistant_* | Bearer | ✅ `assistant_engine.dart:234` |
| Assistant | `PUT /api/v1/admin/assistant/catalog\|policy\...` | `assistant_policy.ts:104-120` | 管理端 | assistant_policy | **Admin Token** | N/A |

### 4.2 后端模块判定

| 模块 | Controller/Route | Service | Repository | Model | 表 | 鉴权 | 第三方 | 前端接入 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Auth | ✅ app.ts | ✅ scrypt | Store | ✅ | users, sessions | Bearer + 限流 | 无 | ✅ 部分能力 |
| User | ❌ **无 User 模块** | ❌ | users 表 | ⚪ 仅 id/username | users | — | — | — |
| Ledger(共享) | ✅ 12 端点 | ✅ Store | ✅ | ✅ | books, members, entities, changes, operations | role/writable/manager | 无 | ✅ |
| Transaction | ⚪ 无独立模块 | ✅ validateAndRecalculate | ✅ | ✅ schemas | entities(kind=transactions) | role | 无 | ✅ 通过同步 |
| Account/Asset | ⚪ 同上 | ✅ 余额重算 | ✅ | ✅ | entities(accounts) | role | 无 | ✅ |
| Investment | 🔴 **完全不存在** | 🔴 | 🔴 | 🔴 | 🔴 | — | 🔴 | 前端用本地 Mock |
| Budget/Goal | ⚪ 无独立模块 | ✅ 校验+重算 | ✅ | ✅ | entities(budgets/goals) | role | 无 | ✅ |
| RecurringBill | ⚪ 无独立模块 | ✅ 校验 | ✅ | ✅ | entities(recurring_bills) | role | 无 | ✅ |
| Reimbursement | ⚪ 无独立模块 | ✅ 金额校验 | ✅ | ✅ | entities(transactions) | role | 无 | ✅ |
| Statistics/Analytics | 🔴 **不存在** | 🔴 | 🔴 | 🔴 | 🔴 | — | — | 全在客户端算 |
| Notification | 🔴 **不存在** | 🔴 | 🔴 | 🔴 | 🔴 | — | 无 Push | 仅本地通知 |
| Sync | ✅ 4 端点 | ✅ changes/mutate | ✅ | ✅ | entities, changes, operations | Bearer+role | 无 | ✅ |
| Membership | ✅ 2 端点 | ✅ catalog | ✅ | ✅ zod | membership_catalog, memberships | Admin Token | 无 | ✅ |
| Payment | ✅ 6 端点 | ✅ 签名/验签 | ✅ | ✅ | membership_orders, subscriptions | Bearer+渠道签名 | **微信/支付宝（未配置）** | ✅ |
| Advertisement | 🔴 **不存在** | 🔴 | 🔴 | 🔴 | **ad_events 服务端0引用** | — | 无 | 前端本地表 |
| AppVersion | 🔴 **不存在** | 🔴 | 🔴 | 🔴 | 🔴 | — | — | 🔴 |
| File/附件云存储 | 🔴 **不存在** | 🔴 | 🔴 | 🔴 | 🔴 | — | 无 | 附件仅本地文件 |
| AI | ✅ 2+3 端点 | ✅ 策略+DeepSeek | ✅ | ✅ zod | assistant_policy/memberships/usage/requests/chat_responses | Bearer+Admin | **DeepSeek（无 key）** | ✅ |
| Redis | 🔴 **未使用** | — | — | — | 🔴 | — | 🔴 | `RedisQuoteCache` 是桩 |
| Queue | 🔴 **未使用** | — | — | — | 🔴 | — | — | — |
| Cron Job | 🔴 **无服务端定时任务** | — | — | — | — | — | — | 定时在 Android AlarmManager |

**服务端缺失的基础能力**：日志（`app.ts:21` `logger:false`）、监控、APM、健康探针以外的可观测性、数据库备份策略、TLS 终结、CDN、附件对象存储。

---

## 5. 数据库功能地图

### 5.1 客户端 Drift 表（26 张）

| # | 表名 | 用途 | 对应功能/页面 | 是否在用 | 冗余 | 索引 | 数据一致性风险 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `accounts` | 账户+账面余额 | 账户/资产/首页 | ✅ | — | ✅ idx_accounts_book_identifier_suffix(唯一,部分) | 余额由 `validateAndRecalculate` 重算，本地靠 `_applyBalanceEffect` |
| 2 | `categories` | 一/二级分类 | 分类/记账 | ✅ | — | ❌ **无显式索引**（靠主键） | parentId 两级校验仅在服务端 |
| 3 | `transactions` | 统一流水事实 | 全App | ✅ | — | ✅ idx_transactions_occurred_at / book_deleted | 强（事务内联动余额） |
| 4 | `transaction_attachments` | 交易附件 | 交易详情 | ✅ | — | ✅ 2个 | 文件本体不参与备份/同步 |
| 5 | `goals` | 目标 | 目标 | ✅ | — | ❌ 无 | status 由重算维护 |
| 6 | `goal_milestones` | 目标节点 | 目标详情 | ✅ 经GoalDao | — | ✅ idx_goal_milestones_goal | — |
| 7 | `goal_contributions` | 目标贡献 | 目标详情 | ✅ | — | ✅ idx_goal_contributions_goal | 服务端禁止覆盖已存在贡献 |
| 8 | `app_settings` | KV 偏好 | 全局 | ✅ | — | 主键 | — |
| 9 | `budgets` | 月预算 | 预算/首页 | ✅ | — | ✅ idx_budgets_month | 唯一(bookId,monthKey,categoryId) |
| 10 | `recurring_bills` | 周期账单 | 周期账单 | ✅ | — | ❌ 无 | — |
| 11 | `installment_plans` | 信用卡分期 | 分期 | ✅ | — | ❌ 无 | 总金额=原流水 服务端校验 |
| 12 | `investment_assets` | 投资标的 | 投资 | ✅ | — | ✅ 唯一(type,market,symbol) | **主数据+价格硬编码在代码里** |
| 13 | `investment_holdings` | 持仓 | 投资 | ✅ | — | ✅ 2个 | — |
| 14 | `investment_transactions` | 投资交易 | 投资 | ✅ | — | ✅ 1个 | 注释明确"不写入 transactions" |
| 15 | `investment_snapshots` | 组合快照 | 投资收益曲线 | ✅ | — | 主键(bookId,date) | **快照值来自假行情** |
| 16 | `merchant_rules` | 商户记忆 | 智能分类 | ✅ | — | ✅ idx_merchant_rules_pattern | 唯一(bookId,userId,pattern,type) |
| 17 | `economic_events` | 经济事件候选 | 去重/收件箱 | ✅ | — | ❌ 无 | — |
| 18 | `economic_event_records` | 事件-流水关联 | 同上 | ✅ | — | ✅ idx_event_records_event | 唯一(eventId,transactionId) |
| 19 | `inbox_items` | 待处理收件箱 | 账单收件箱 | ✅ | — | ✅ idx_inbox_status | — |
| 20 | `families` | 家庭空间 | — | 🔴 **死表** | **是（冗余）** | — | 设计被 books+sync_books 取代 |
| 21 | `books` | 账本 | 账本管理 | ✅ | — | ✅ idx_books_owner_archived | — |
| 22 | `family_members` | 家庭成员 | — | 🔴 **死表** | **是** | ✅ 索引存在但表无写入 | 成员真身是服务端 members 表 |
| 23 | `family_invitations` | 家庭邀请 | — | 🔴 **死表** | **是** | ✅ 索引存在 | 邀请真身是服务端 invitations |
| 24 | `family_operation_logs` | 家庭操作审计 | — | 🔴 **死表** | **是** | ✅ 索引存在 | 审计真身是服务端 changes |
| 25 | `family_budgets` | 家庭预算 | — | 🔴 **死表** | **是** | ✅ 主键+唯一键 | 预算真身是 budgets |
| 26 | `ad_events` | 广告事件 | 推广位频控 | 🟠 仅本地 | 服务端无消费 | ✅ idx_ad_events_placement_time | 永不外发 |

**验证依据**（`grep` 结果）：`familyBudgetEntries` / `familyOperationLogEntries` / `familyInvitationEntries` / `familyEntries` / `familyMemberEntries` 在 `lib/` 中（排除 `app_database.g.dart` 与 `app_database.dart` 自身）**引用数均为 0**。
`FamilyDao`（`app_database.dart:2053-2115`）虽然在 `@DriftAccessor(tables: [...])` 里声明了这 5 张表，但**所有方法只操作 `bookEntries`**。→ 这是明确的**孤立表 / 架构冗余**。

### 5.2 同步辅助表（原始 SQL，6 张）

| 表名 | 用途 | 在用 |
| --- | --- | --- |
| `sync_control` | 当前 actor + 批处理抑制开关 | ✅ |
| `sync_books` | 本地账本↔远端账本映射 + 角色 + 游标 + 权限 | ✅ |
| `sync_id_map` | 本地ID↔远端ID 映射 | ✅ |
| `sync_versions` | 已确认版本（乐观锁基线） | ✅ |
| `sync_outbox` | 待上行的 mutation 队列 | ✅ |
| `sync_promotions` | 提升为共享账本时的暂存 | ❓ 未见读写调用（需确认，标记❓） |

### 5.3 服务端表（7 张 + 1 视图级）

`users`、`sessions`、`books`、`members`、`invitations`、`entities`、`changes`、`operations`（`store.ts:16-24`）+ `book_import_versions`（`store.ts:36`）+ `membership_orders`、`membership_subscriptions`（`payment.ts:100-124`）+ `membership_catalog`（`membership_catalog.ts:17`）+ 5 张 `assistant_*`（`assistant_policy.ts:43-49`）。

**缺失**：无 `app_versions`、无 `devices/push_tokens`、无 `analytics_events`、无 `ad_placements/ad_events`、无 `investment_*`、无 `attachments/files`。

### 5.4 索引与一致性小结

- ✅ **正面**：`transactions`、`goals` 相关、`budgets`、`accounts`、`investment_*`、`ad_events`、`attachments` 均有针对性索引。
- 🟠 **缺索引**：`categories`、`goals`、`recurring_bills`、`installment_plans`、`economic_events` 无显式索引（当前数据量下影响有限）。
- 🔴 **一致性风险**：客户端 `transactions_repository.dart:272-302` 的 `_mapEntities` / `_mapEntity` **每次映射都全量 `categoryDao.getAll()`**；`quick_bookkeeping_service.dart:177` 的 `_linkedReimbursements` 调用 `_transactions.getAll()`（全表加载）。这是 §10 明确记录的技术债，数据量大后必然成为性能瓶颈。
- 🔴 **孤立表**：`families` / `family_members` / `family_invitations` / `family_operation_logs` / `family_budgets`（5 张）。

---

## 6. 用户账户系统专项检查

### 6.1 27 项能力逐项判定

| # | 能力 | 判定 | 证据 |
| --- | --- | --- | --- |
| 1 | 用户注册 | 🟡 **存在** | `family_page.dart:189-210`；`session_repository.dart:74-78`；`server/app.ts:49-60` |
| 2 | 登录 | 🟡 **存在** | 同上 `:189-204` / `:68-87` / `app.ts:61-68` |
| 3 | 退出登录 | ✅ | `family_page.dart:221-234`；`session_repository.dart:89-96`；`app.ts:70-73` |
| 4 | 手机号登录 | 🔴 缺失 | 服务端用户名正则 `app.ts:14` 禁止手机号字符 |
| 5 | 短信验证码 | 🔴 缺失 | `grep 验证码\|verifyCode\|sms` → 0 命中 |
| 6 | 邮箱登录 | 🔴 缺失 | 正则无 `@` |
| 7 | 第三方登录 | 🔴 缺失 | `wechat_kit`/`alipay_kit` 仅用于支付，无登录调用；无 Apple 登录依赖 |
| 8 | Apple 登录 | 🔴 缺失 | 无 `sign_in_with_apple` |
| 9 | 微信登录 | 🔴 缺失 | 同上 |
| 10 | 账号注销 | 🔴 缺失 | `grep 注销` → 0 命中；服务端无 DELETE user 路由 |
| 11 | 找回密码 | 🔴 缺失 | 无路由、无 UI |
| 12 | 修改密码 | 🔴 缺失 | 同上 |
| 13 | 设备管理 | 🔴 缺失 | 服务端存 sessions 但无列表/踢出端点 |
| 14 | 登录状态持久化 | ✅ | `SecureSessionStorage`，`session_repository.dart:22-32` |
| 15 | Access Token | ✅ | 32字节随机不透明token，`app.ts:40-43`，sha256 落库 |
| 16 | Refresh Token | 🔴 缺失 | `sessions(token_hash,user_id,expires_at)` 无该字段 |
| 17 | Token 刷新 | 🔴 缺失 | 无 `/refresh`，无客户端调用 |
| 18 | Token 过期处理 | 🟠 部分 | 客户端恢复时检查(`:55-59`)、服务端 401(`app.ts:36`)，**但会话中收到 401 不会清理本地会话** |
| 19 | 多设备登录 | 🟠 部分 | 表结构允许多 session，但无管理界面 |
| 20 | 用户 Profile | 🟠 部分 | `SessionUser` 仅 id+username；`GET /auth/me` 存在但**前端从未调用** |
| 21 | 头像 | 🔴 缺失 | 仅文案声称默认头像；无上传/字段 |
| 22 | 昵称 | 🔴 缺失 | `grep 昵称\|nickname` → 0 命中 |
| 23 | 用户 ID | ✅ 内部存在 | `SessionUser.id`；**从不展示给用户** |
| 24 | 游客模式 | 🔴 作为"功能"缺失 | `grep 游客` → 0 命中；实际是隐式的 `user==null` 本地模式 |
| 25 | 游客数据转正式账号 | 🔴 缺失 | 登录只 `setSyncActor`，**不迁移 `owner_user_id`** |
| 26 | 账号删除 | 🔴 缺失 | 无 UI、无 API |
| 27 | 用户数据删除 | 🔴 缺失 | 无清空本地数据入口；`invalidate()` 只清 token |

**统计：✅ 4 项 / 🟡 3 项 / 🟠 3 项 / 🔴 17 项。**

### 6.2 已发现的账户系统缺陷

```dart
// lib/features/family/presentation/family_page.dart:529-535
final joined = (await ref.read(bookRepositoryProvider)
        .getForUser('user-local'))          // ← 硬编码，即使已登录
    .firstWhere((b) => b.sharedId == member.familyId);
```

已登录时 `currentActor == <服务端用户ID>`（`session_repository.dart:85`），因此 `getForUser('user-local')` **可能查不到刚刚加入的账本**。DAO 本身是参数化的（`app_database.dart:2066-2080`），属于调用点误用。

### 6.3 建议的最小账户系统方案

**原则：不要做大而全的账户中心。** 当前 App 的定位是"本地优先记账"，账户只在需要**共享/支付/多设备**时才必要。

**第一阶段（P0，最小可用）**
1. 把 `session_repository` 提升为正式 `auth` 模块（不改表、不改协议，只搬目录 + 补 UI）：独立的 `/profile/account` 页承载登录/注册/退出，`family_page` 只做共享账本。
2. **登录后本地数据认领**：`setSyncActor` 时若存在 `owner_user_id='user-local'` 的个人账本，提示"是否把本地账本绑定到该账号"，绑定即批量 `UPDATE accounts/categories/... SET owner_user_id=?`。这是把"游客数据转正"从前端一行 `setSyncActor` 变成真实闭环。
3. **401 统一处理**：在 `shared_api.dart` 统一拦截 401 → 调 `sessionRepository.invalidate()` → 回到本地模式并提示重新登录。
4. **账号注销 + 数据删除**：服务端 `DELETE /api/v1/users/me`（级联删 sessions/members/owned books），客户端二次确认后同时清空本地库。
5. **隐私政策 / 用户协议**：静态页 + 首次启动同意门。

**第二阶段（P1，生产必需）**
6. Refresh Token（或在现有 30 天不透明 token 上做滑动续期），避免用户每 30 天被登出。
7. 设备管理：`GET /api/v1/auth/sessions` + `DELETE .../sessions/:id`。
8. 第三方登录：**只接微信**（与已有 `wechat_kit` 复用，成本最低）。Apple 登录在 iOS 上架若提供第三方登录则是**强制要求**，届时再补。

**第三阶段（P2）**
9. 修改密码、找回密码（短信需接短信服务商）。
10. Profile 扩展（昵称/头像）。

---

## 7. 广告系统专项检查

### 7.1 现状：**没有任何真实广告能力**

```dart
// lib/features/ads/data/placement_repository.dart:189-191
final adProviderProvider = Provider<AdProvider>(
  (ref) => const UnconfiguredAdProvider(),   // ← 唯一绑定
);
```

```dart
// lib/features/ads/domain/ad_provider.dart:11-30
class UnconfiguredAdProvider implements AdProvider {
  Future<bool> isAvailable(AdFormat format) async => false;        // 恒 false
  Future<NativeAdPayload?> loadNative(...) async => null;          // 恒 null
  Future<AdDeliveryResult> showRewarded(...) => completed: false;  // 恒 false
  Future<AdDeliveryResult> showSplash(...)  => completed: false;   // 恒 false
}
```

穷举搜索结果（`pubspec.yaml` / `pubspec.lock` / `.flutter-plugins-dependencies` / `ios/Podfile.lock` / `android/` / `ios/`）：
搜索 `admob|google_mobile_ads|pangle|gromore|bytedance|unity|applovin|ironsource|mintegral|穿山甲|优量汇|oaid` → **0 命中**。

### 7.2 逐项检查结果

| 广告形式 | 代码状态 | 判定 |
| --- | --- | --- |
| 开屏广告 | `AdFormat.splash` 枚举存在，**无 Splash 页面、无 `/splash` 路由** | 🔴 死代码 |
| 首页推广位 | `PlacementSurface.homePromo` 有配置，**0 调用点** | 🔵 未接线 |
| Banner | 无概念 | 🔴 |
| 信息流广告 | `AdFormat.native` 存在，但 `loadNative` 恒 null | 🔴 |
| 激励广告 | `RewardedAdService` 存在但 `:159` 提前返回，全项目 0 生产调用点 | 🔴 死路径 |
| 插屏广告 | 无概念 | 🔴 |
| **内部推广卡** | `PlacementSlot` 渲染 `AppCard`，**全项目仅 1 个调用点**（`goals_page.dart:59`） | 🟡 唯一活着的东西 |

| 广告系统要素 | 判定 | 证据 |
| --- | --- | --- |
| AdSlot（广告位） | 🟡 模型存在 | `PlacementConfig` |
| AdConfig（配置） | 🔴 **硬编码** | `BundledPlacementConfigRepository` 返回 `const [...]`，ads 目录**不 import 任何 HTTP** |
| AdProvider | ⚪ 空实现 | `UnconfiguredAdProvider` |
| 广告位 ID | 🟡 有字符串 ID | `'home-pro-value'` 等 3 条 |
| 远程开关 | 🔴 | 无网络通路 |
| 会员去广告 | ✅ **通** | `payment.ts:181` 授 `adFree` → `placement_policy.dart:38` |
| 广告频率控制 | ✅ | `dailyLimit` + `impressionsToday` |
| 曝光 | 🟡 | 写本地 `ad_events`，但 `sessionId`/`metadataJson` **调用方从不传，恒 NULL** |
| 点击 | 🟡 | 同上 |
| 关闭 | 🟡 | 仅 `RewardedAdService`（死路径） |
| 展示失败 | 🔴 | 无 |
| 广告请求失败 | 🔴 | 无 |
| 广告收入统计 | 🔴 | `ad_events` 服务端 **0 引用**，永不外发 |

### 7.3 缺陷

```dart
// lib/features/ads/data/placement_repository.dart:213
userCreatedAt: DateTime(2020),   // ← 硬编码
```
→ `placement_policy.dart:50-53` 的"新用户 24 小时内不出开屏"规则**永久失效**（虽然开屏本身也不存在）。

### 7.4 适合记账 App 的广告设计建议

**用户体验判断（关键）**：记账 App 的用户对"钱"极度敏感，且使用场景是**高频、短时、私密**。判断如下：

| 广告形式 | 是否适合 | 理由 |
| --- | --- | --- |
| **开屏广告** | ❌ **强烈不建议** | 记账是高频工具（日均 3~8 次），每次打开都被拦截是最大体验杀手；且与"今日安心可花"的即时性冲突 |
| **插屏广告** | ❌ 不建议 | 打断记账流程，容易导致记错/放弃 |
| **Banner** | ⚠️ 谨慎 | 首页空间已被财务数据占满，Banner 会挤压信息密度 |
| **信息流广告** | ❌ 不建议 | 流水列表是用户核对账目的列表，混入广告会破坏"账本=可信记录"的心理模型 |
| **激励视频** | ✅ **推荐（唯一推荐）** | 用户主动选择，换取 AI 记账次数/高级报表等权益，不打断正常流程 |
| **首页/我的 推广位（自有）** | ✅ 推荐 | 当前 `PlacementSlot` 就是这个模式，展示自家会员权益，零风险 |

**建议第一阶段最小广告架构（P1）**：

```
第一阶段只做「激励视频 + 自有推广位」，明确不做开屏/插屏/信息流。

服务端新增（3 张表 + 3 个端点）：
  ad_placements(id, surface, format, provider, provider_slot_id,
               enabled, target_audience, daily_limit, priority,
               start_at, end_at, content_category)     ← 远程配置，替代 const
  ad_events(id, user_id, placement_id, event_type, provider,
            session_id, occurred_at, metadata_json)    ← 服务端可统计
  ad_config(remote_switch, global_daily_cap, min_app_version)

  GET  /api/v1/ads/placements        → 客户端拉取广告配置（带会员/版本过滤）
  POST /api/v1/ads/events            → 批量上报曝光/点击/完成
  PUT  /api/v1/admin/ads/placements  → 运营后台（Admin Token，复用既有模式）

客户端改造（复用现有骨架，不重写）：
  1. PlacementConfigRepository 增加 RemotePlacementConfigRepository
     （BundledPlacementConfigRepository 保留为离线兜底，与 membership_catalog 完全同构）
  2. AdProvider 增加真实实现，只在「激励视频」格式下返回 true
  3. AdEventRepository 增加上报（当前只写不发）
  4. 广告位 ID 一律来自服务端，客户端不硬编码
  5. 会员 adFree 逻辑已通，无需改动

第三方 SDK 选择：
  - 国内 Android：穿山甲(CSJ) 或 优量汇(GDT)，只接激励视频 SDK
  - iOS：若上架中国区，同样这两家；若全球，AdMob
  - 建议自建一层 AdProvider 适配（接口已存在），先接 1 家，避免多 SDK 包体膨胀
```

**远端关闭能力**：`ad_config.remote_switch=false` 时 `GET /ads/placements` 返回空数组，客户端自然不展示——满足"广告必须能通过后端关闭"的要求。

---

## 8. 用户行为统计专项检查

### 8.1 现状：**完全没有**，且比"没有埋点"更彻底

穷举搜索结果（`lib/` + `server/src` + `server/test`，排除 `*.g.dart`）：

```
analytics 1(仅 Icons.analytics_outlined) | Analytics 0 | telemetry 0
sentry 0 | firebase 0 | crashlytics 0 | bugsnag 0 | amplitude 0
umeng 0 | 友盟 0 | 埋点 0 | logEvent 0 | trackEvent 0 | track( 0
appsflyer 0 | datadog 0 | mixpanel 0 | posthog 0
reportError 0 | recordError 0 | FlutterError.onError 0
PlatformDispatcher 0 | runZonedGuarded 0
```

- `pubspec.yaml` 依赖中**无任何** analytics/crash/APM 包。
- **没有 `FlutterError.onError`、没有 `runZonedGuarded`、没有 `PlatformDispatcher.instance.onError`** → 崩溃**完全不捕获**。
- 服务端 `app.ts:21` `logger:false`，仅 `console.error`。
- 唯一带 "event" 的表 `ad_events` 是**本地频控计数器**，且从不外发（服务端 0 引用）。

### 8.2 您列出的 25 项指标可得性

| 指标 | 当前可得性 | 原因 |
| --- | --- | --- |
| APP 安装量 | 🔴 | 无埋点 → 只能靠应用商店后台 |
| 注册用户数 | 🟠 | 服务端 `users` 表可查（但只有共享/付费用户，非全部用户） |
| DAU / WAU / MAU | 🔴 | 无 |
| 次日 / 7日 / 30日留存 | 🔴 | 无 |
| 平均使用时长 | 🔴 | 无 |
| 记账次数 / 手动 / 自动 | 🔴 | 无上报（本地有数据但不上云） |
| 创建账本 / 预算 / 目标次数 | 🔴 | 无 |
| 会员页访问 | 🔴 | 无 |
| 会员转化 | 🔴 | 无（服务端有订单表，但无漏斗） |
| 广告曝光 / 点击 | 🟡 | 本地 `ad_events` 有，**但不上报** |
| 功能使用率 | 🔴 | 无 |
| 页面访问情况 | 🔴 | 无 |
| 崩溃率 | 🔴 | **无崩溃捕获** |
| APP 版本分布 | 🔴 | 无 |

### 8.3 建议的最小统计方案（P1）

**原则：不要每个点击都埋点。** 只跟踪真正有产品价值的行为，且**隐私优先**（记账数据绝不上报）。

```
第一阶段（最小闭环，约 1 周）：

客户端（不引入第三方 SDK，先自建轻量层，避免隐私合规复杂度）：
  lib/core/analytics/analytics_service.dart
    - DeviceId: 首次启动生成 UUID，存 app_settings（非硬件标识，合规友好）
    - Session: 应用进入前台开始，退到后台结束（已有 lifecycle 监听可复用，见 app.dart）
    - Queue: 本地表 analytics_events 暂存，批量上报，失败重试（复用 sync_outbox 的模式）
    - 只上报白名单事件，且绝不携带金额、商户、备注等财务内容

  推荐事件（严格限制在您列出的清单内）：
    page_view             (仅一级页面: home/transactions/analysis/goals/profile)
    transaction_created   (仅 type，不含 amount/merchant/note)
    transaction_edited
    transaction_deleted
    auto_bookkeeping_triggered
    ledger_created
    budget_created
    goal_created
    membership_viewed
    membership_purchased
    ad_impression
    ad_clicked

服务端：
  analytics_events(id, device_id, user_id, event, props_json,
                   app_version, platform, occurred_at, session_id)
  POST /api/v1/analytics/events     ← 批量上报
  GET  /api/v1/admin/analytics/*    ← Admin Token 保护的聚合查询

崩溃上报（与统计分开，P0 优先级）：
  服务端新增 crash_reports，客户端 FlutterError.onError + runZonedGuarded 上报堆栈
  生产环境建议直接接 Sentry/Firebase Crashlytics，成本远低于自建
  ⚠️ 崩溃上报是 P0，因为它直接决定"能不能发现线上问题"
```

**重要合规提示**：新增任何上报能力后，**隐私政策必须同步更新**（当前连隐私政策占位页都没有），否则应用商店审核会拒。这与 §9 的隐私缺口是同一件事。

---

## 9. APP 更新系统专项检查

### 9.1 现状：**完全不存在**

搜索 `CheckVersion|updateCheck|app_version|latestVersion|forceUpdate|强制更新|版本更新|AppVersion|package_info` → **0 处业务命中**（仅命中无关的 `_upgradeCategoryTemplate` 等）。

| 检查项 | 状态 |
| --- | --- |
| 当前版本 | 🟡 硬编码在 `pubspec.yaml:19` `version: 1.0.0+1`，且 `profile_page.dart:360` **又硬编码一次** `'版本 1.0.0+1'`（会漂移） |
| Build number / versionCode | 🟡 来自 `flutter.versionCode`，当前 = 1 |
| 后端最低支持版本 | 🔴 |
| 最新版本 | 🔴 |
| 强制更新 | 🔴 |
| 普通更新 | 🔴 |
| 更新公告 | 🔴 |
| 下载地址 | 🔴 |
| 应用商店跳转 | 🔴 |
| 灰度更新 | 🔴 |
| Android 更新 | 🔴 |
| iOS App Store 更新 | 🔴 |
| 维护模式 | 🔴 |
| 最低版本限制 | 🔴 |

Android 侧也没有 `package_info_plus` 依赖，因此**客户端连自己的版本号都读不到**（只能硬编码）。

### 9.2 建议方案（P0，成本极低）

```typescript
// server: 新增 1 张表 + 1 个端点
CREATE TABLE app_versions(
  platform TEXT NOT NULL,            -- 'android' | 'ios'
  version_name TEXT NOT NULL,        -- '1.2.0'
  build_number INTEGER NOT NULL,     -- 12
  minimum_build INTEGER NOT NULL,    -- 低于此值强制更新
  force_update INTEGER NOT NULL DEFAULT 0,
  update_title TEXT,
  update_description TEXT,
  download_url TEXT,                 -- Android APK / 商店页
  store_url TEXT,                    -- iOS App Store
  gray_percent INTEGER DEFAULT 100,  -- 灰度百分比
  published_at INTEGER NOT NULL,
  PRIMARY KEY(platform, build_number)
);

GET /api/v1/app/version?platform=android&build=1
→ {
    latestVersion, latestBuild,
    minimumBuild, forceUpdate,
    updateTitle, updateDescription,
    androidUrl, iosUrl, grayPercent
  }
```

客户端：
1. 加 `package_info_plus`，启动时读取真实 versionName/versionCode（同时修掉 `profile_page.dart:360` 的硬编码）。
2. 启动后（登录与否都要）调一次 `/app/version`。
3. `build < minimumBuild || forceUpdate` → **不可取消**的对话框，Android 跳下载/商店，iOS **只跳 App Store**。
4. 否则可取消的温和提示。
5. 请求失败必须**静默降级**，不能阻塞启动。

⚠️ **合规红线**：iOS **绝不能**自行下载安装包或引导用户去第三方渠道，只能 `itms-apps://` 跳 App Store。Android 若在 Google Play 上架同样受政策限制；国内渠道包可直接下载 APK。

Android 的 `AndroidManifest.xml` 已声明 `INTERNET`，`network_security_config.xml` 允许 HTTPS，**无需新增权限**。

---

## 10. 正式发布缺失的基础能力检查

> 已逐项扫描代码，**不预设缺失**。

| 分类 | 能力 | 状态 | 证据 / 缺口 |
| --- | --- | --- | --- |
| **账号** | 注册 | 🟡 | 见 §6 |
| | 登录 | 🟡 | 见 §6 |
| | 注销 | 🔴 | 无 |
| | 游客模式 | 🟠 | 隐式实现（`user-local`），无显式入口 |
| **稳定性** | Crash Reporting | 🔴 | 无 `FlutterError.onError` / `runZonedGuarded` |
| | 错误日志 | 🟠 | 仅 `debugPrint`(release 剥离) + `console.error` |
| | 异常上传 | 🔴 | 无 |
| | API Error Handling | 🟠 | 服务端 `setErrorHandler` 统一（`app.ts:27-33`）；客户端 `SharedApiException` 有，但无统一拦截/重试/401处理 |
| **网络** | 超时 | ✅ | `shared_api.dart:30,50,54`（10s连接/20s响应） |
| | 重试 | 🟠 | 仅同步服务有退避；普通请求无重试 |
| | 断网处理 | 🟠 | 同步有；其他功能无显式提示 |
| | 弱网处理 | 🔴 | 无 |
| | Token 失效 | 🟠 | 见 §6 #18 |
| | 统一错误码 | 🟠 | 服务端有 message，无业务 error code 枚举 |
| **安全** | HTTPS | ✅ | `shared_api.dart:21-26` + `network_security_config.xml` 双保险 |
| | Token 安全存储 | ✅ | `flutter_secure_storage`（Keychain/Keystore） |
| | 接口鉴权 | ✅ | Bearer + role/writable/manager 分级 |
| | 敏感信息加密 | 🔴 | **本地 SQLite 未加密**（无 sqlcipher，无 PRAGMA key） |
| | 数据库敏感字段 | 🔴 | 金额/商户/备注明文落盘 |
| | API Rate Limit | ✅ | `@fastify/rate-limit` 全局300/min + 登录注册单独限流 |
| | 防重放 | ✅ | 支付回调 ±300s 时间窗；助手请求 body_hash 幂等 |
| | 支付安全 | ✅ | RSA-SHA256 验签 + AES-256-GCM 解密 + 金额/appid/序列号三重校验。**唯一授予路径 `markPaid` 无旁路** |
| | 密码存储 | ✅ | scrypt(salt,64) + `timingSafeEqual` |
| **数据** | 数据库 migration | ✅ | v1→v18 共18个版本，含迁移前自动 VACUUM INTO 备份（`app_database.dart:1162-1176`） |
| | 版本升级 | ✅ | 同上 |
| | 数据备份 | ✅ | 完整 SQLite 备份（含核心表与 schema 版本校验） |
| | 云同步 | 🟠 | 仅共享账本；个人数据不上云 |
| | 冲突解决 | ✅ | `expectedVersion` 乐观锁 + 服务端 409 返回 remote |
| | 软删除 | ✅ | `deletedAt`，且禁止删除有关联的流水 |
| **运营** | Remote Config | 🟠 | 会员 catalog 与助手 policy 可从服务端拉；**广告/功能开关等无** |
| | Feature Flag | 🔴 | 无 |
| | 公告 | 🔴 | 无 |
| | 活动配置 | 🔴 | 无 |
| **APP** | 版本更新 | 🔴 | 见 §9 |
| | 强制更新 | 🔴 | 见 §9 |
| | 维护模式 | 🔴 | 无 |
| | 最低版本限制 | 🔴 | 无 |
| **推送** | Push Token | 🔴 | 无任何 push SDK（无 FCM/JPush/Getui） |
| | 系统通知 | ✅ | 本地通知：周期账单提醒、自动记账结果（`RecurringBillNotificationScheduler.kt`、`AutoBookkeepingNotificationController.kt`） |
| | 消息通知 | 🟠 | 仅本地通知，无服务端触达 |
| | Push 点击跳转 | ✅ | 本地通知深链已通（`MainActivity.kt:302-306` + `app.dart:67-73`） |
| **权限** | 通知权限 | ✅ | `POST_NOTIFICATIONS` + `MainActivity.kt:298` 运行时请求 |
| | 悬浮窗权限 | ✅ | `SYSTEM_ALERT_WINDOW` + `AutoBookkeepingOverlayPermission.kt` |
| | 无障碍权限 | ✅ | `BIND_ACCESSIBILITY_SERVICE` + 引导页 |
| | 相册权限 | 🟠 | iOS 有 `NSPhotoLibraryUsageDescription`；Android 走系统 Photo Picker 免权限（正确做法） |
| | 文件权限 | ✅ | FileProvider（`${applicationId}.fileprovider`）用于附件/相机输出 |
| | 相机权限 | ✅ 设计正确 | Android 不声明 `CAMERA`（走 `ACTION_IMAGE_CAPTURE`，正确）；iOS 已声明 |
| **隐私** | 用户协议 | 🔴 | 仅占位："正式会员服务协议详情尚未配置"（`membership_page.dart:290`） |
| | 隐私政策 | 🔴 | **完全不存在**（`grep 隐私政策` 0 命中） |
| | 权限说明 | 🔴 | 无 App 内说明页 |
| | 隐私授权 | 🔴 | 无首次启动同意流程 |
| | 数据删除 | 🔴 | 见 §6 #27 |
| | 账号注销 | 🔴 | 见 §6 #10 |
| | 第三方 SDK 清单 | 🔴 | 无（虽然当前 SDK 很少，合规仍要求列明） |
| **监控** | 服务器日志 | 🔴 | `logger:false` |
| | API Monitor | 🔴 | 无 |
| | 数据库监控 | 🔴 | 无 |
| | Redis 监控 | N/A | 未使用 Redis |
| | Crash Monitor | 🔴 | 见稳定性 |

**权限声明核查结论（正面）**：Android 声明的 7 个权限**全部有真实代码消费者**，无过度声明；`allowBackup="false"`（财务 App 正确）；定时使用 `setInexactRepeating`/`setAndAllowWhileIdle`，因此未声明精确闹钟权限是**正确的**，不是遗漏。iOS 的 4 个 usage description 全部真实使用。

---

## 11. 核心业务闭环检查

### 11.1 手动记账闭环 —— ✅ **完整闭环**（本项目最扎实的部分）

```
输入金额（支持计算器表达式）
  → 分类（一级5列 + 二级横滑）
  → 金额  → 账户  → 账本  → 时间
  → 报销/退款关联  → 附件  → 周期标记
  → 保存
      lib/features/bookkeeping/application/quick_bookkeeping_service.dart:187-233
  → 事务内写入流水 + 联动账户余额
      transactions_repository.dart:102-115  _database.transaction(() { insertOne; _applyBalanceEffect })
  → 流水（watchAll 响应式）  → 账户余额  → 趋势  → 分类统计  → 预算
```

关键证据（**同一事务内联动，这是正确的根因级实现**）：

```dart
// lib/features/transactions/data/transactions_repository.dart:102-115
return _database.transaction(() async {
  for (final transaction in transactions) {
    if (await _database.transactionDao.findById(transaction.id) != null) {
      throw StateError('Transaction ${transaction.id} already exists');
    }
    await _ensureAccountsExist(transaction);      // 账本/币种/分类一致性
  }
  for (final transaction in transactions) {
    await _database.transactionDao.insertOne(_toCompanion(transaction));
    await _applyBalanceEffect(transaction, 1);    // 余额联动
  }
  return List<TransactionRecord>.unmodifiable(transactions);
});
```

更新时先回滚旧影响再应用新影响（`:130-132`），删除时先撤销影响再软删除（`:183-187`）——**语义正确**。

二级处理失败的处理也很严谨：

```dart
// quick_bookkeeping_service.dart:86-102
/// The ledger transaction and account balance have already committed.
/// Secondary local writes may still need repair, so callers must not retry the
/// bookkeeping request automatically.
class BookkeepingCommittedException extends StateError { ... }
```
→ 附件/智能后处理失败会抛 `BookkeepingCommittedException` 并明确告诉 UI "流水已入账"，**不会重复记账**。这是很好的设计。

**闭环中的小缺口**：`_postProcess` 依赖 `intelligence`（可空），但 `transactionRepositoryProvider` 的普通 `create` 路径**不经过** `QuickBookkeepingService`，因此直接调 repository 的调用方不会触发智能分类。需确认实际调用点是否都走 service。

### 11.2 多账本闭环 —— ✅ 基本闭环，一处语义需确认

```
账本 → 成员 → 流水 → 账户 → 权限 → 共享账户
```

- **共享默认账户下多账本流水能否正确影响同一账户余额？** —— ✅ **能**。
  证据：`transactions_repository.dart:236-243` 通过 `accountBookIdForBook` 解析出目标账户所属的"资产账本"，允许流水账本与账户账本不同：

```dart
final resolvedAccountBookId = accountBookIdForBook?.call(transaction.bookId);
final allowedAccountBooks = <String>{
  transaction.bookId,
  ?accountBookId,
  ?resolvedAccountBookId,
};
```

  而余额更新走 `accountDao.adjustBalance`（按 accountId），因此**多个账本指向同一账户时，余额累加在同一行上**——语义正确。
  `Book.assetSourceBookId`（`app_database.dart:548`）就是为此存在，UI 上是"共用主账本资产"。

- **权限**：客户端 SQL 触发器层强制 ACL（`shared_sync_schema.dart:130-140`），服务端 `writable/manager` 分级。✅
- **成员**：服务端 `members` 表 + 角色 owner/admin/member，客户端 `sync_books.role` 缓存。✅
- 🟠 **需确认**：`store.ts:90` 的"3 个自建共享账本上限"与客户端"Free 10 / Pro 20 / Family 50"额度语义不一致。

### 11.3 周期账单闭环 —— ✅ **完整闭环**

```
创建（周期规则，含自定义天数）
  → 存储 recurring_bills + schedule_json
  → 自动生成：启动 / 回前台 / Android AlarmManager 后台 isolate
      （幂等：每个发生日使用稳定 ID，失败保留到周期账单页提示）
  → 生成真实流水（走 QuickBookkeepingService）
  → 提醒（RecurringBillNotificationScheduler.kt:120行）
  → 修改 / 停止（status: active/paused/ended）
```
证据：`docs/development/CURRENT_STATUS.md` 明确 "周期账单 `auto_record` 会在应用启动/回到前台时幂等补齐到期流水"，且测试 `test/recurring_bill_repository_test.dart`、`test/recurring_schedule_regression_test.dart`、`test/recurring_bill_notification_test.dart` 覆盖。✅

### 11.4 报销闭环 —— ✅ **完整闭环**

```
流水 → 标记待报销（reimbursement_status）
  → 报销列表（/transactions/reimbursements）
  → 报销回款流水（type=reimbursement，关联 relatedTransactionId）
  → 状态自动转 reimbursed / partial（quick_bookkeeping_service.dart:146-159）
  → 统计（reimbursement_page.dart）
```
- 服务端强校验（`store.ts:209-223`）：报销必须关联原流水、原流水必须是 expense/lend/assetPurchase、币种一致、**金额不得超过原流水**。
- 编辑保护：有回款的流水不能直接改报销状态，必须去回款流水处理（`quick_bookkeeping_service.dart:130-144`）。
- 退款同理（`refund_service.dart`）。✅

### 11.5 预算闭环 —— ✅ **闭环**

```
预算（月度总预算/分类预算）
  → 消费流水
  → 实时扣减（派生计算，非物化）
  → 使用率 / 超预算 / 日均可用
  → 首页"今日安心可花"
```
- 首页文案**诚实披露边界**（`home_page.dart:492`）：
  > "今日安心可花 = 可用支出（最低为 0）÷ 剩余天数。仅统计人民币；目标预留汇总所有进行中的目标，不会自动扣款。**未来计划支出、固定账单与周期支出尚未纳入计算。**"
  → 这是**正面做法**：把未纳入的维度明确告诉用户，而不是假装完整。
- 唯一约束 `(bookId, monthKey, categoryId)` 防重复。✅

### 11.6 目标闭环 —— ✅ **完整闭环**

```
目标金额 → 当前金额（由 contributions 重算）
  → 阶段进度（milestones，达成自动写 completed_at）
  → 达成状态（status: active/completed/paused/archived）
  → 完成庆祝（completionCelebrationShown / celebrationShown，防重复）
```
服务端 `store.ts:272-283` 有严格校验：节点必须包含最终金额、节点金额不可重复、节点不得高于最终目标、贡献不可覆盖只能追加调整记录。✅

### 11.7 投资管理闭环 —— 🔴 **记录闭环成立，行情闭环断裂**

```
持仓 → 成本  → ✅ 真实（investment_holdings.averageCost）
当前价格      → 🔴 假数据（MockMarketDataProvider 正弦波）
当前市值      → 🔴 基于假价格
今日涨跌      → 🔴 基于假价格
总收益        → 🟠 算术正确，输入错误
```

**核心证据**：

```dart
// lib/features/investments/data/investment_repository.dart:723-725
final marketDataProviderProvider = Provider<MarketDataProvider>(
  (ref) => MockMarketDataProvider(),      // ← 生产环境唯一注册
);
```

```dart
// lib/features/investments/data/market_data_provider.dart:245-256
final drift = math.sin(dayNumber / 37 + phase) * 0.12
            + math.sin(dayNumber / 11 + phase * 1.7) * 0.05;
final value = base * (1 + drift);         // ← 价格是正弦波
```

```dart
// market_data_provider.dart:280-468
const _catalog = <_Instrument>[
  _Instrument(symbol: '600519', name: '贵州茅台', basePrice: 1680),   // ← 30条硬编码锚定价
  ...
];
```

```dart
// market_data_provider.dart:159-167
// An unknown symbol still gets a stable synthetic quote so a ...
_Instrument(..., basePrice: 100, ...)   // ← 未知代码返回合成 ¥100，而非"未找到"
```

同时存在两个**未接入的桩**：
- `investment_repository.dart:644-717` `ApiInvestmentRepository` → 全部 `_unimplemented()`，未接入 `/investment/*`，**从未被构造**。
- `quote_cache.dart:107-137` `RedisQuoteCache` → `_unimplemented()`，`quoteCacheProvider` 返回 `MemoryQuoteCache`。

**判定**：这个模块**"看起来完成，实际上是空壳"**——4 个 Tab、图表、收益卡片、快照表全部就绪，但**驱动它们的价格是编造的**。用户会看到"贵州茅台 ¥1680 今日 +1.2%"这样的**假财务数据**。这是本项目**最严重的单点问题**（§12 第 1 位）。

**建议**：接入真实行情源（新浪/腾讯财经免费接口，或按需接付费源）。数据流只需替换 `marketDataProviderProvider` 一个 provider（架构已为此预留）：

```dart
// market_data_provider.dart:93
/// Replace with `HttpMarketDataProvider` when a quote vendor is configured.
```

---

## 12. 「疑似假功能清单」

| # | 文件:行 | 表现 | 原因 | 应该如何完成 | 严重度 |
| --- | --- | --- | --- | --- | --- |
| 1 | `market_data_provider.dart:95,245-256` + `investment_repository.dart:723-725` | 投资模块所有价格/涨跌/收益是**正弦波合成值** | 无真实行情源；`MockMarketDataProvider` 被注册为生产 provider | 实现 `HttpMarketDataProvider` 调用真实行情 API，替换 provider（架构已预留） | 🔴 **最高** |
| 2 | `market_data_provider.dart:280-468` | 30 条标的主数据 + 锚定价**硬编码在 Dart 源码** | 无服务端标的库 | 服务端 `investment_assets` 主数据 + 搜索接口 | 🔴 高 |
| 3 | `market_data_provider.dart:159-167` | 未知代码返回合成 ¥100 报价 | 为 Demo 体验兜底 | 返回 null / 明确"未找到" | 🟠 中 |
| 4 | `placement_repository.dart:213` | `userCreatedAt: DateTime(2020)` | 占位值 | 传真实账号/用户创建时间 | 🟡 低（且开屏不存在，规则本就无效） |
| 5 | `ad_provider.dart:11-30` + `placement_repository.dart:189-191` | 广告 provider 恒 `isAvailable=false` | 未接广告 SDK | 接激励视频 SDK（见 §7.4） | 🟠 中 |
| 6 | `placement_repository.dart:16-70` | 3 条广告位**硬编码 const** | 无远程配置 | 服务端 `ad_placements` 表 + `GET /ads/placements` | 🟠 中 |
| 7 | `placement_repository.dart:84-94` | `sessionId`/`metadataJson` **调用方从不传，恒 NULL** | 未实现会话与上下文 | 记录 session 与展示位置 | 🟡 低 |
| 8 | `investment_repository.dart:644-717` | `ApiInvestmentRepository` 全部 `UnimplementedError` | 服务端接口未开发 | 实现 `/investment/*` | 🟠 中 |
| 9 | `quote_cache.dart:107-137` | `RedisQuoteCache` 全部 `UnimplementedError` | 无 Redis | 多实例部署时接入 | 🟡 低 |
| 10 | `app_router.dart:3` (`placement.dart`) + `ad_provider.dart:7,28` + `placement_policy.dart:50-53` | `AdFormat.splash` / `PlacementSurface.splash` / 24小时规则 → **无 Splash 页面、无 `/splash` 路由** | 未实现 | 若采纳建议则删除（开屏不建议做） | 🟡 低 |
| 11 | `placement_repository.dart:153-170` | `RewardedAdService` 恒提前返回 | provider 恒 false | 同上 | 🟡 低 |
| 12 | `transaction_parser.dart:220-225` + `speech_recognition_service.dart:196-206` | `AiParsingGateway` **无实现**；`HybridTransactionParser` 构造时**未传 `ai:`** → `transaction_parser.dart:346-350` 的 `ai == null` 恒真 → **AI 语音解析永远不执行** | 未接 LLM 网关 | 实现 `AiParsingGateway` 并注入；或删除该死路径 | 🟠 中 |
| 13 | `assistant_ai.ts:28` + 无 `.env` | 服务端 DeepSeek 调用**无 API key** → 恒 503 | 未配置生产密钥 | 配置 `DEEPSEEK_API_KEY` | 🟠 中 |
| 14 | `assistant_engine.dart:64-77,82-93` | 助手对多数输入返回**硬编码字符串** | 本地规则引擎设计 | 已可用；仅在配置远程后可增强 | 🟡 低（有诚实披露） |
| 15 | `assistant_page.dart:98` | `'图片记账识别开发中，尚未上传或创建账单'` | OCR 未实现 | 实现 OCR 管线（`TransactionSource.ocr` / `EntitlementKey.ocr` 枚举已预留） | 🟠 中（**已诚实告知，非欺骗**） |
| 16 | `profile_page.dart:114` | `'当前版本尚未上线积分服务'` | 积分服务未做 | 排期或删除入口 | 🟡 低（诚实） |
| 17 | `profile_page.dart:347` | `'当前版本尚未接入在线反馈提交'` | 无反馈后端 | 接反馈接口 | 🟡 低（诚实） |
| 18 | `membership_page.dart:290` | `'正式会员服务协议详情尚未配置'` | 协议未法务定稿 | 补协议（**上架前必须**） | 🔴 高（合规） |
| 19 | `membership_page.dart:341` | `'以上为原型示例评价，当前版本没有可验证的更多评价数据'` | 无真实评价 | 删除或接真实评价 | 🟡 低（诚实） |
| 20 | `profile_page.dart:360` | `'版本 1.0.0+1'` **硬编码**，与 `pubspec.yaml:19` 重复 | 无 `package_info_plus` | 引入 package_info_plus | 🟡 低 |
| 21 | `payment.ts:192,251` + `pubspec.yaml:100-102` + `Info.plist:44` + `Runner.entitlements:7` + `payment_service.dart:93` | 支付商户配置全为 `YOUR_*` 占位 | 未申请商户号 | 发布前填入真实配置 | 🔴 高 |
| 22 | `ios/Runner/Info.plist:44` | `CFBundleURLSchemes` 含 `YOUR_WECHAT_APP_ID` | 同上 | **iOS 微信支付因此完全不可用** | 🔴 高 |
| 23 | `app_database.dart:519-635` | `families`/`family_members`/`family_invitations`/`family_operation_logs`/`family_budgets` **5 张死表** | 早期设计被 `books`+`sync_books` 取代，未清理 | 在下一个 schema 版本删除，或明确保留理由 | 🟠 中 |
| 24 | `server/src/app.ts:69` | `GET /auth/me` **前端从未调用** | 无 Profile 页 | 供 Profile 页使用 | 🟡 低 |
| 25 | `app.ts:115-118` | `GET /books/:id/logs` 未在 `lib/` 找到调用 | 审计日志页未做 | 做审计页或删除 | 🟡 低 |
| 26 | `app_router.dart:198-204` + `investment_overview_page.dart:118-120` | 路由 `holdings/:assetType/detail/:holdingId` 需要 4 段，但唯一 push 只给 3 段（`/profile/investments/holdings/detail/$holdingId`） → **`:holdingId` 永远无法绑定，`InvestmentDetailPage` 无法打开** | 路径拼接漏了 `:assetType` | 改为 `'/profile/investments/holdings/${type.name}/detail/$holdingId'` | 🟠 中（功能不可用） |
| 27 | `family_page.dart:529-535` | `getForUser('user-local')` 硬编码，登录后可能查不到刚加入的账本 | 调用点误用未参数化 | 传 `currentActor` / session user id | 🟠 中 |
| 28 | `android/app/build.gradle.kts:61-66` + 无 `android/key.properties` | release 构建**静默回退到 debug 签名** | 未提供正式 keystore | 配置 `android/key.properties` | 🔴 高（无法上架/无法升级） |
| 29 | `app_database.dart:704` + `:102` (`session_repository.dart`) | "用户"是字符串常量 `'user-local'`；登录只切 actor，**不迁移本地数据归属** | 共享账本定位的历史设计 | 实现"本地数据认领"（见 §6.3） | 🟠 中 |
| 30 | `membership_repository.dart:91-143` | 服务端下发的 `featurePolicies` **客户根本不解析**（构造 `MembershipSnapshot` 时未填该字段） → `membership.dart:221-224` 恒走 passthrough → **永远放行** | 半成品接线 | 解析 `featurePolicies` | 🟠 中 |
| 31 | `membership_upgrade_prompt.dart:15-28` | `ensureMembershipFeatureAvailable` **0 个生产调用点** | 未接线 | 在实际收费功能入口调用 | 🟠 中 |
| 32 | `assistant_policy.ts:73` vs `payment.ts:161` | 服务端会员门控读 `assistant_memberships`（仅管理员写入），**支付写的是 `membership_subscriptions`** → **付费用户解锁不了服务端会员功能** | 两套会员表未打通 | 统一读 `membership_subscriptions` | 🔴 高 |
| 33 | `membership_page.dart:360` + `:376` | 会员页头部 `_MemberHeader` 在 **320dp 小屏溢出 6.6px**（实测 RenderFlex 异常），内容被裁 | 头部高度预算 `height: 68 + (scale-1)*64` 小于内层 Column 实际需要的高度 | 提高高度预算或降低 `top` padding，见 §18 | 🔴 高（真实用户可见） |
| 34 | `membership_page_ui_test.dart` `test/widget_test.dart` | **测试套件跑不完**：单测试 10 分钟超时，阻塞其后所有测试 | 会员页存在永不停歇的动画/Timer，`pumpAndSettle` 永不静止 | 修动画或改用 `pump(Duration)` + 显式断言；设置单测试超时 | 🔴 高（阻塞一切回归） |
| 35 | `membership_page_ui_test.dart:62` | `type 'Text' is not a subtype of type 'RichText'` | 测试与 UI 实现的类型契约已漂移 | 同步测试与实现 | 🟠 中 |

**汇总**：无 TODO/FIXME/HACK 标记（0 命中），说明项目**不用注释搪塞**；未完成项都以 `尚未接入` 注释 + 用户可见的诚实文案标注。**但存在 1 处会让用户看到虚假财务数据的实现（#1 投资行情）和 1 处支付与权益脱节的实质缺陷（#32）。**

---

## 13. 缺失功能清单（按优先级）

### P0 —— 正式发布之前**必须**完成

| # | 事项 | 为什么必须 | 涉及范围 |
| --- | --- | --- | --- |
| **0** | **修复测试基线（255通过/6失败/套件跑不完）** | **这是所有其他开发的前置条件**：套件跑不完就无法判断任何改动是否引入回归；且其中 1 项是真实用户可见的 320dp 布局溢出 | `membership_page.dart:360`、会员页动画、2 个测试文件的契约、单测试超时配置 |
| 1 | **隐私政策 + 用户协议 + 首次同意门** | 应用商店**硬性**审核要求；当前 0 实现 | 新页面 + 首次启动拦截 + 应用商店后台 |
| 2 | **Crash Reporting** | 没有它 = 线上崩溃完全不可知，无法运维 | 引入 Sentry 或 Crashlytics |
| 3 | **投资行情真实化 或 明确下架** | 当前向用户展示**编造的价格与收益**，是产品诚信与合规风险 | `market_data_provider.dart` + 一个 provider |
| 4 | **Android 正式 keystore** | 无 `key.properties` 时 release 静默用 debug 签名 → **无法上架、无法升级** | `android/key.properties` + CI |
| 5 | **`SHARED_API_BASE_URL` 生产配置** | 默认 `127.0.0.1:8787`，不配置则商店包会员/AI/共享全部失效 | 构建脚本 |
| 6 | **后端公网部署（HTTPS + 域名 + TLS）** | 客户端强制 HTTPS；支付回调也要求公网 HTTPS | 部署 + 证书 + 域名 |
| 7 | **支付商户配置 + 真实联调** | `YOUR_*` 占位；iOS 微信 scheme 也是占位 → **iOS 微信支付完全不可用** | 微信/支付宝开放平台 + 沙箱验证 |
| 8 | **账号注销 + 用户数据删除** | 《个人信息保护法》要求；商店审核必查 | 服务端 `DELETE /users/me` + 客户端清库 |
| 9 | **统一 API 错误处理 + 401 自动登出** | 会话中 401 目前只抛异常，用户卡在死状态 | `shared_api.dart` 统一拦截 |
| 10 | **会员权益强制接线**（客户端 + 服务端统一读 `membership_subscriptions`） | 当前付费用户解锁不了服务端功能 = 收钱不办事 | §12 #30/#31/#32 |
| 11 | **APP 版本更新检查** | 无此能力则出问题无法强制升级 | 服务端 1 表 1 接口 + 客户端 1 次请求 |
| 12 | **服务端日志与监控** | `logger:false`，线上故障无迹可查 | pino + 日志采集 |
| 13 | **修复投资详情路由 bug** | 页面永远打不开 | 1 行路径拼接 |

### P1 —— 上线第一版建议完成

| # | 事项 | 价值 |
| --- | --- | --- |
| 1 | **用户行为统计（最小埋点）** | 没有数据无法做任何产品决策；见 §8.3 |
| 2 | **激励视频广告（唯一推荐形式）** | 变现且不伤体验；骨架已存在，只需接 SDK + 远程配置 |
| 3 | **Remote Config / Feature Flag** | 出问题可远程关闭功能，避免重新发版 |
| 4 | **推送（Push）** | 周期账单提醒、会员到期、运营触达 |
| 5 | **本地数据库加密（SQLCipher）** | 财务数据明文落盘，中低端机 root 后可读 |
| 6 | **账号体系补全**（独立账户页、微信登录、设备管理、Refresh Token） | 降低登录摩擦，减少 30 天掉登录 |
| 7 | **列表分页与 SQL 聚合** | 当前全量内存计算，数据量大后卡顿 |
| 8 | **附件云备份** | 当前备份不含附件文件 |
| 9 | **数据清空入口** | 用户预期能力 |
| 10 | **iOS 可编译与真机验收** | 当前 `flutter build ios` 被配置问题阻断 |

### P2 —— 上线之后逐步增加

- 运营后台（广告/公告/活动可视化配置）
- 复杂广告策略（频次分层、A/B）
- 实验系统（A/B test 框架）
- 企业报税
- 附件对象存储 + CDN
- 多币种汇率

### P3 —— 暂时**不要**做

- ❌ 微服务拆分（当前 1,127 行服务端，拆了纯属自残）
- ❌ 复杂推荐系统
- ❌ 数据仓库 / OLAP
- ❌ 自建广告投放平台
- ❌ 自建崩溃收集服务（直接用 Sentry）
- ❌ 开屏广告 / 插屏广告（见 §7.4 —— 对高频记账工具体验伤害过大）
- ❌ 自建 Push 通道（直接接厂商通道或极光/个推）

---

## 14. 产品全景图

```
                              好好记账 APP
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
     【本地核心 · 95%】        【联网能力 · 条件开启】      【原生能力 · Android】
        │                          │                          │
   ┌────┴────┐              ┌──────┴──────┐            ┌──────┴──────┐
   │         │              │             │            │             │
 用户身份   记账引擎        共享账本      商业化        无障碍读屏    系统调度
   │         │              │             │            │             │
 user-local  流水           Auth        会员catalog   微信支付解析   AlarmManager
 （字符串）  分类           Books       订单/订阅     悬浮窗确认     周期账单补齐
            账户           成员/邀请     微信/支付宝   通知监听       开机重排
            预算           快照/游标     验签回调      (支付宝/云闪付
            目标           幂等mutation  AI助手策略     捕获)
            周期账单       冲突检测      DeepSeek转发
            分期                           │
            报销/退款              ┌───────┴────────┐
            投资(假行情) ⚠️         │                │
            智能(规则)          本地规则引擎      远程LLM
            收件箱                               (无key→503)
            附件
            备份/恢复
        │
        │  Drift / SQLite (26 表)  +  6 张 sync_* 表
        ▼
   ┌─────────────────────────────────────────────────────┐
   │              本地数据层（无加密）                     │
   │  accounts / categories / transactions / goals /     │
   │  budgets / recurring_bills / installment_plans /    │
   │  investment_* / merchant_rules / inbox_items /      │
   │  ad_events / sync_outbox  ←SQL触发器→  sync_books   │
   │                                                     │
   │  ⚠️ 5 张死表: families / family_members /           │
   │     family_invitations / family_operation_logs /    │
   │     family_budgets                                  │
   └──────────────────────┬──────────────────────────────┘
                          │  HTTPS（强制）+ Bearer Token
                          │  编译期开关 SHARED_API_BASE_URL
                          ▼
   ┌─────────────────────────────────────────────────────┐
   │   Node 22 + Fastify 5 + better-sqlite3 + Zod        │
   │   server/src（1,127 行，logger:false）               │
   │                                                     │
   │  Auth(users/sessions)  共享账本(books/members/       │
   │  entities/changes/operations/invitations)           │
   │  Membership(membership_catalog)                     │
   │  Payment(membership_orders/subscriptions)           │
   │  Assistant(assistant_policy/memberships/usage/…)    │
   │  Health                                             │
   │                                                     │
   │  🔴 不存在: Investment / Analytics / Ads /          │
   │     AppVersion / Notification / File / Redis /      │
   │     Queue / Cron                                    │
   └──────────────────────┬──────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
   微信支付APIv3      支付宝开放平台      DeepSeek API
   (未配置商户)       (未配置商户)       (无 API Key)
        │                 │                 │
   RSA-SHA256验签     RSA2验签        OpenAI兼容
   AES-GCM解密       金额/appid校验    /chat/completions
        │
   🔴 缺失的第三方:
      广告SDK(穿山甲/优量汇/AdMob) · 崩溃上报(Sentry/Crashlytics)
      Push(FCM/极光) · 行情数据源 · 对象存储 · 短信
```

---

## 15. 功能完成度矩阵

> 百分比按**实际代码可运行程度**估算，不为了好看给高分。

| 系统 | 功能 | 前端 | 后端 | DB | 第三方 | 完成度 |
| --- | --- | --- | --- | --- | --- | --- |
| 记账 | 手动记账（含转账/债务/计算器） | ✅ | — | ✅ | — | **95%** |
| 记账 | 编辑/软删除/余额联动 | ✅ | — | ✅ | — | **95%** |
| 记账 | 附件管理 | ✅ | 🔴 | ✅ | file_picker | **70%**（不含云备份） |
| 记账 | 语音记账（识别+规则解析） | ✅ | — | — | speech_to_text | **80%** |
| 记账 | 语音 AI 兜底 | 🔴 | 🟣 | — | 🔴 | **10%**（接口空实现） |
| 记账 | 图片/OCR 记账 | 🔴 | 🔴 | ⚠枚举 | 🔴 | **5%** |
| 记账 | 自动记账（Android/微信） | ✅ | — | ✅ | 无障碍+悬浮窗 | **65%**（仅微信、易被改版打破） |
| 记账 | 自动记账（Alipay/云闪付） | 🟠 | — | ✅ | 通知监听 | **35%**（下游链路未验证） |
| 记账 | 自动记账（iOS） | 🔴 | — | — | — | **0%** |
| 账本 | 多账本/归档/书架UI | ✅ | — | ✅ | — | **90%** |
| 账本 | 共享账本同步 | ✅ | ✅ | ✅ | — | **85%**（本地双端联调通过，未公网验收） |
| 账本 | 共享默认账户余额联动 | ✅ | ✅ | ✅ | — | **85%** |
| 资产 | 账户管理/校准/排序 | ✅ | — | ✅ | — | **90%** |
| 资产 | 资产总览/趋势/资金形式 | ✅ | — | ✅ | — | **85%** |
| 投资 | 持仓/交易记录 | ✅ | 🔴 | ✅ | — | **70%** |
| 投资 | 行情/市值/涨跌/收益 | 🔴 | 🔴 | ✅ | 🔴 | **0%**（假数据） |
| 预算 | 月/分类预算/使用率/今日可花 | ✅ | — | ✅ | — | **85%** |
| 目标 | 目标/节点/贡献/预测/庆祝 | ✅ | — | ✅ | — | **90%** |
| 分析 | 趋势/分类/习惯/热力图/洞察 | ✅ | — | ✅ | — | **85%** |
| 分析 | 消费日历（跨账本） | ✅ | — | ✅ | — | **85%** |
| 分析 | 搜索 | ✅ | — | ✅ | — | **80%** |
| 费用 | 周期账单（含后台补齐+提醒） | ✅ | — | ✅ | AlarmManager | **85%** |
| 费用 | 信用卡分期 | ✅ | — | ✅ | — | **80%** |
| 费用 | 报销/退款 | ✅ | ✅ | ✅ | — | **85%** |
| 智能 | 商户记忆/去重/收件箱 | ✅ | — | ✅ | — | **75%**（规则，非ML） |
| 智能 | AI 助手 | 🟠 | 🟣 | ✅ | DeepSeek(无key) | **25%** |
| 用户 | 注册/登录/登出 | 🟡 | ✅ | — | — | **50%**（为共享账本服务） |
| 用户 | 游客模式 | 🟠 | — | ✅ | — | **40%**（隐式） |
| 用户 | 游客转正 | 🔴 | 🔴 | ⚠ | — | **5%** |
| 用户 | 手机号/短信/邮箱/第三方登录 | 🔴 | 🔴 | — | 🔴 | **0%** |
| 用户 | 找回/修改密码 | 🔴 | 🔴 | — | — | **0%** |
| 用户 | 账号注销/数据删除 | 🔴 | 🔴 | — | — | **0%** |
| 用户 | Profile（头像/昵称） | 🔴 | 🟣 | — | — | **5%** |
| 用户 | Token 体系（Access） | ✅ | ✅ | ✅ | — | **70%** |
| 用户 | Refresh Token/刷新 | 🔴 | 🔴 | 🔴 | — | **0%** |
| 用户 | 401 自动登出 | 🔴 | ✅ | — | — | **20%** |
| 用户 | 设备管理/多设备 | 🔴 | 🟠 | ✅ | — | **15%** |
| 商业化 | 会员套餐/权益展示 | ✅ | ✅ | ✅ | — | **80%** |
| 商业化 | 会员支付（微信/支付宝） | ✅ | ✅ | ✅ | 未配置 | **70%**（代码真实，未联调） |
| 商业化 | 支付回调验签 | — | ✅ | ✅ | — | **95%** |
| 商业化 | 退款 | 🔴 | 🔴 | ⚠枚举 | 🔴 | **0%** |
| 商业化 | 权益强制执行 | 🔴 | 🟠读错表 | — | — | **15%** |
| 商业化 | 广告 SDK 接入 | 🔴 | 🔴 | — | 🔴 | **0%** |
| 商业化 | 广告位骨架/策略/事件 | 🟡 | 🔴 | ✅ | — | **25%** |
| 商业化 | 远程广告配置 | 🔴 | 🔴 | 🔴 | — | **0%** |
| 商业化 | 会员去广告 | ✅ | ✅ | — | — | **70%**（逻辑通，但无广告可去） |
| 运营 | 用户统计/埋点 | 🔴 | 🔴 | 🔴 | 🔴 | **0%** |
| 运营 | 崩溃上报 | 🔴 | 🔴 | 🔴 | 🔴 | **0%** |
| 运营 | Remote Config | 🟠 | 🟠 | ✅ | — | **30%**（仅会员catalog） |
| 运营 | 公告/活动 | 🔴 | 🔴 | 🔴 | — | **0%** |
| APP | 版本更新 | 🔴 | 🔴 | 🔴 | — | **0%** |
| APP | 强制更新/最低版本 | 🔴 | 🔴 | 🔴 | — | **0%** |
| APP | 维护模式 | 🔴 | 🔴 | 🔴 | — | **0%** |
| APP | Push 推送 | 🔴 | 🔴 | 🔴 | 🔴 | **0%** |
| APP | 本地通知（周期账单/自动记账） | ✅ | — | — | 原生 | **80%** |
| 数据 | Migration（v1→v18） | ✅ | ✅ | ✅ | — | **90%** |
| 数据 | 本地备份/恢复 | ✅ | — | ✅ | — | **85%**（不含附件、无加密） |
| 数据 | CSV 导出 | ✅ | — | ✅ | file_picker | **90%** |
| 数据 | 云同步（个人数据） | 🔴 | 🔴 | — | — | **0%** |
| 数据 | 本地库加密 | 🔴 | — | 🔴 | 🔴 | **0%** |
| 数据 | 附件云存储 | 🔴 | 🔴 | 🔴 | 🔴 | **0%** |
| 隐私 | 隐私政策/用户协议 | 🔴 | 🔴 | — | — | **0%** |
| 隐私 | 权限说明/隐私授权 | 🔴 | — | — | — | **0%** |
| 安全 | HTTPS 强制 | ✅ | 🟠 | — | — | **70%**（代码就绪，未部署TLS） |
| 安全 | Token 安全存储 | ✅ | ✅ | ✅ | — | **85%** |
| 安全 | 接口鉴权 | ✅ | ✅ | ✅ | — | **85%** |
| 安全 | Rate Limit/防重放 | — | ✅ | ✅ | — | **85%** |
| 安全 | 支付安全（验签） | — | ✅ | ✅ | 未配置 | **80%** |

---

## 16. 《当前项目状态报告》

### A. 已经完成的主要系统（可放心依赖）

1. **本地记账核心** —— 手动记账、编辑、软删除、余额事务联动、转账、债务、计算器输入。质量高，测试覆盖好。
2. **账户与资产管理** —— 账户 CRUD/归档/排序/校准、资产总览、资产负债、资金形式、趋势图。
3. **预算 / 目标** —— 完整的预算体系（月/分类/使用率/今日可花）；完整的目标体系（节点/贡献/预测/庆祝）。
4. **收支分析** —— 现金流、分类构成、消费习惯、热力图、大额检测、本地洞察、基线对比。
5. **消费日历 / 搜索 / 交易详情** —— 含跨账本日历、附件预览（图片缩放/PDF 打开）。
6. **周期账单 / 信用卡分期** —— 含 Android 后台幂等补齐 + 提醒通知。
7. **报销 / 退款** —— 关联原流水、服务端金额校验、状态自动流转、编辑保护。
8. **智能能力（规则型）** —— 商户记忆、指纹去重、账单收件箱、经济事件关联。真实持久化。
9. **语音记账（识别 + 规则解析）** —— 设备真实识别（on-device 优先），中文正则解析，多笔拆分。
10. **自动记账（Android / 微信）** —— 无障碍读屏 + 悬浮确认 + 后台 Engine + 幂等落库，**不静默写入**。
11. **共享账本协作** —— 快照/游标/幂等 mutation/乐观锁冲突/角色权限/SQL层ACL。服务端 10/10 测试通过。
12. **本地数据安全基础** —— v1→v18 migration（含自动备份）、软删除、外键、13+索引、后台 isolate 连接、完整 SQLite 备份/恢复。
13. **支付服务端协议** —— 微信 APIv3 签名下单、AES-256-GCM 回调解密、支付宝 RSA2 验签、金额/appid/序列号/时间窗校验。**代码质量高，无"回调即置成功"旁路。**
14. **Android 原生能力** —— 权限声明精准无冗余、`allowBackup=false`、禁明文流量、免精确闹钟权限。

### B. 当前半成品系统

| 系统 | 完成的部分 | 缺的部分 |
| --- | --- | --- |
| 用户/账户 | 注册/登录/登出/Token/安全存储 | 手机号、短信、第三方登录、注销、找回密码、Refresh Token、Profile、设备管理、游客转正 |
| 会员体系 | catalog/订单/支付/回调/权益数据 | 权益强制接线（客户端 0 调用点 + 服务端读错表）、family 档位服务端不返回 |
| 支付 | 完整协议与验签 | 商户配置、真实联调、退款、查单对账 |
| 广告 | 位/策略/事件/频控骨架 + 1 张内部推广卡 | 真实 SDK、远程配置、事件上报、开屏/激励 |
| AI 助手 | 本地规则引擎 + 服务端策略/配额/限流/幂等 + DeepSeek 转发代码 | API Key、`AiParsingGateway` 实现、图片 OCR |
| 自动记账 | Android 微信完整链路 | iOS、支付宝/云闪付下游、更多支付场景 |
| 云同步 | 共享账本完整同步 | 个人数据云备份、附件同步 |
| 设置 | 我的页内弹窗 | 独立设置页、隐私/权限说明 |
| iOS | 配置与权限声明基本就位 | 可编译、真机验收、微信 scheme、签名 |

### C. 当前完全缺失系统

1. **APP 版本更新 / 强制更新 / 维护模式 / 最低版本限制** —— 0 实现
2. **用户行为统计 / 埋点 / 漏斗 / 留存** —— 0 实现
3. **崩溃上报 / 异常上传 / APM** —— 0 实现（连 `FlutterError.onError` 都没有）
4. **隐私政策 / 用户协议 / 隐私授权 / 第三方 SDK 清单** —— 0 实现
5. **账号注销 / 用户数据删除** —— 0 实现
6. **任何广告 SDK / 远程广告配置 / 广告收入统计** —— 0 实现
7. **Push 推送**（无任何 push SDK）—— 0 实现
8. **Remote Config / Feature Flag / 公告 / 活动配置** —— 0 实现（仅会员 catalog 可远程）
9. **本地数据库加密** —— 0 实现
10. **附件云存储 / 个人数据云同步** —— 0 实现
11. **服务端投资 / 统计 / 广告 / 版本 / 通知 / 文件模块** —— 0 实现
12. **服务端日志 / 监控 / Redis / Queue / Cron** —— 0 实现
13. **退款 / 主动查单对账** —— 0 实现

### D. 前端存在但后端缺失

| 前端 | 后端 | 影响 |
| --- | --- | --- |
| 投资管理全套 UI + 4 张表 | 🔴 无 `/investment/*`；`ApiInvestmentRepository` 全 `_unimplemented()` | 只能用本地假行情 |
| `ad_events` 事件写入 | 🔴 服务端 0 引用 | 事件永不外发 |
| 广告位配置（const） | 🔴 无 `/ads/placements` | 无法远程调控 |
| `GET /auth/me` 消费者 | ✅ 端点在，但前端不调 | Profile 页缺失 |
| 离线反馈入口 | 🔴 无反馈端点 | 文案明示"尚未接入" |
| 积分服务 | 🔴 无 | 文案明示"尚未上线" |
| 图片/OCR 记账 | 🔴 无 | 文案明示"识别开发中" |
| 附件文件云备份 | 🔴 无 | 备份不含附件 |

### E. 后端存在但前端未接入

| 后端 | 前端 | 影响 |
| --- | --- | --- |
| `GET /api/v1/auth/me` | 🔴 从未调用 | Profile 能力闲置 |
| `GET /api/v1/books/:id/logs` | ❓ 未在 lib/ 找到调用 | 审计日志能力闲置 |
| `PUT /api/v1/admin/membership/catalog` | N/A 运营接口 | 有 Admin Token 保护，正常 |
| `PUT /api/v1/admin/assistant/*` | N/A 运营接口 | 同上 |
| `GET /api/v1/membership/catalog` 的 `featurePolicies` 字段 | 🔴 客户端不解析 | 权益策略形同虚设 |
| `assistant_memberships`（管理员授予） | ⚠️ 与支付表不通 | **付费用户无法解锁** |
| `GET /health` | 🔴 未调用 | 可用于更新检查/维护模式 |

### F. 数据库存在但未使用

| 表 | 证据 | 建议 |
| --- | --- | --- |
| `families` | `familyEntries` 在 lib/ 中 0 引用 | 下个 schema 版本删除 |
| `family_members` | `familyMemberEntries` 0 引用 | 同上 |
| `family_invitations` | `familyInvitationEntries` 0 引用 | 同上 |
| `family_operation_logs` | `familyOperationLogEntries` 0 引用 | 同上 |
| `family_budgets` | `familyBudgetEntries` 0 引用 | 同上 |
| `sync_promotions` | 未找到读写调用 | ❓ 需确认是否有迁移用途 |
| `transaction_attachments.sizeInBytes` / `checksum` | 字段声明但未见赋值 | 预留字段，可接受 |
| `transactions.metadataJson` | 附件已迁出，仅存 tags | 保留兼容 |

`FamilyDao`（`app_database.dart:2053-2115`）在 `@DriftAccessor(tables:[...])` 中声明了这 5 张死表，但**所有方法只操作 `bookEntries`**。

### G. 当前明显技术债务

0. **测试基线不绿且套件跑不完** —— 实测 255 通过 / 6 失败 / 单测试 10 分钟超时阻塞其后所有测试；其中含 1 个真实用户可见的 320dp 会员页布局溢出（`membership_page.dart:360`）。`CURRENT_STATUS.md` 的"230 个测试全部通过"已失效。**这是最高优先级的技术债**，因为它使所有回归验证失效。
1. **全量内存计算** —— `transactions_repository.dart:272-302` 每次映射都全量加载 categories；`quick_bookkeeping_service.dart:177` 用 `getAll()` 找关联流水。数据量增长后必然卡顿。
2. **单文件过大** —— `app_database.dart` 70,645 字节（含 DAO）、`book_selector.dart` 2,232 行、`quick_add_sheet.dart` 2,192 行。维护成本高。
3. **`_mapEntity` 全表扫描分类** —— `transactions_repository.dart:292-302` 循环遍历所有分类而非按 ID 查。
4. **5 张死表 + 死 DAO 声明** —— 见 F。
5. **投资模块假数据** —— 见 §12 #1。
6. **权益系统三处脱节** —— 客户端无调用点、不解析 featurePolicies、服务端读错表。
7. **`DateTime(2020)` 硬编码** —— 使新用户广告宽限规则失效。
8. **版本号重复硬编码** —— `profile_page.dart:360` vs `pubspec.yaml:19`。
9. **投资详情路由参数不匹配** —— 页面无法打开。
10. **`family_page.dart:532` 硬编码 `'user-local'`** —— 登录后可能查不到账本。
11. **无统一错误码** —— 服务端返回中文 message，无业务错误码枚举，客户端难以做精细处理。
12. **`flutter analyze` 有 2 个 warning** —— 测试文件未使用 import（`test/investment_flow_test.dart:10`、`test/investment_repository_test.dart:8`）。
13. **`speech_to_text` KGP 兼容性 warning** —— 构建仍报，需等插件迁移。
14. **无 iOS 可编译状态** —— `flutter build ios --no-codesign` 被配置问题阻断。

### H. 正式发布前必须解决的问题（P0）

0. 🔴 **修复测试基线** —— 套件跑不完 = 无法可信回归；含 1 个真实用户可见的 320dp 会员页布局溢出
1. 🔴 **隐私政策 + 用户协议 + 首次同意门**（商店硬性要求，当前 0 实现）
2. 🔴 **投资行情真实化，或从首版下架该模块**（当前展示编造价格）
3. 🔴 **Crash Reporting**（否则线上崩溃不可知）
4. 🔴 **Android 正式 keystore**（当前 release 用 debug 签名，无法上架/升级）
5. 🔴 **`--dart-define=SHARED_API_BASE_URL=https://...`**（否则商店包云端能力全废）
6. 🔴 **后端公网部署（HTTPS 域名 + TLS）**（客户端强制 HTTPS，支付回调也要求）
7. 🔴 **支付商户配置 + 真实联调**（含 iOS 微信 scheme 占位修复）
8. 🔴 **账号注销 + 用户数据删除**（个保法要求）
9. 🔴 **401 统一处理 + API 错误处理收敛**
10. 🔴 **会员权益强制接线**（客户端 + 服务端统一读 `membership_subscriptions`）
11. 🔴 **APP 版本更新检查**（无此能力无法强制升级）
12. 🔴 **服务端日志与监控**（`logger:false`）
13. 🔴 **修复投资详情路由 bug**（1 行）
14. 🔴 **iOS 可编译 + 真机验收**

### I. 发布后再考虑的问题（P2/P3）

- 用户行为统计与留存分析（P1 其实就应做）
- 激励视频广告（P1）
- Remote Config / Feature Flag（P1）
- Push 推送（P1）
- 本地库加密（P1）
- 账号体系补全（微信登录/设备管理/Refresh Token）（P1）
- 分页与 SQL 聚合优化（P1）
- 运营后台、A/B 实验、企业报税、多币种汇率（P2）
- 微服务、推荐系统、数据仓库、自建广告平台（P3，**不要做**）

---

## 17. 《接下来开发顺序》

### Phase 1 —— 让 App「能安全上架」（P0，不发新功能）

**做什么**
0. **先把测试基线修绿**：修 `membership_page.dart:360` 会员页头部 320dp 溢出；修会员页永不停歇动画/`pumpAndSettle` 超时；同步 `membership_page_ui_test.dart:62` 的 `Text`/`RichText` 契约；为单测试设置合理超时；重跑取得全绿基线并更新 `CURRENT_STATUS.md`
1. 隐私政策 + 用户协议静态页 + 首次启动同意门 + 第三方 SDK 清单页
2. 引入 Sentry（或 Crashlytics）上报崩溃
3. 投资行情真实化：实现 `HttpMarketDataProvider` 接真实行情源；**若来不及，首版直接隐藏投资入口**（比展示假数据好）
4. Android 正式 keystore + 构建脚本支持 `--dart-define`
5. 后端公网部署：HTTPS + 域名 + TLS + 日志（pino）+ 数据库备份
6. 支付商户配置 + 微信/支付宝沙箱或小额真实订单全链路验证（下单→回调→查单）
7. 账号注销 + 数据删除（服务端 `DELETE /users/me` + 客户端清库）
8. `shared_api.dart` 统一 401 拦截 → 自动登出；统一错误码
9. 会员权益接线：客户端解析 `featurePolicies` 并在真实入口调用 `ensureMembershipFeatureAvailable`；服务端 `assistant_policy.ts:73` 改读 `membership_subscriptions`
10. APP 版本更新：服务端 `app_versions` 表 + `GET /app/version`；客户端 `package_info_plus` + 启动检查 + Android 下载/iOS 跳商店
11. 修复 §12 中的低风险 bug：#26 投资详情路由、#27 `getForUser('user-local')`、#4 `DateTime(2020)`、#20 版本号硬编码

**为什么做** —— 这 11 项里任何一项缺失都会直接导致：无法通过商店审核、或上线后无法运维、或用户看到假数据/付了钱没权益。

**涉及页面** —— 新增：隐私政策页、用户协议页、同意门、强制/普通更新弹窗；修改：会员页、家庭页、我的页、投资总览页。

**涉及 API** —— 新增 `GET /app/version`、`DELETE /users/me`、`GET /auth/sessions`、`DELETE /auth/sessions/:id`；修改 `assistant_policy` 会员判定。

**涉及数据库** —— 新增 `app_versions`；清理 5 张死表（可选）。

**是否需要第三方** —— 需要：Sentry/Crashlytics、行情数据源、微信/支付宝商户、HTTPS 证书。**这是本项目第一次真正引入第三方依赖，需要申请周期，应立刻启动。**

**会不会影响现有功能** —— 低风险。除"会员权益接线"和"401 拦截"会改变行为（属修复）外，其余都是新增。建议按"先加后切"方式：新逻辑加开关，验证后再启用。

---

### Phase 2 —— 让 App「可运营」（P1）

**做什么**
1. 用户行为统计最小闭环（见 §8.3，12 个白名单事件 + 服务端 `analytics_events`）
2. Remote Config / Feature Flag（服务端配置表 + 启动拉取 + 本地缓存）
3. Push 推送（厂商通道或极光/个推）+ 周期账单/会员到期触达
4. 激励视频广告（只做这一种形式）+ 远程广告位配置 + 事件上报
5. 本地数据库加密（SQLCipher）
6. 账号体系补全：独立账户页、微信登录、设备管理、Refresh Token
7. 性能优化：流水/分析分页与 SQL 聚合，消除 `getAll()` 全量加载
8. 附件云备份 + 数据清空入口
9. iOS 完整验收与发布

**为什么做** —— 没有统计就是盲飞；没有 Remote Config 出问题只能发版；广告和 Push 是商业化与留存的基础设施。

**涉及页面** —— 新增：账户页、Feature Flag 无 UI；修改：会员页（广告权益）、周期账单页、我的页。

**涉及 API** —— 新增 `POST /analytics/events`、`GET /config`、`GET /ads/placements`、`POST /ads/events`、`POST /auth/refresh`、`GET /auth/sessions`。

**涉及数据库** —— 新增 `analytics_events`、`remote_config`、`ad_placements`、`push_tokens`；客户端 `analytics_events` 本地队列。

**是否需要第三方** —— 需要：统计（可自建）、Push 服务商、广告 SDK（穿山甲/优量汇/AdMob）、短信（若做找回密码）。

**会不会影响现有功能** —— 中等。数据库加密会改变数据库打开方式（需处理迁移，**必须先备份后启用**）；性能优化会改查询路径（需要回归测试保障）。

---

### Phase 3 —— 让 App「更完整」（P2）

- 运营后台（广告/公告/活动可视化配置）
- 公告与活动配置
- A/B 实验框架
- 企业报税
- 附件对象存储 + CDN
- 多币种汇率
- 投资模块增强（真实持仓同步、分红/利息自动入账）
- 报销/分期/周期的更细粒度报表

---

### Phase 4 —— 规模化的能力（仅在用户量支撑时）

- 服务端拆分与读写分离
- 行情/统计的预计算与缓存（接入 Redis，替换 `RedisQuoteCache`）
- 数据仓库 / OLAP（用于复杂留存与漏斗分析）
- 灰度发布系统
- 智能能力升级（本地模型或云端 NLU）

**明确不做**：微服务拆分（1,127 行服务端）、复杂推荐系统、自建广告投放平台、开屏/插屏广告。

---

## 18. 本轮验证记录（可复现）

```bash
# 客户端静态分析
flutter analyze --no-pub
→ 2 issues found (ran in 7.3s)
  warning • Unused import: 'package:jizhang_app/features/investments/domain/investment_holding.dart'
            • test/investment_flow_test.dart:10:8
  warning • Unused import: (同上) • test/investment_repository_test.dart:8:8

# 服务端类型检查
cd server && npm run typecheck    # tsc --noEmit
→ 通过，无输出

# 服务端测试
cd server && npm test
→ # tests 10 / # pass 10 / # fail 0
  含：真实 HTTP 两客户端（重试、冲突、权限、隔离）、
      批量原子性、校准版本、负余额、邀请过期、共享额度、
      服务端拒绝已删除原流水继续被关联

# 客户端测试
flutter test
→ 见下方说明
```

**关于 `flutter test`（已实测，这是一个独立的 P0 级发现）**

命令：`flutter test --reporter expanded --concurrency=1`

实测结果是**基线不绿，且测试套件无法跑完**：

```
13:57 +255 -6: /Users/algive/jizhang_01/test/membership_page_ui_test.dart:
                membership page stays usable at Size(320.0, 700.0) and scale 1.6 [E]
  TimeoutException after 0:10:00.000000: Test timed out after 10 minutes.
```

| 指标 | 实测值 |
| --- | --- |
| 已执行通过 | **255** |
| 已执行失败 | **6** |
| 套件是否跑完 | ❌ **未跑完** —— 卡在 `membership_page_ui_test.dart`，该测试 **10 分钟超时**，后续测试被阻塞 |
| 整个命令耗时 | 14 分钟仍未结束（被手动终止） |

**这在实际上推翻了 `docs/development/CURRENT_STATUS.md` 中「230 个测试全部通过」的结论**（该记录为 2026-09-14，而 `test/` 现已有 83 个文件并新增了投资、分期、自动记账、响应式等测试，其中包含真实失败）。

### 失败 1（真实 UI 缺陷，非测试问题）：会员页头部在 320dp 溢出

```
A RenderFlex overflowed by 6.6 pixels on the bottom.
The relevant error-causing widget was:
  Column  Column:file:///Users/algive/jizhang_01/lib/features/membership/presentation/membership_page.dart:376:22
constraints: BoxConstraints(0.0<=w<=320.0, 0.0<=h<=58.4)
creator: Column ← Padding ← Align ← Stack ← SizedBox ← _MemberHeader ← Column ← Stack ← ...
```

**根因（已定位到具体表达式）**：

```dart
// lib/features/membership/presentation/membership_page.dart:360
height: 68 + (scale - 1) * 64,     // scale=1.0 → 高度 68

// :374-376
Align(
  alignment: Alignment.topCenter,
  child: Padding(
    padding: EdgeInsets.only(top: scale > 1.2 ? 48 : 13),   // scale=1.0 → top: 13
    child: Column(                                          // ← 溢出的就是这里
```

**溢出计算**：外层 `Stack` 位于 `SizedBox(height: 68)` 内且被裁剪，实际可用高度 58.4；
`Padding(top: 13)` 吃掉 13 → 剩 45.4；
`Column` 内容 = 「开通会员」(fontSize 20, `height: 1.1` → 约 22) + `SizedBox(5)` + 「更多权益 · 让记账更简单」(fontSize 11 → 约 13) = **约 40–45**，在 320dp 窄屏字体度量下超出可用空间 → **溢出 6.6px**。

**触发条件**：屏幕宽度 320dp（小屏手机）+ 文本 scale 1.0。这是**真实用户可见的布局缺陷**（黄黑条纹 / 内容被裁），不是测试环境的假象。

**可能的最小修复**（不改变设计意图）：
- 将 `height: 68` 提高到约 `76`（或改为 `68 + (scale - 1) * 64` 之上再给 `scale == 1.0` 一个下限）；
- 或把 `top: 13` 降到 ~8；
- 或给该 `Column` 包 `FittedBox`/`ClipRect`。

**连带影响**：`test/home_header_cards_test.dart:118` 的 `header cards interaction and layout at 320.0` 因此失败（RenderFlex 异常 + `pumpAndSettle timed out`），即**同一个真实缺陷导致 2 个测试失败**。

### 失败 2（测试自身挂起，阻塞整个套件）：`pumpAndSettle` 永不静止

```
pumpAndSettle timed out
#1  TestAsyncUtils.guard.<anonymous closure>
#2  main.<anonymous closure> (test/home_header_cards_test.dart:118:7)
...
TimeoutException after 0:10:00.000000: Test timed out after 10 minutes.   ← membership_page_ui_test.dart
```

`docs/development/CURRENT_STATUS.md`（2026-09-14）已自述：
> "2026-09-13 未完成：… 会员页存在既有的 `pumpAndSettle` 超时失败（与本轮无关）。"

→ **该问题未修复，且已从"一个测试失败"恶化成"整个测试套件无法跑完"**（单测试 10 分钟超时）。
通常根因是会员页存在**永不停止的动画/周期性 Timer**（`membership_visuals.dart` 用了 `math.Random().nextInt` 生成幂等键、页内有渐变/动效），使 `pumpAndSettle` 永远等不到静止帧。

### 失败 3（测试与实现契约不匹配）

```
type 'Text' is not a subtype of type 'RichText' in type cast
#0  WidgetController.widget (package:flutter_test/src/controller.dart:828:44)
#1  main.<anonymous closure> (test/membership_page_ui_test.dart:62:38)
```
测试按类型取 `RichText`，实现返回 `Text` → **测试与 UI 实现的契约已漂移**，需同步二者。

### 失败清单（实测）

| 测试文件:行 | 测试名 | 失败原因 |
| --- | --- | --- |
| `test/home_header_cards_test.dart:118` | header cards interaction and layout at 320.0 | RenderFlex 溢出 6.6px（会员页头部）+ pumpAndSettle 超时 |
| `test/widget_test.dart:400` | membership navigation closes the ledger drawer | 期望失败 |
| `test/widget_test.dart:422` | quick add and membership share the same back-button target | pumpAndSettle 超时 |
| `test/widget_test.dart:524` | opens account, category and budget management pages | pumpAndSettle 超时 |
| `test/membership_page_ui_test.dart:62` | membership page stays usable at Size(320.0, 700.0) and scale 1.0 | `type 'Text' is not a subtype of type 'RichText'` |
| `test/membership_page_ui_test.dart` | membership page stays usable at Size(320.0, 700.0) and scale 1.6 | **10 分钟超时 → 阻塞整个套件** |

### 为什么这是 P0

1. **无法可信回归** —— 套件跑不完，任何后续改动都无法判断是否引入回归。这是所有其他开发工作的前置条件。
2. **掩盖真实缺陷** —— 320dp 会员页头部溢出是**真实用户可见**的布局 bug（小屏手机）。
3. **`CURRENT_STATUS.md` 的"全部通过"已失效** —— 交接文档与真实状态不一致，会误导后续开发者。

### 建议（已列为 Phase 1 的第 0 项，先于一切其他工作）

1. 修 `membership_page.dart:360` 的头部高度预算（真实 UI 缺陷）。
2. 修会员页永不停歇的动画/Timer，让 `pumpAndSettle` 能静止；或把测试改为 `pump(Duration)` + 显式条件断言。
3. 同步 `membership_page_ui_test.dart:62` 与实现的 `Text`/`RichText` 契约。
4. 在 `flutter_test_config.dart` 中为单测试设置**合理超时**（如 60s），避免单个挂起测试吃掉 10 分钟。
5. 修复后重跑，取得"全绿"基线并**更新 `CURRENT_STATUS.md`**。

**其他基线事实（本次已实测）**：

```bash
ls -la build/app/outputs/flutter-apk/
→ app-release.apk   93,906,423 bytes   (2026-09-17 02:28)
   app-debug.apk  221,615,858 bytes   (2026-09-17 10:09)
```

`android/key.properties` **不存在**（实测 `ls` 无此文件），且 `android/app/build.gradle.kts:58-67` 在缺少该文件时把 `release` 的 `signingConfig` 指向 **`debug`**。因此当前的 `app-release.apk` 是 **debug 签名**的：

- ❌ 无法提交任何应用商店（商店拒绝 debug 签名包）
- ❌ 与非 debug 签名的历史包**签名不同**，用户**无法覆盖升级**（必须卸载重装，本地数据会丢失）
- ⚠️ 仅可用于本机验收，`README.md` 已如实说明这一点

---

## 19. 给新窗口继续本任务的交接说明

**本报告文件**：`docs/PROJECT_AUDIT_2026-09-17.md`

**新开窗口的提示词（可直接复制）**：

```
请先阅读 docs/PROJECT_AUDIT_2026-09-17.md（全项目工程审计报告），
再阅读 docs/development/CURRENT_STATUS.md 了解最新开发状态。

本报告已完成「扫描 / 理解 / 整理 / 建图 / 发现问题」阶段，禁止重新做一遍审计。
接下来按报告 §17 的《接下来开发顺序》执行 Phase 1。

本次只做 Phase 1 的第 <N> 项：<具体事项>。
（若 N=0，即"修复测试基线"：会员页 320dp 溢出、pumpAndSettle 挂起、Text/RichText 契约漂移。）

要求：
0. 注意：当前 flutter test 基线**不绿且跑不完**（255通过/6失败/单测试10分钟超时）。
   若本次不是修基线，请先用 `flutter test --reporter expanded --concurrency=1 --plain-name "<相关测试名>"`
   只跑与本次改动相关的测试来验证，避免被已知挂起测试阻塞 10 分钟。
1. 先跑 flutter test 与 flutter analyze 建立基线，记录结果。
2. 只改必要代码，复用现有 Service / Repository / Provider / 配置体系。
3. 不允许假实现、Mock 冒充真实功能、TODO 代替实现。
4. 完成后运行 flutter analyze、flutter test、相关构建，并在报告中记录真实结果。
5. 无法真实联调的第三方（支付/行情）必须明确说明"代码完成但未实际联调"。
6. 完成后更新 docs/PROJECT_AUDIT_2026-09-17.md 对应条目的状态，
   并更新 docs/development/CURRENT_STATUS.md。
```

**建议的 Phase 1 起步顺序**（按"先解锁阻塞项、后动业务"排）：

| 顺序 | 事项 | 理由 |
| --- | --- | --- |
| **0** | **修复测试基线（会员页 320dp 溢出 + pumpAndSettle 挂起 + 契约漂移）** | **不做这一步，后续任何改动都无法验证**。且其中含 1 个真实用户可见的布局缺陷 |
| 1 | 修 §12 的 4 个低风险 bug（#26/#27/#4/#20） | 成本 <1 天，立即消除 2 个功能不可用 |
| 2 | APP 版本更新（§9.2） | 后续所有发布都依赖它 |
| 3 | 401 统一处理 + 会员权益接线 | 逻辑修复，测试可完整覆盖 |
| 4 | 隐私政策 + 同意门 | 商店审核阻塞项 |
| 5 | Android keystore + `--dart-define` 构建脚本 | 发布阻塞项 |
| 6 | Sentry 接入 | 后续所有验证都依赖它 |
| 7 | 投资行情真实化（或下架） | 产品诚信风险 |
| 8 | 后端公网部署 + 支付联调 | 周期最长，需尽早启动 |

---

**审计结束。本轮未修改任何业务代码，仅新增本报告文件。**
