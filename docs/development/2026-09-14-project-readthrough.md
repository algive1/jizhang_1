# 项目完整读码交接记录

> 日期：2026-09-14  
> 范围：`/Users/algive/jizhang_01`  订单/记账应用源码、配置、测试、原生端和服务端

## 结论

本次已按模块逐文件通读项目中的手写业务代码、页面代码、数据层、Android/iOS 原生代码、服务端、测试、构建配置和开发文档，并通过静态检查及主要测试验证调用链。

本次没有修改任何业务代码。当前工作区原本就存在大量已修改和未跟踪文件，均已保留，没有执行回退、清理或覆盖操作。

生成文件 `lib/core/database/app_database.g.dart` 以其生成头、表声明、查询映射和文件尾部进行结构性交叉核对；它是 Drift 生成产物，重复代码不再当作手写业务逻辑逐行复核。手写 schema 位于 `lib/core/database/app_database.dart`，后续数据库修改应以手写 schema 和迁移逻辑为主。

## 一、整体架构

项目是 Flutter/Dart 的本地优先记账应用，Android 是当前功能最完整的平台，包含共享账本、会员支付、语音记账、支付通知和 Android 自动记账扩展。服务端是 Fastify + SQLite 的本地/可部署共享账本服务。

核心分层如下：

```text
main.dart
  → ProviderScope / JizhangApp
  → GoRouter / AppScaffold
  → Riverpod providers
  → Presentation 页面与 Sheet
  → Application Service
  → Domain Model / Policy
  → Repository
  → DAO
  → Drift / SQLite
```

启动时会完成日期本地化、数据库创建与 seed、通知队列处理、周期账单自动记账、分期还款处理、Android 日调度注册和共享同步前台状态管理。`JizhangApp` 还监听 App lifecycle，在恢复前台时重新处理通知、周期账单和共享同步。

路由由 `lib/app/router/app_router.dart` 统一管理，外层 `ShellRoute` 使用 `AppScaffold`。主要业务页面包括首页、交易、搜索、收件箱、退款/报销、日历、分析、目标、账户/资产、分类、预算、会员、共享账本、支付通知、自动记账、周期账单、分期账单和助手。

## 二、最重要的记账调用链

### 手动、语音、助手和自动记账确认

```text
QuickAddSheet / VoiceBookkeepingSheet / Assistant / AutoBookkeepingConfirmPage
  → QuickBookkeepingRequest
  → QuickBookkeepingService
  → TransactionRepository.create/createAll/update/softDelete
  → Drift transaction
      ├─ 写入交易
      ├─ 按 AccountBalanceEffect 调整账户余额
      ├─ 校验 book/account/category/关联交易的账本边界
      └─ 处理软删除时的余额反向修正
  → 附件、最近账户设置、智能分类/重复检测等次级处理
  → Riverpod stream 刷新首页、交易列表、账户和分析
```

`QuickBookkeepingService` 对批量记账采用“一次提交、后处理”的模型。主账本已经提交但附件或智能后处理失败时，会抛出 `BookkeepingCommittedException`，调用方必须提示“已保存但部分后处理失败”，不能自动重试造成重复记账。

金额统一以整数分保存；展示和输入使用 `MoneyFormatter`。金额输入支持计算表达式，但最终值仍必须满足正数、两位小数和上限约束。交易类型通过 `AccountBalanceEffect` 统一决定账户余额影响：支出、收入、转账、借入/借出、还款、退款、报销、资产购买和调整分别有明确方向。

更新交易时先反向应用旧余额效果，再写入新交易并应用新效果；删除是软删除，并反向修正余额。已被退款、报销、分期还款或其他关联记录引用的交易不能直接删除。

### 周期账单和分期

`RecurringBillExecutionService` 先创建周期账单，再按计划日期生成稳定 ID 的交易；稳定 ID 使重复运行具备幂等性，并支持补处理到期记录。`InstallmentPlanRepository` 将分期还款单独记录为 `repayment` 类型，生成稳定 repayment ID，更新剩余期数和下次还款日期；还款不应重复计入消费分析。

### Android 自动记账

```text
AccessibilityService / NotificationListener
  → AccessibilityTreeReader / WeChatPaymentParser
  → PaymentSceneDetector + fingerprint 去重
  → AutoBookkeepingPendingStore
  → AutoBillOverlayService 仅展示识别结果
  → 用户点击“去确认”打开 Flutter 确认页
  → 用户选择账本、账户、分类
  → MethodChannel / AutoBookkeepingBridge
  → Flutter AutoBookkeepingRepository
  → QuickBookkeepingService
```

当前设计明确要求先确认账本和分类，Overlay 不会在未确认时自动写入账本。解析器要求明确的支付成功场景和金额/商户字段，对歧义金额、聊天报价、失败支付和错误页面会拒绝识别。Pending candidate、处理 fingerprint 和日志都做了 TTL/脱敏处理。

Android 的支付通知记账链路类似，但来源是通知文本；会根据应用包名识别微信/支付宝/银联，并通过账本、账户映射和 metadata 去重。iOS 当前没有等价的自动记账原生实现。

## 三、数据库和数据边界

### Drift/SQLite

`AppDatabase` 当前 `schemaVersion` 是 **17**。主要表覆盖：

- 账本、账户、分类、交易、附件；
- 目标、里程碑、目标贡献；
- 月度预算、周期账单、分期计划；
- 应用设置、商户规则、智能收件箱、经济事件；
- 家庭/共享账本、成员、邀请、同步日志、家庭预算；
- 广告展示事件。

迁移逻辑是 forward-only，并在打开数据库时建立索引、安装共享同步 schema、开启 SQLite foreign keys。低版本迁移包含账本隔离、附件元数据、资产账户、退款/报销关联、周期账单、分期、账户标识后缀等步骤。共享同步 schema 通过 ACL、role 校验、版本号和 outbox 触发器保护共享数据。

`book_scope_migration.dart` 是账本隔离的关键迁移：它会复制非个人账本的默认账户/分类，迁移交易 bookId，重建预算唯一约束，并检查账户余额和外键完整性。

### 账本隔离

绝大多数 repository、DAO 和 provider 都有 `bookId`/`accountBookId` 范围。账户、分类、交易、预算、目标、周期账单和分期都必须属于当前账本；跨账本账户、分类、关联交易会在 repository 层拒绝。

共享账本使用 `SharedSyncSchema.visibleBooksSql` 和服务端 ACL 判断可见范围。服务端还会重新校验身份、成员角色、版本冲突、引用关系、交易金额和账户余额，客户端不能作为共享账本的最终可信边界。

### 备份和附件

SQLite 完整备份会验证 SQLite header、核心表和 schema version，并在恢复前创建安全副本。共享备份恢复后会重新验证成员资格，不能仅凭备份内容恢复共享访问权。

附件文件保存在应用文档目录的 `bookkeeping_attachments`，不在 SQLite 文件内，因此不包含在 SQLite 备份中，也没有实现云对象同步；界面已经对此做了提示。这是当前明确的产品边界，不是遗漏的假同步。

## 四、业务模块理解

- `accounts`：账户 CRUD、排序、归档、余额校准、资产/负债汇总；校准不是直接改余额，而是写入 adjustment 交易。
- `categories`：根分类和二级分类、同账本父子校验、归档时处理子分类、排序。
- `transactions`：月份/类型/分类/状态/金额比较搜索，详情、复制、退款、报销、删除和附件展示。
- `books`：个人/家庭/企业账本、主资产账户、排序、默认账本、账本配额和共享状态。
- `budgets`：月度总预算、分类预算、当前月消费进度和 SafeToSpend；消费只统计实际已发生交易。
- `goals`：目标、里程碑、贡献、取出、调整、封存、恢复和预测；贡献是追加记录，当前金额按贡献重算。
- `analysis`：本地内存计算趋势、分类、热力图、时段、基线和洞察；分析前会过滤删除、未来和非目标币种数据。
- `recurring`：周期计划、首次记账、到期自动生成、手动补记和归档/暂停。
- `installments`：从原始消费/借出/资产购买建立分期，逐期登记还款并避免重复消费统计。
- `sharing`：登录、共享账本、邀请、成员角色、同步、冲突解决、离线草稿和服务端恢复校验。
- `membership`：本地免费快照和服务端会员目录；支付订单、SDK 调起、服务端回调、幂等购买记录和权益刷新。
- `assistant`：本地规则助手 + 可选服务端 AI；本地规则支持帮助、预算、摘要、导出、会员和记账，图片识别/附件识别仍是开发中提示。
- `voice`：设备语音识别、规则解析、可选 AI JSON 解析和确认卡；只有确认后的有效交易才进入统一记账服务。
- `notifications`：Android 通知监听、待处理队列、账本/账户映射、去重和错误反馈。
- `ads`：内置广告位和事件记录；会员、敏感路由和高风险类别有展示限制。

## 五、服务端理解

服务端位于 `server/`，由 Fastify、SQLite、Zod contract 和 store 组成。主要边界如下：

```text
HTTP route
  → auth/session/rate limit
  → Zod strict contract
  → role/membership/version/idempotency 校验
  → SQLite transaction
  → validateAndRecalculate
  → entities/changes/operations/logs
```

服务端的 `store.ts` 会根据 opening balance 重新计算账户余额，而不是信任客户端传来的计算值；共享成员只能修改自己允许修改的交易；调整、目标、交易和账户之间存在版本冲突保护。批量 mutation 具有事务性和幂等性。

AI provider 只在服务端读取环境变量中的 provider key，Flutter 不持有服务端密钥。助手策略包括会员资格、请求长度、频率、每日额度、范围正则和 usage 记录。支付价格以服务端 catalog 为准，服务端会校验回调签名、解密结果、订单金额和幂等状态，客户端 SDK 返回值不能直接授予会员。

## 六、已确认的风险和文档/实现差异

以下内容是本次读码后需要后续处理或持续关注的事项，并非本次修改：

1. `docs/development/ARCHITECTURE.md` 和旧状态文档中仍有 schema version 15 等旧描述，源码 `AppDatabase` 已是 version 17。后续应统一文档，避免迁移排查时以旧版本为准。
2. 客户端 `BookLimitPolicy.free` 当前允许最多 10 个 active books；服务端共享账本上限是 3。两者适用范围不同，但文档中有旧的“免费 3 本”描述，需要明确区分本地账本配额和共享服务端配额。
3. 首页的 `HomeExpenseTrend` 组件具备金额隐藏参数，但 `HomePage` 当前创建它时没有传入首页的隐藏状态。需要确认隐私模式下趋势图是否应完全隐藏金额；如果产品要求一致隐藏，这是一个 UI 联动缺口。
4. `TransactionIntelligenceService` 明确跳过 transfer 和 adjustment；repayment 在分析层被排除，但智能分类层是否应同样跳过 repayment，需要结合产品规则补一条明确测试，避免还款被放入不必要的分类收件箱。
5. 生产支付、云端 AI、共享后端公网部署、TLS、监控和真实商户配置不在当前本地验证范围内。代码具备未配置时的 unavailable/error 分支，但不能据此声称已完成生产联调。
6. iOS 的自动记账能力尚未实现；`Info.plist` 中仍存在需要真实配置的微信 app ID 占位项，iOS 构建和真实支付回调也未在本次验证。
7. OCR、云端 ASR、图片识别、附件云同步属于未完成或明确显示“开发中”的能力；当前没有用固定返回或 mock 冒充成功。
8. 分析和首页部分 provider 会把当前账本交易加载到内存计算；数据量增大后应评估分页、聚合查询或缓存策略。
9. release signing 在缺少 `key.properties` 时会回退到 debug signing。用于正式发布前必须显式配置 release keystore。
10. `QuickAddSheet` 的非图片附件选择路径没有使用其传入的附件类型参数，目前 MIME/类型主要依赖文件本身；若要严格限制类型，应补充类型过滤和测试。

## 七、验证结果

本次实际执行：

- `flutter analyze --no-pub`：通过，`No issues found`。
- `server` `npm run typecheck`：通过。
- `server` `npm test`：通过，10 个测试全部通过。
- `server` `npm run build`：通过。
- Flutter 非视觉逻辑/交互测试：排除测试配置文件、视觉截图测试和已单独处理的 membership UI 文件后，62 个测试文件、221 个用例全部通过。
- 单独执行窄屏大字 membership 用例：通过。

视觉测试没有批量运行，因为这些测试会写入 `docs/qa` 截图目录；当前工作区已有大量用户生成的视觉产物，本次不额外扩大变更范围。第一次批量测试命令曾误把 `flutter_test_config.dart` 当作测试文件，随后修正命令并完成上述 62 文件测试；这不是代码编译或 analyzer 错误。

## 八、后续建议顺序

如果下一步要继续维护，建议按以下顺序处理：

1. 先统一 schema version、账本配额和当前状态文档。
2. 补首页隐私金额联动和 repayment 智能分类规则的回归测试。
3. 对共享同步、支付回调、自动记账确认做真实环境配置后的联调；本地单元测试不能替代这一步。
4. 评估附件备份/同步策略以及分析数据量增长后的性能。
5. 发布前验证 iOS 构建、Android release signing、真实 HTTPS、密钥注入和监控。

## 工作区注意事项

本次读码前工作区已经存在大量 tracked modifications、未跟踪 Android/Dart 文件、测试截图、APK 和源码压缩包。本记录不代表这些文件是本次产生的，也不对其内容做覆盖或回退。继续开发时应先按 `git status --short` 区分已有工作，再选择性提交或整理。
