# 账户体系 Phase 1：账户基础层（源码文档）

日期：2026-09-18
范围：**仅 Phase 1（账户基础层）**。Phase 2～7 未开发。
上游规范：`好好记账_Codex账户体系完整交互开发提示词.txt`（长期约束，非一次性交付清单）

---

## 一、本轮实际阅读的关键源码

### 客户端（`jizhang_app/lib`）

| 文件 | 为什么读 |
| --- | --- |
| `features/sharing/data/session_repository.dart` | 唯一登录态来源；`SessionUser` / `SessionStorage` / `SecureSessionStorage` / `SessionRepository` 全在这里 |
| `features/sharing/data/shared_api.dart` | 所有服务器请求的 HTTP 客户端；`sessionToken` 内存字段、`SharedApiException(status,message)` |
| `features/sharing/application/shared_book_sync_service.dart` | 401 处理、`setSyncActor` 的间接影响、共享账本可见性触发器 |
| `core/database/shared_sync_schema.dart` | `sync_control.actor_id`、`visibleBooksSql`、`setSyncActor`、共享触发器 ACL |
| `core/database/app_database.dart` | `schemaVersion = 18`、migration 链、`currentActor`、`books.owner_user_id` |
| `core/database/database_provider.dart` | `databaseProvider` / `createMemoryDatabase()` |
| `core/database/database_seeder.dart` | `SeedIds.localUser = 'user-local'`、`SeedIds.personalBook` |
| `features/membership/data/membership_repository.dart` | `LocalOnly` / `Remote` 双实现与 `sessionRepositoryProvider` 依赖 |
| `features/membership/data/payment_service.dart` | 下单链路，确认客户端是否传 `userId` |
| `features/membership/domain/commercial_service_contracts.dart` | `CreatePaymentOrderRequest.userId`、`MembershipFeatureAccessService`、`CloudSyncService` |
| `features/membership/presentation/membership_page.dart` | 游客点击购买时的现有拦截方式（对话框） |
| `features/membership/application/membership_purchase_bookkeeping.dart` | 会员购买记账，全部写 `SeedIds.personalBook` |
| `core/models/membership.dart` | `MembershipPlan` / `EntitlementKey` / `MembershipFeature` / `FeaturePolicy` |
| `features/profile/presentation/profile_page.dart` | ProfileHero 展示 `user.username`、点击进入共享账本 |
| `features/family/presentation/family_page.dart` | 当前真实登录/注册 UI 与退出登录 |
| `features/family/data/shared_family_service.dart` | 邀请、成员、角色全部依赖 `sync.session.user!` |
| `features/family/domain/family_access_policy.dart` | 共享角色权限判定 |
| `app/router/app_router.dart` | 无全局 redirect；`/profile/*` 路由树 |
| `app/app.dart` | 启动流程（本地库 bootstrap → 首页 → 后台恢复会话） |
| `core/diagnostics/operation_log.dart` | 依赖 `_api.sessionToken != null` 判定是否上传诊断 |
| `features/assistant/application/assistant_policy.dart`、`assistant_engine.dart` | 依赖 `sessionProvider` 决定本地/远程实现 |
| `features/data_export/application/local_backup_service.dart` | 本地备份/恢复能力（与 dataset binding 相关） |

### 服务端（`server/src`）

`app.ts`（auth/sessions/books/members/invitations/rate limit）、`store.ts`（users/sessions 表结构与 migration）、`payment.ts`（订单归属）、`contract.ts`、`membership_catalog.ts`、`diagnostics.ts`。

### 测试

`shared_backend_integration_test.dart`、`shared_restore_regression_test.dart`、`membership_page_ui_test.dart`、`membership_test.dart`、`family_domain_test.dart`、`profile_reference_test.dart` 以及全部 91 个测试文件的清单。

---

## 二、当前账户架构图（Phase 1 完成后）

```
                    ┌─────────────────────────────────────────────┐
                    │  UI（本轮未改动任何页面视觉）                │
                    │  ProfilePage / FamilyPage / MembershipPage  │
                    │  PaymentService / Assistant / Diagnostics    │
                    └───────────────┬─────────────────────────────┘
                                    │ sessionProvider (StreamProvider<SessionUser?>)
                                    │ sessionRepositoryProvider
                    ┌───────────────▼─────────────────────────────┐
                    │ SessionRepository  ← 兼容门面（API 未变）    │
                    │  · user / userId / accountStatus            │
                    │  · watch() / initialize()                   │
                    │  · authenticate() / logout() / invalidate() │
                    │  · markSessionExpired()  ← 新增              │
                    └───────┬───────────────────────┬─────────────┘
                            │                       │
        LegacySessionStorageAdapter            SharedApi（HTTP + Bearer）
        （旧 SessionStorage → 账户信封）             │
                            │                       │
                    ┌───────▼───────────────────────▼─────────────┐
                    │ AccountSessionController  ← 新增，唯一状态源 │
                    │  status: initializing/guest/authenticated/  │
                    │          expired/error                      │
                    │  start() / signIn() / adoptIdentity() /     │
                    │  expire() / clear() / watch()               │
                    └───────────────────┬─────────────────────────┘
                                        │
                    ┌───────────────────▼─────────────────────────┐
                    │ SessionEnvelopeStorage                      │
                    │  SecureSessionStorage（生产）                │
                    │   · account_session_v1  ← 规范信封（新增）   │
                    │   · shared_ledger_session_v1 ← 旧键（继续维护）│
                    │  InMemorySessionStorage（测试）              │
                    └─────────────────────────────────────────────┘

  数据库 actor（共享账本可见性，本轮行为完全未变）
    SessionRepository.initialize() / authenticate() / invalidate()
        → AppDatabase.setSyncActor(服务器 user_id | 'user-local')
        → sync_control.actor_id
        → visibleBooksSql() → 本地个人账本 + 当前 user 的共享账本
```

### 关键依赖关系（源码事实）

1. **SessionRepository 位置**：`lib/features/sharing/data/session_repository.dart`（共享模块持有登录，这是本轮要去耦合的对象）。
2. **currentActor / user-local 产生点**：`AppDatabase.currentActor` 默认 `'user-local'`（`app_database.dart:704`）；持久值在 `sync_control.actor_id`，由 `setSyncActor()` 写（`shared_sync_schema.dart:160`）；`SeedIds.localUser = 'user-local'`（`database_seeder.dart:9`）。
3. **登录成功后如何 setSyncActor**：`SessionRepository.authenticate()` → `database.setSyncActor(user.id)`；恢复登录时 `_restore()` 同样调用；登出 `invalidate()` 写回 `'user-local'`。
4. **membership 如何获取当前用户**：`RemoteMembershipRepository` 注入 `SessionRepository`，`session.user == null` 时直接返回 `LocalOnlyMembershipRepository()` 的本地 free 快照；否则 `GET /membership/current`，服务端从 Session 取 `user_id`。
5. **共享账本如何获取 user_id**：`SharedBookSyncService` 全部通过 `session.user!.id`；`sync_books.user_id` 与 `sync_control.actor_id` 必须一致才会放行写入（触发器 `$allowed`）。
6. **Profile 如何展示 username**：`ProfilePage` 读 `sessionProvider`，`ProfileHero(name: user.value?.username ?? '本地用户')`；点击 `_profile()` 弹层，未登录跳到 `/profile/family` 登录。
7. **支付订单 userId 来源**：客户端 `CreatePaymentOrderRequest.userId`（membership_page 传 `session.user!.id`），但**服务端不采信**：`POST /api/v1/membership/orders` 用 `authenticate(authorization)` 得到的 `user.id` 落库（`server/src/payment.ts:326-340`）。提示词第 39 节的“支付安全”在当前源码中**已经是安全的**。
8. **401 如何处理**：只有 `SharedBookSyncService._sync()` 的 `on SharedApiException` 分支处理（本轮由 `session.invalidate()` 改为 `session.markSessionExpired()`）；其余网络错误走通用 `catch` 分支，不动 Session。
9. **本地数据是否与登录账号绑定**：**不绑定**。个人账本 `books.owner_user_id = 'user-local'`，流水通过 `book_id` 归属账本，与服务器 user_id 无关；登录只改变共享账本可见性。
10. **是否已存在设备 ID / installation ID / dataset ID**：**不存在**。只有 `transactions.device_id` 字段（共享上传时被置 `null`），没有任何安装级/数据集级身份。

### 依赖关系上发现的冲突（以源码为准，未擅自改动产品原则）

| 提示词假设 | 源码事实 | 本轮处理 |
| --- | --- | --- |
| `users` 只有 id/username/password_hash/created_at，需要升级 | 属实（`server/src/store.ts:16`），且 `PRAGMA user_version = 3` | 不动，属 Phase 2/5 |
| 客户端自由传 userId 需要移除 | 服务端已从 Session 取 user_id | 不改（已安全），仅在文档记录 |
| 需要 `GET /auth/sessions` 等设备管理 API | 服务端只有 `sessions(token_hash,user_id,expires_at)` | 不动，属 Phase 4 |
| `AccountLoginPage` 等页面已存在 | 不存在，登录 UI 内嵌在 `FamilyPage` | 本轮不新建页面（属 Phase 2） |
| Session 30 天 + 滑动过期 | 服务端 30 天固定，无滑动、无 `last_seen_at` | 不动，属 Phase 4 |

---

## 三、本轮新增文件（5 个）

| 文件 | 职责 |
| --- | --- |
| `lib/features/account/domain/account_session_status.dart` | `initializing / guest / authenticated / expired / error` 五态枚举 |
| `lib/features/account/domain/account_user.dart` | 统一服务器用户身份：`id`、`username`、`displayName`、`avatarKey`；兼容 `id`/`userId`、`displayName`/`display_name`；`preferredName` 回退 |
| `lib/features/account/domain/account_session.dart` | 会话信封：`user`、`token`、`expiresAt`、`baseUrl`、`status`；`toJson`/`fromJson`、`refreshedAt(now)`、`isUsableAt(now)` |
| `lib/features/account/data/secure_session_storage.dart` | `SessionEnvelopeStorage` 接口、`StorageRead` 密封结果（missing/canonical/legacy）、`LegacySessionPayload`、生产实现 `SecureSessionStorage`、测试用 `InMemorySessionStorage` |
| `lib/features/account/application/account_session_controller.dart` | 会话状态机 + 广播；`start/signIn/adoptIdentity/expire/clear/watch`；`accountSessionControllerProvider`、`accountSessionProvider` |

测试新增 4 个文件（`test/account_session_test.dart`、`account_session_storage_test.dart`、`account_session_controller_test.dart`、`account_session_repository_test.dart`）。

---

## 四、本轮修改文件（2 个）

| 文件 | 为什么修改 | 改了什么 |
| --- | --- | --- |
| `lib/features/sharing/data/session_repository.dart` | 让旧门面把状态委托给账户模块；保持对外 API 与注入签名不变 | `SessionUser` 保留 `id`/`username` 并新增 `toAccountUser()`；`SessionStorage` 接口原样保留；新增 `LegacySessionStorageAdapter`（旧存储 → 账户信封）；`SessionRepository` 内部改为持有 `AccountSessionController`，新增 `userId`/`accountStatus`/`markSessionExpired()`，恢复可写 `user` setter；`authenticate()` 增加登录响应字段校验；`logout()` 改为网络尽力而为 |
| `lib/features/sharing/application/shared_book_sync_service.dart` | 区分“服务器明确 401”和“网络异常” | 401 分支 `session.invalidate()` → `session.markSessionExpired()`（Token/actor 行为不变，仅多记录 `expired` 状态） |

---

## 五、数据库变化

**无。**

- Flutter Drift `schemaVersion` 仍为 **18**，`migration.onUpgrade` 未新增任何分支。
- 未创建/修改/删除任何 Drift 表，包括 `transactions`、`books`、`accounts`、`budgets`、`goals`、`recurring_bills`、`installment_plans`、`sync_*` 系列。
- 未新增 `device_data_binding` 等新表（属 Phase 6）。
- 服务端 SQLite：`user_version` 仍为 **3**，`users` / `sessions` 表结构未动，未新增 `display_name`、`status`、`recovery_hash`（属 Phase 2/4/5）。
- 唯一持久化变化在**客户端安全存储**（不属于数据库）：新增键 `account_session_v1`，并继续维护旧键 `shared_ledger_session_v1`。

---

## 六、API 变化

**客户端与服务端均无新增、无改动、无删除。**

- 客户端仍只调用 `/auth/login`、`/auth/register`、`/auth/logout`、`/membership/*`、`/books/*`、`/assistant/authorize`、`/diagnostics/events`。
- 请求头仍是 `Authorization: Bearer <token>`。
- 服务端 `app.ts` / `store.ts` / `payment.ts` 本轮**未做任何修改**。

---

## 七、兼容处理（核心）

### 1. 旧 SessionRepository 仍然兼容

对外 API 与迁移前逐项对齐，调用方零改动（8 个文件、3 个测试仍按原方式使用）：

| 迁移前 | 现在 |
| --- | --- |
| `SessionUser(id, username)` | 同左（新增 `toAccountUser()`） |
| `SessionStorage { read, write }` | 同左（接口签名完全未变，外部自定义实现继续有效） |
| `SecureSessionStorage()` | 同左（仍读写 `shared_ledger_session_v1`） |
| `SessionRepository(api, db, {storage})` | 同左 |
| `user`（可读可写 getter/setter） | 同左（setter 转为 `adoptIdentity`，测试注入仍生效） |
| `watch()` / `initialize()` | 同左（`watch()` 仍先发当前值再发变化） |
| `authenticate()` / `logout()` / `invalidate()` | 同左 |
| `sessionProvider` / `sessionRepositoryProvider` / `sharedApiProvider` | 同左 |

### 2. 旧用户与旧 Session 继续可用（三层兼容）

1. **识别旧键**：启动时先读 `account_session_v1`；没有则解析 `shared_ledger_session_v1` 的旧 JSON 结构（`{token,expiresAt,user,baseUrl}`），校验 `baseUrl` 与本地过期时间后恢复登录，**用户不需要重新注册或重新登录**。
2. **双写**：迁移成功后把同一份会话同时写入规范键与旧键，因此覆盖安装、甚至回滚到旧版本都能继续识别同一个 Token。
3. **注入式存储兼容**：不再使用默认安全存储的场景（测试、外部自定义 `SessionStorage`）通过 `LegacySessionStorageAdapter` 读同一份旧结构 JSON，行为与迁移前一致（含本地过期即清理）。

### 3. 现有共享账本不受影响

- `setSyncActor` 的调用时机与取值未变：`initialize()` 恢复身份时写服务器 user_id，`authenticate()` 写服务器 user_id，`invalidate()` / `markSessionExpired()` 写回 `user-local`。
- `sync_books`、`sync_outbox`、触发器 ACL、`visibleBooksSql` 全部未动。
- 端到端验证：`shared_backend_integration_test.dart`、`shared_restore_regression_test.dart` 均通过（双端真实 SQLite + 真实 HTTP + 真实共享账本 promotion/邀请/冲突/权限撤销/恢复场景）。

### 4. 会员获取与支付不受影响

- `membershipRepositoryProvider`、`paymentServiceProvider`、`SessionUser` 类型均未变。
- `RemoteMembershipRepository` 的 `session.user == null` 分支语义未变。
- 订单归属仍在服务端从 Session 取 `user_id`。

### 5. 登录与本地数据保持解耦

- 登录/登出只操作 `sync_control.actor_id` 与安全存储，不触碰任何本地账务表。
- 新增测试断言：登出后本地流水数量不变（`logout 清凭证、actor 回到 user-local，本地流水完整保留`）。

### 6. 网络错误 ≠ 登录失效

- `SharedBookSyncService` 只有 `SharedApiException.status == 401` 才标记失效；其他异常走通用分支。
- `AccountSessionController` 明确不做“网络失败 → 清会话”的映射，并在文档注释里写死这条约束。
- 顺带修掉一个真实缺陷：`logout()` 之前会把 `SocketException` 抛给 UI（用户在“退出登录”后看到网络报错），现在本地清理一定完成、服务端撤销尽力而为。

---

## 八、本阶段刻意没有做的事（防止越界）

- 没有新建任何页面（`AccountLoginPage` / `AccountRegisterPage` / `AccountCenterPage` / `AuthGateSheet` …）。
- 没有实现 `AuthGateService` / `PendingIntent`（Phase 3）。
- 没有新增路由、没有改 `GoRouter`、没有加全局 redirect。
- 没有改 `ProfilePage` / `FamilyPage` / `MembershipPage` 的任何视觉或交互。
- 没有新增 `dataset_id` / `device_data_binding`（Phase 6）。
- 没有改会员套餐、价格、权益、支付渠道。
- 没有改共享账本业务逻辑。
- 没有删除任何现有代码路径，`SessionRepository` 全部保留。
- 没有为对齐提示词而强造 `account_api.dart`：认证请求继续复用现有 `SharedApi`，因为它是唯一的 HTTP 边界，另造一层只会产生第二份 baseUrl/超时/错误处理。

---

## 九、检查结果

| 检查 | 结果 |
| --- | --- |
| `flutter analyze`（改动前基线） | `No issues found! (ran in 7.6s)` |
| `flutter analyze`（改动后） | `No issues found! (ran in 6.7s)` |
| `flutter test`（全量） | **+443 passed / 3 failed**，3 个失败**全部是环境/产物问题，与本次改动无关**（见下） |
| `flutter test`（两文件在仓库根目录运行） | `All tests passed!`（`shared_backend_integration_test`、`shared_restore_regression_test`） |
| 服务端 `npm run typecheck` | 退出码 0，无输出错误 |
| 服务端 `npm test` | `# tests 11 / # pass 11 / # fail 0` |

3 个失败项说明：

1. `shared_backend_integration_test.dart`、`shared_restore_regression_test.dart`：测试用相对路径 `server/node_modules/tsx/dist/cli.mjs` 启动服务端，因此必须在**仓库根目录**运行；在 `jizhang_app/` 下运行会 `MODULE_NOT_FOUND`。这是既有测试的运行方式要求，不是回归 —— 在根目录运行两者均通过。
2. `asset_visual_qa_test.dart`：写入 `docs/qa/asset-overview-fidelity-2026-09-12/round3.png` 失败（该产物路径在 `jizhang_app/` 下不存在），同样是既有 QA 产物测试与工作目录相关的问题，与账户体系无关。

---

## 十、已知风险 / TODO / 临时兼容层

1. **双写临时层**：`account_session_v1` 与 `shared_ledger_session_v1` 同时维护。Phase 2 完成后应评估是否停止写旧键（建议至少保留一个版本周期）。
2. **`expired` 状态不落盘**：401 后的 `expired` 只在内存存活，App 重启后退化为 `guest`。好处是绝不会复用被服务器拒绝的 Token；代价是重启后无法提示“你的登录状态已失效”。Phase 2 如需该提示，应改为“只持久化身份、不持久化 Token”的失效标记。
3. **`SessionUser` 与 `AccountUser` 并存**：两者目前都表示同一个人。Phase 2 改造 Profile 时应统一切到 `AccountUser`，并让 `SessionUser` 退化为 `AccountUser` 的类型别名或直接删除。
4. **`SessionRepository.user` setter 仍在**：为兼容旧的 UI 测试保留。Phase 2 之后应改为只能在测试中通过注入控制器实现。
5. **`account_api.dart`、`device_identity_repository.dart`、`data_binding_repository.dart` 未创建**：分别对应 Phase 2/6；提示词第 36 节建议的目录结构会在后续阶段自然补齐。
6. **服务端 users/sessions 未升级**：`display_name`、`status`、`sessions.device_id/device_name/platform/last_seen_at/revoked_at`、`recovery_hash` 全部待做（Phase 2/4/5）。
7. **没有“切换账号”的守卫**：提示词第 27 节要求 dataset 绑定 A 时禁止同步到 B。当前不存在 dataset 概念，因此该守卫会在 Phase 6 落地；现阶段登出再登录会正常切换共享账本可见性（已有回归测试覆盖）。
8. **未真机联调**：本轮不涉及网络写入，未运行真机验证；`flutter analyze` / `flutter test` / 服务端检查是唯一验证手段。

---

## 十一、Phase 2 建议

Phase 2 目标：独立登录注册（Login / Register / displayName / ProfileHero 改造 / 路由）。

建议按此顺序修改：

1. **服务端**（`server/src/store.ts`、`server/src/app.ts`）
   - `users` 增加可空 `display_name`、`status`（默认 `active`）、`updated_at`、`password_changed_at`；
   - `user_version` → 4，`ALTER TABLE` + 回填 `display_name = NULL`（展示回退 `username`）；
   - `register` 接受可选 `displayName`；`/auth/me`、`/auth/login` 响应增加 `user.displayName`（当前 `authenticate()` 的 SELECT 只有 `id,username`，必须一起改）；
   - `sessions` 暂不动。
2. **客户端账户模块**
   - 新增 `lib/features/account/presentation/account_login_page.dart`、`account_register_page.dart`；
   - 新增 `lib/features/account/application/account_auth_service.dart`（把 `SessionRepository.authenticate` 的注册/登录调用上移到账户模块，`SessionRepository` 只保留兼容转发）；
   - 可选：`lib/features/account/data/account_api.dart`，用 `SharedApi` 作为传输实现，避免共享模块直接拼 `/auth/*` 路径。
3. **路由**（`lib/app/router/app_router.dart`）
   - 增加 `/auth/login`、`/auth/register`；**不加全局 redirect**；
   - `ProfilePage._profile()` 与 `FamilyPage` 的登录区改为跳转这两个页面，`FamilyPage` 只保留“管理共享账本”职责。
4. **ProfileHero**（`lib/features/profile/presentation/profile_page.dart`、`profile_cards.dart`）
   - 游客显示“本地使用中” + “登录后可使用会员、云同步和共享功能”；
   - 已登录显示 `displayName`、`@username`、会员徽标，点击进入（Phase 5 的）Account Center。
5. **测试**
   - 服务端：`register` 带/不带 `displayName`、`display_name` 为 NULL 的旧用户登录、`/auth/me` 回退字段；
   - 客户端：登录/注册页面 widget 测试、`AccountUser.displayName` 回退、ProfileHero 两态、旧 `SessionStorage` 迁移后 `displayName` 为空仍可用。

进入 Phase 2 前建议先处理风险 2 与 3（`expired` 落盘策略、`SessionUser`/`AccountUser` 合并），否则 Profile 改造会同时面对两套用户模型。

---

## 十二、结论

- 本轮**只完成 Phase 1**：账户基础层（AccountUser / AccountSessionState / Secure Session / 兼容 SessionRepository），未改变共享账本行为。
- 不存在阻碍 Phase 2 的结构性问题；唯一需要在 Phase 2 一并处理的是 `expired` 状态的持久化策略与 `SessionUser`/`AccountUser` 的合并。
- 建议可以进入 Phase 2，但**必须先落服务端 users.display_name migration**（可空 + 回退 username），否则客户端 `AccountUser.displayName` 永远为空。
