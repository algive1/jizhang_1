# 记账 APP 管理后台：仓库分析与实施边界

分析日期：2026-10-06。代码位置：项目实际 Git 根目录 `repo/`，而非外层工具目录。本文以当前工作区代码为准；现有架构文档中的数据库 v18 已过时，实际 Drift 为 v25。

## 架构决定

现有服务不是空项目：`server/src/app.ts` 使用 Fastify 5、TypeScript、better-sqlite3，已经承载账号、会话、共享账本、会员支付、Apple IAP、个人云数据、AI、推送和诊断。`server/src/admin.ts` 有基于 ADMIN_TOKEN 的简易运营页面，且正在被其他工作修改。

ContiNew 是 Java / Spring Boot / MyBatis / Sa-Token 系统，不能直接替换这些 Node 服务而不迁移账号、会话、数据库、支付回调和同步协议。因此依据需求第 34 条：保留现有服务，在 `server/src/console/` 增量建立独立管理 API，建立独立 `admin-web/` Vue 3 + TypeScript + Vite + Arco 前端。不会创建一个重复保存用户和账本的 Java 数据库。Gi Admin Pro 仅作布局与统一表格设计参考，不引入其 mock 后端。

参考：[ContiNew 源码](https://github.com/continew-org/continew-admin)、[Gi Admin Pro](https://github.com/lin-97/gi-demo)。MySQL / Redis / Java 框架迁移属于后续独立迁移项目，当前不假称已接入。

## 已核实的业务模型与代码入口

| 范围 | 当前实现 | 管理端边界 |
| --- | --- | --- |
| 账号 | `server/src/app.ts`、`lib/features/sharing/data/session_repository.dart`；用户名、显示名、scrypt 密码、SHA-256 会话哈希、恢复密钥哈希 | 复用 user ID，禁止返回密码、恢复密钥、会话令牌 |
| 账本 | `lib/core/models/book.dart`、`app_database.dart`；personal/family/company、owner、sharedId、角色、assetSourceBookId | 聚合账本类型；不默认暴露账本名称和正文 |
| 流水 | `TransactionEntries`、`transaction_record.dart`；整数分、type、bookId、accountId、targetAccountId、分类、商户、note、source、version、软删除 | 聚合统计与私密明细分离；私人本地流水不能当作服务端已有数据 |
| 分类 | `category.dart`；收入/支出、parentId、bookId、隐藏/排序 | 保持本地层级与账本作用域 |
| 商户/渠道 | 流水 merchant、支付候选 paymentMethod / sourceApp、商户归一化和学习规则 | 不采集原始商户文本、账户后缀、订单号 |
| SQLite | `lib/core/database/app_database.dart`；Drift v25、SQLCipher key store、本地附件 | 保持离线核心数据库与迁移不变 |
| 共享同步 | `shared_sync_schema.dart`、`server/src/store.ts`；entities / changes / operations、游标、幂等操作、409 冲突 | 不重建数据模型或修改同步版本协议 |
| 个人云 | `personal_cloud_backup_service.dart`、`server/src/personal_cloud.ts`；datasetId、revision、snapshot_blob/size/sha256 | 后台只返回大小、校验和、版本和时间 |
| 自动记账设置 | Flutter `auto_bookkeeping_settings.dart` 与 Kotlin `AutoBookkeepingSettings.kt` | 无上报时开关状态返回 null，不能猜测 |
| 通知监听 | `PaymentNotificationListenerService.kt`、`PaymentNotificationStore.kt`、`PaymentNotificationCandidateParser.kt` | 通知解析是本地能力，禁止上传完整正文 |
| 页面识别 | `AutoBookkeepingAccessibilityService.kt`、`AccessibilityTreeReader.kt`、PaymentJourney / CompletionGate / WindowPolicy | 不上传页面完整文本或截图；页面 hash 和命中结果可上报 |
| 支付候选 | `autobookkeeping/model/PaymentCandidate.kt`；TransactionCandidate 统一模型，金额分、时间、置信度、paymentSessionId、退款/转账相关字段 | 新遥测引用 traceId，不同步 candidate 中的 note、订单号或截图路径 |
| 合并/去重 | `AutoBookkeepingPendingStore.kt`、PaymentInboxDedup / BillDedupEngine、Flutter refund matcher / transfer resolver | 后台记录实际阶段结果；服务器不替本地重新认定一笔支付 |
| 原生浮层 | `AutoBillOverlayService.kt`、`AutoBookkeepingEngine.kt`；原生宿主和复用 Flutter 确认 engine | 保持现有展示、确认、忽略、延迟与写库逻辑 |
| 通信 | `AutoBookkeepingChannels.kt`、`MainActivity.kt`；`jizhang/autobookkeeping_pending`、`autobookkeeping_overlay`、`payment_notifications`、`autobookkeeping_logs`、`local_ocr` | 当前不改这些 channel，不接管确认浮层 |
| AI | `assistant_policy.ts`、`assistant_ai.ts`、`insights.ts`；服务器 provider、额度和请求幂等，远程 parsing gateway | 当前 provider complete 只返回文本，没有真实 Token/费用数据；成本不能从调用次数猜算 |
| OCR | `local_ocr_service.dart` / `bill_screenshot_parser.dart`、原生 `local_ocr` | 离线识别保留；不上传用户图片 |
| ASR | `speech_recognition_service.dart`、voice transaction parser | 语音录音和识别正文不能进后台日志 |
| 自动规则 | `PaymentRule.kt` / `AutoBookkeepingRuleRegistry.kt` 和各 APP parser；本地规则与定制 APP | 远程规则必须是声明式、版本化，并保留本地默认与回退 |
| APP 配置 | app_settings 本地设置；服务端 assistant/insight/ad/theme 等策略 | 新通用配置与旧策略并存，不暗中改变用户设置 |
| 版本策略 | `server/src/app_update.ts` + Flutter `app_update_service.dart`；现由环境变量提供语义版本策略 | 数据库发布策略优先，未发布时继续使用原环境配置 |
| 日志 | `OperationLogService`、GlobalCrashReporter、Kotlin LogStore；通用诊断批量幂等；analytics 以匿名 installationId 统计 | 新事件链使用严格字段白名单；旧日志在管理读取时再次脱敏 |
| 运营 | support tickets、announcements、push_devices/outbox、membership_catalog | 复用数据表和已有服务，不通过后台开发擅自发送消息 |

## 关键差距与敏感数据

1. 现有云备份格式 `gzip+base64` / `gzip+base64+json-v2` 是压缩，不是端到端加密。服务端会验证解压后的 SQLite。不能将这套现有备份标为“加密备份”。端到端加密必须新增协议、客户端持钥、恢复策略和兼容迁移后接入，保留为明确 TODO。
2. 本地自动记账链路有阶段日志，但尚无跨通知/页面/浮层/数据库/同步统一 traceId 的可靠上传协议。后台新增可用的事件 API 与时间轴，APP 接入独立推进，不改正在迭代的 Kotlin 核心。
3. analytics 的 installationId 不是 userId。DAU/MAU 明确表示活跃安装设备；登录用户最近活跃来自会话请求。不能混称唯一活跃账号。
4. 当前 AI provider 没有 usage 回执。新增管理配置不等于既有 AI 路由已采用该配置；未接入字段在后台明确标识。
5. 私人账单、账本标题、备注、商户、附件、备份 blob、聊天/ASR/OCR 正文、银行账户标识均为敏感内容。管理端不提供浏览备份 blob 的入口。

## 新服务端结构

所有管理表使用 `console_` 前缀、幂等初始化与独立迁移标记；不改变 Store 的现有 user_version。

- 管理账号、角色、会话哈希、登录记录、审计日志；管理员与 APP 用户完全分离。
- 用户状态与设备元数据：引用原 users.id，不复制用户密码。禁用撤销现有会话且阻止重新登录。
- APP 发布版本：草稿、发布/下线、最低版本、版本号、HTTPS 下载链接、灰度比例与发布时间。
- 远程配置、自动规则、Prompt：不可变修订、当前发布指针、灰度、下线、历史与回滚；操作者/时间/备注。
- 遥测事件：用户和 trace 作用域、事件 ID、毫秒时间、阶段、结果、失败码、规则/APP/设备版本；事件匹配引用同一 trace。
- AI 模型配置保存 key 的环境变量引用，前端和日志不返回密钥值；真实 usage 集成前成本为未知。

## 数据同步策略与离线保障

现有共享游标同步和个人 revision 备份继续工作。新事件按 `(user_id,event_id)` 幂等，trace 限定同一用户，批次大小和日志字段上限由服务端限制。设备以 `(user_id,installation_id)` 幂等 heartbeat 更新。发布配置与规则按稳定 installationId 分桶灰度，客户端缓存最后一个校验通过的版本，下载失败继续用本地默认。

TODO：Flutter/Kotlin 统一 trace、用户主动同意诊断、离线队列/重试/TTL、动态规则验证与应用、远程功能门控、AI provider 路由/usage 回执、加密备份 v3。后台不会将这些尚未发生的 APP 行为标成已接入。

## API 与模块规划

新管理 API 统一前缀 `/api/v1/console`，成功返回 `{data: ...}`，错误沿用现有统一 `{message,details}`；分页 `{items,total,page,pageSize}`。所有列表服务端分页，排序使用白名单。管理会话不能调用 APP 用户接口，旧 ADMIN_TOKEN 不能调用新控制台。

| 阶段 | 模块 | 接口 |
| --- | --- | --- |
| P0 | 登录、角色、菜单、管理员、审计 | `/auth/login`、`/auth/me`、`/auth/logout`、`/roles`、`/administrators`、`/audit` |
| P0 | Dashboard、用户详情/禁用、设备、账务聚合 | `/dashboard?days=7|30`、`/users`、`/users/:id`、`/users/:id/status`、`/devices`、`/ledger/statistics` |
| P0 | APP 版本与远程配置 | `/releases`、`/releases/:id/state`、`/documents/config` |
| P1 | 支付通知、页面事件、时间轴、失败案例、规则修订 | `/events`、`/events/trace/:userId/:traceId`、`/documents/rule` |
| P2 | AI 模型、Prompt 与成本观测 | `/ai/models`、`/documents/prompt`、`/ai/usage`；真实路由未接入需明确标识 |
| P3 | 备份元数据、反馈、公告、FAQ | `/backups`、`/feedback`、`/operations`；Push 只通过已有服务，后台开发不主动触发投递 |
| APP 增量 | 设备、事件链、配置与规则下载 | `/api/v1/app/heartbeat`、`/api/v1/auto-accounting/events`、`/api/v1/app/config`、`/api/v1/app/rules` |

六类初始角色：超级管理员、运营、客服、开发、数据分析、AI 管理员。权限以 action 粒度校验，服务端是最终授权边界。`ledger:transaction:view-sensitive` 单独保留，不默认分配；管理统计接口不会返回私密内容。前端菜单和按钮从服务端权限派生。

## 影响面与验证

新增 `admin-web/`、`server/src/console/`、`server/test/console*.test.ts`、本文与部署说明。必要修改限于 `server/src/app.ts` 注册新路由/用户禁用边界，`app_update.ts` 数据库策略回退，AI usage adapter 如接入则单独验证。保留正在修改的 `admin.ts`、`personal_cloud.ts`、会员文件、Flutter UI、Kotlin、Drift schema。

每阶段依次执行后端 typecheck/build/test、前端 lint/typecheck/build、API 集成与权限测试、浏览器操作测试。只提交本任务明确文件，不使用 `git add -A`。服务运行时库与所有密钥不入 Git。

## 实施后更新

以上业务分析记录开发前状态。本轮已经新增 `ConsoleAIProvider`，后台启用的模型可以路由到真实 Endpoint 并记录 usage 与估算成本；原有 legacy provider 的 Token 仍未知。P0 / P1 与 AI、辅助运营管理代码已经落地。当前可用功能、APP 尚未接入的部分及验证命令详见 [交付说明](admin-console-delivery.md) 和 [启动说明](../admin-web/README.md)。
