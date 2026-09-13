# 好好记账项目架构、功能与节点总览

更新时间：2026-09-12

## 1. 结论先行

当前项目是一个 Flutter 移动端、本地优先的记账应用。主链路使用真实 Drift/SQLite 持久化；个人账本保持本机私有，家庭/企业账本通过独立 Node.js 共享服务完成本地双端联调。手动记账、账户余额联动、转账、编辑、软删除、目标、预算、收支分析、商户分类记忆和本地去重均有实际代码与测试覆盖。本轮又补齐统一流水关联、报销、退款、消费日历、周期账单、信用卡分期、账户详情和增强搜索。

会员、支付、公网部署、云端 AI 和第三方广告仍没有生产联调；共享后端已提供真实本地服务、权限、版本和冲突契约，不能把本地联调理解为公网已上线。

本轮按当前源码重新统计：

| 项目 | 当前值 |
| --- | ---: |
| Flutter/Dart 源文件（不含 generated） | 143 个 |
| 业务 Dart 代码量（不含 `app_database.g.dart`） | 34,928 行 |
| Drift 生成代码 | 27,069 行 |
| Feature 模块 | 24 个 |
| SQLite 表 | 22 张 |
| Drift DAO | 10 个 |
| GoRouter 路由节点 | 23 个 |
| 本轮 `flutter test` | 230 个测试全部通过 |

当前工作区包含此前多个功能切片的未提交改动；本轮未执行 reset、checkout 或批量清理，代码演进应以工作区 diff 和验证结果为准。

## 2. 技术栈与启动链路

依赖配置在 `pubspec.yaml`：Flutter、Riverpod 3、GoRouter 16、Drift 2.34、SQLite3 3.5、`file_picker`、`speech_to_text` 和 `intl`。项目没有引入 Riverpod code generation，Provider 以手写 Dart 声明为主。

本地共享后端在 `server/`：Node.js 22、TypeScript、Fastify 5、better-sqlite3 和 Zod。它独立于客户端 SQLite，负责会话、成员权限、邀请、快照、游标变化、幂等 mutation、版本冲突和操作日志；本轮只做本地两端联调。

启动链路：

```text
main.dart
  → WidgetsFlutterBinding.ensureInitialized
  → initializeDateFormatting('zh_CN')
  → ProviderScope
  → JizhangApp
  → MaterialApp.router
  → appRouterProvider / AppScaffold
```

`JizhangApp` 还注册了生命周期监听：应用首次显示和从后台恢复时，会调用支付通知自动记账服务处理 Android 原生队列，并执行已勾选 `auto_record` 的周期账单到期补齐。Android 另通过 `AlarmManager` 每日唤醒后台 Flutter isolate，处理周期账单和分期到期流水；每个发生日/分期使用稳定 ID 幂等。失败会保留到周期账单页提示，不阻断应用启动。

统一视觉入口：

- `lib/app/theme/app_theme.dart`：Material 3、中文字体、暖米白/鼠尾草绿主题。
- `lib/app/theme/app_colors.dart`：通用财务颜色。
- `lib/app/theme/finance_ui.dart`：首页和快速记账使用的薄荷青、渐变、卡片圆角和动画契约。
- `lib/core/widgets/`：卡片、金额、交易行、日期分组、底部导航等公共组件。

## 3. 分层架构与依赖方向

项目采用按业务 Feature 分组、Feature 内再分 `data / domain / application / presentation` 的结构。不是严格的 Clean Architecture，但核心职责边界已经明确：

```text
Presentation 页面 / BottomSheet
  ↓ ref.watch / ref.read Provider
Application Service（跨 Repository 的业务编排）
  ↓
Domain Service / Model（规则、计算、策略）
  ↓
Repository（领域模型 ↔ Drift Entity）
  ↓
DAO（查询、写入、数据库事务）
  ↓
Drift / SQLite 本地数据库
```

实际情况有两种：

1. 记账、智能分类、通知、会员购买记账等复杂流程经过 Application Service。
2. 账户、分类、预算、目标管理页面部分直接通过 Provider 读取 Repository，属于轻量 CRUD 入口。

全局 Provider 主干：

```text
databaseProvider
  → databaseBootstrapProvider
  → 各 Repository Provider
  → Stream/Future/Notifier Provider
  → 页面
```

账本切换是主要状态边界：`activeBookIdProvider` 持久化当前账本 ID；账户、分类、预算、流水、目标、商户记忆、收件箱和通知目标都按当前账本过滤，首页和分析再从过滤后的流水派生数据。账本列表通过响应式查询恢复当前可访问账本；归档、撤权或退出共享后会回到仍可访问的账本。

## 4. 路由与页面节点

路由定义在 `lib/app/router/app_router.dart`，所有页面共用 `ShellRoute → AppScaffold`。底部固定四个一级 Tab，中央 `+` 是全局快速记账入口；短按打开手动记账，长按打开语音记账。

| 路由 | 页面/功能 | 入口与主要联动 |
| --- | --- | --- |
| `/` | 首页 | 月度收支、今日安心可花、目标、洞察、趋势、分类、资产、最近流水 |
| `/transactions` | 流水 | 全部/支出/收入、分类筛选、搜索、分析入口、账单收件箱 |
| `/transactions/search` | 流水搜索 | 商户/分类/备注搜索；复用编辑、分类修正、删除操作 |
| `/transactions/inbox` | 账单收件箱 | 处理分类不确定、疑似重复、缺少账户 |
| `/transactions/reimbursements` | 报销管理 | 待报销/已报销汇总、关联回款和统一流水详情 |
| `/transactions/calendar` | 消费日历 | 月历日金额、当日流水和月份统计 |
| `/analysis` | 收支分析 | 周期/币种切换、现金流、分类构成、消费习惯与洞察 |
| `/goals` | 目标列表 | 进行中/已完成目标、新建目标、目标排序 |
| `/goals/:goalId` | 目标详情 | 编辑、阶段节点、存入/取出/调整、预测、庆祝 |
| `/profile` | 我的 | 会员、家庭、数据、通知、资产、分类、预算等入口 |
| `/profile/data` | 数据与安全 | 导出未删除流水 CSV；导出/恢复完整 SQLite 备份（恢复需重启应用） |
| `/profile/assets` | 资产总览 | 按币种资产/负债/净资产、资金形式、账户校准 |
| `/profile/accounts` | 账户管理 | 新增、编辑、归档/恢复、拖拽排序、余额校准 |
| `/profile/categories` | 分类管理 | 支出/收入、一级/二级、新增、编辑、排序、隐藏 |
| `/profile/budgets` | 预算管理 | 月度总预算、分类预算、使用率、日均可用 |
| `/profile/recurring-bills` | 周期账单 | 周期配置、到期自动记账、暂停/结束 |
| `/profile/installments` | 信用卡分期 | 分期计划、详情、每期还款登记 |
| `/profile/membership` | 会员与数据安全 | 后台 catalog 驱动的套餐/权益、微信/支付宝开通入口、订单记录和服务端会员状态 |
| `/profile/family` | 家庭/企业共享 | 登录、启用共享、邀请、成员、同步和冲突处理 |
| `/profile/payment-notifications` | 支付通知记账 | Android 通知权限、开关和待处理通知消费 |

底部导航的选中规则把 `/analysis` 归到“流水”，把目标详情归到“目标”，把个人页所有子路由归到“我的”。子页面返回优先使用 `context.pop()`，无历史时回到父级页面。

## 5. 数据库与数据结构

数据库定义在 `lib/core/database/app_database.dart`，当前 `schemaVersion = 15`，连接文件为应用文档目录下的 `haohao_jizhang.sqlite`。Android 使用当前 isolate 的 `NativeDatabase`，桌面端使用后台连接。开启了 SQLite foreign keys，并为交易、附件、目标、智能分类、家庭、账本、同步事件和广告事件创建索引。

### 5.1 核心业务表

| 表 | 作用 | 关键字段/关系 |
| --- | --- | --- |
| `accounts` | 账户与账面余额 | `balanceInCents`、币种、账户类型、资金形式、归档 |
| `categories` | 收入/支出分类 | 自引用 `parentId`，支持一级/二级和隐藏 |
| `transactions` | 统一流水事实 | 类型、金额、账本、账户、转入账户、分类、来源、软删除、同步/隐私/版本字段 |
| `transaction_attachments` | 交易附件记录 | 账本、交易、路径、文件名、MIME、顺序、大小/校验和预留字段、软删除 |
| `goals` | 财务目标 | 目标金额、当前金额缓存、目标日期、账本、排序、月度预留 |
| `goal_milestones` | 目标阶段节点 | 目标、金额、顺序、完成时间、庆祝状态 |
| `goal_contributions` | 目标贡献流水 | 存入/取出/调整、来源流水预留、贡献人 |
| `budgets` | 月预算 | `bookId`、月份、可选分类、金额；唯一约束按账本生效 |
| `recurring_bills` | 周期账单配置 | 周期、下次日期、账户/分类、自动记账、提醒和状态 |
| `installment_plans` | 信用卡分期计划 | 原始消费、期数、本金/手续费、信用卡/还款账户、剩余本金和状态 |
| `app_settings` | 本地偏好 | 当前账本、上次使用账户、seed 版本、首页洞察关闭状态 |

### 5.2 智能、家庭、广告表

| 表 | 作用 |
| --- | --- |
| `merchant_rules` | 个人商户记忆、精确规则、关键词规则 |
| `economic_events` / `economic_event_records` | 跨渠道同一经济事件候选及流水关联 |
| `inbox_items` | 分类不确定、疑似重复、缺少账户的待确认项 |
| `families` / `books` | 家庭协作空间与个人/家庭/企业账本模型；`assetSourceBookId` 指定是否共用主账本资产 |
| `family_members` | 家庭成员与角色 |
| `family_invitations` | 邀请码、状态、过期时间 |
| `family_operation_logs` | 家庭共享操作审计 |
| `family_budgets` | 家庭预算模型 |
| `ad_events` | 推广位展示、点击、完成、关闭等事件 |

### 5.3 迁移与种子

数据库迁移是 forward-only 的 1→15 版本链，不能删除数据库绕过迁移。8→9 会先保存数据库副本，再按流水净影响拆分非个人账本账户、重绑流水/分类/预算并校验余额守恒；9→10 创建同步表、版本、ID 映射、待同步队列、推广状态和 SQLite 变更触发器；10→11 创建独立附件表和索引，并把旧交易 `metadata.attachments` 中可识别的路径迁移为记录，malformed 项和其他 metadata 保留；11→12 为账本增加主账本资产来源字段；12→13 增加交易关联、报销和退款字段；13→14 创建周期账单表；14→15 创建分期计划表。`DatabaseSeeder` 当前 seed 版本为 5：新安装默认只创建空余额账户、默认分类、个人账本和商户规则；演示流水、演示目标和演示预算只有显式 `includeDemoData: true` 才写入。

## 6. 核心业务调用链

### 6.1 手动记账

```text
点击中央 +
  → QuickAddSheet
  → 金额/类型/账户/分类/时间/备注等校验
  → QuickBookkeepingService.save
  → TransactionRepository.createAll
  → SQLite transaction
       ├─ 写入 transaction
       └─ 按交易类型更新账户余额
  → 写入上次使用账户
  → TransactionAttachmentRepository.replaceForTransaction（有附件时）
       ├─ 写入/恢复独立附件记录
       └─ 对移除附件执行软删除
  → TransactionIntelligenceService
       ├─ 商户分类
       ├─ 指纹去重
       └─ 写入 inbox / economic event（必要时）
  → Riverpod stream 更新首页、流水、分析、预算、资产
```

`createAll` 支持语音多笔记账，同批次流水和账户余额在同一 SQLite transaction 中提交；后续设置、分类和去重属于提交后的本地处理，失败时通过 `BookkeepingCommittedException` 告诉页面“已入账但后处理失败”，避免用户无感知地自动重试造成重复记账。

### 6.2 编辑、删除、分类修正

- 编辑：流水行操作菜单复用 `QuickAddSheet(initialTransaction: ...)`；Repository 事务先撤销旧流水余额影响，再写新流水，再应用新余额影响。
- 删除：软删除，不物理删除；同时撤销账户余额影响，流水从 active stream 中消失。
- 分类修正：更新 `categoryId`、`userCorrected`；用户选择“记住商户”时额外写入个人精确规则。
- 搜索页和首页最近流水都复用同一个交易操作菜单。

### 6.3 账本节点

```text
BookSelectorButton
  → booksProvider / activeBookIdProvider
  → 顶部书架抽屉选择、创建类型、重命名、归档
  → app_settings.active_book_id
  → 账户/分类/预算/流水/目标/收件箱 Provider 按账本重新派生
```

账本类型包括 personal、family、enterprise；个人账本不会因登录自动上传，家庭和企业账本必须在书架抽屉中明确启用共享。Free/Pro/Family 自建账本数量上限分别为 3/20/50，受邀加入不占自建额度；服务端最终执行额度检查。创建后自动切换到新账本，切换期间页面不显示旧账本金额。

### 6.4 共享与同步节点

```text
SessionRepository（系统安全存储会话）
  → SharedFamilyService（登录、启用共享、邀请、成员权限）
  → SharedBookSyncService
      ├─ promotion：预留账本 → 上传初始快照 → 建立 ID 映射
      ├─ pull：按 cursor 拉取变化并在事务中应用
      ├─ push：按 operationId/expected version 提交待同步操作
      └─ conflict：暂停同一实体队列，用户选择服务端版本或基于最新版本重提
  → server/src/app.ts（Fastify 5）
  → server/src/store.ts（SQLite 事务、幂等收据、版本/余额/日志）
```

本地业务写入和 outbox 由 SQLite 触发器在同一事务内完成；共享账本前台每 15 秒检查，启动、恢复前台、手动刷新和保存后立即触发，后台不持续轮询。权限撤销或登录失效会停止提交并保留可处理的本地草稿。个人账本不进入共享快照。

### 6.5 目标节点

```text
创建目标
  → GoalMilestoneService.suggest
  → 校验节点必须包含最终目标金额
  → GoalRepository.create（目标 + 节点 + 初始贡献事务）

存入/取出/调整
  → GoalRepository.contribute / adjustCurrentAmount
  → goal_contributions 追加不可变记录
  → 根据新旧金额跨越 milestones
  → 更新目标状态与庆祝标记
  → GoalForecastService 用近 30/60/90 天净存入速度估算完成日
```

目标月度预留是用户显式开启的展示/预算口径，不会移动账户资金，也不会自动生成目标存入流水。

### 6.6 预算与首页“今日安心可花”

预算按当前月份统计 CNY、未删除、已发生且属于支出的交易：

```text
本期可用支出 = 月预算 - 已支出 - 进行中目标月度预留
今日安心可花 = max(0, 本期可用支出) ÷ 含今天的剩余天数
```

支持总预算、分类预算、父分类匹配子分类、正常/接近预算/超预算状态。未来计划支出、固定账单、周期支出和自动扣款尚未进入公式。

### 6.7 收支分析节点

`StatisticalAnalysisService` 以当前账本流水为输入，在 Dart 内存中计算：

- 7 天、30 天、90 天、本月、上月、本年范围。
- 总收入、总支出、结余、笔数和按日/按月现金流趋势。
- 收入来源和支出分类金额、笔数、占比。
- 剔除大额一次性/资产购置后的日常消费。
- 7×24 热力图、七段时间分布、分类趋势、频次/客单价归因。
- 深夜、外卖/分类增加等可解释洞察。
- 7/30/90/180 天个人行为基线。

分析页先展示“收支分析”，下方再展示“消费习惯”，入口来自流水工具栏和首页月度摘要。

## 7. 各 Feature 当前状态

| Feature | 当前真实能力 | 当前边界 |
| --- | --- | --- |
| `home` | 首页真实派生月度收支、安心可花、目标、洞察、趋势、分类、资产和最近记录 | 依赖全量内存派生；安心可花未纳入未来账单 |
| `transactions` | 流水筛选、分类筛选、搜索、编辑、分类修正、软删除 | 没有月份/账户等更细筛选；全量加载 |
| `bookkeeping` | 手动支出/收入/转账、数字键盘、计划/一次性/周期、标签、独立附件记录 | OCR 未接；附件文件仍只保存本地路径，文件内容未进入备份/同步；扩展交易类型没有独立体验 |
| `books` | 书架抽屉选择、新建 personal/family/enterprise、重命名、归档、数量限制 | 公网部署和正式权益服务未接入 |
| `accounts` | 新增、编辑、归档/恢复、排序、资产/负债/资金形式、按账本余额校准 | 不支持跨账本直接转账 |
| `categories` | 收入/支出、一级/二级、新增、编辑、排序、隐藏默认分类 | 没有批量导入/导出分类 |
| `budgets` | 按账本的总预算、分类预算、使用/剩余/日均可用、目标预留联动 | 无周期支出计划 |
| `goals` | 创建、17 类目标、动态节点、贡献、调整、排序、预测、完成庆祝、封面 | 目标贡献与交易只预留 `sourceTransactionId`，没有自动资金关联 |
| `analysis` | 收支面板与消费习惯面板真实计算 | 全量拉取后内存计算，数据量大时需要 SQL 时间窗口/分页优化 |
| `intelligence` | 商户分类优先级、个人记忆、指纹去重、经济事件候选、账单收件箱 | 没有独立账单导入入口；经济事件不等于自动消除统计重复 |
| `data_export` | 导出未删除流水 CSV，带 BOM、字段转义和公式注入保护；可校验并恢复完整 SQLite 备份，包含独立附件记录 | 恢复采用待启动替换，不含独立附件文件；备份没有加密/密码保护 |
| `voice` | Android/iOS 语音接口抽象、设备端优先、规则解析、多笔确认保存 | 云 ASR/LLM 未接；当前生产 Provider 的 AI parser 为 `null`，AI 文本入口实际仍是规则解析 |
| `notifications` | Android NotificationListenerService、权限设置、微信/支付宝/云闪付解析、幂等自动记账 | iOS 不支持；不识别通知保留在原生队列，没有完整人工导入修正流程 |
| `membership` | Free/Pro/Family 模型、后台 catalog、微信/支付宝 APP 支付订单、回调验签、会员状态和购买记账幂等逻辑 | 真实商户证书、公网 HTTPS 回调、移动端登记配置仍需部署联调 |
| `family` | 真实登录、共享启用、邀请、成员角色、撤权和同步状态页 | 仅本地 Node 后端联调；公网/TLS/生产运维未接 |
| `ads` | 内部推广位配置、受众/频控/内容安全策略、本地事件记录 | `AdProvider` 是 `UnconfiguredAdProvider`；无第三方 SDK、后台配置和真实 Rewarded/Splash |
| `profile` | 真实汇总入口、会员/家庭/安全/通知/资产/分类/预算导航、连续记账天数 | 提醒设置没有实际能力；帮助只有本地说明弹窗 |

## 8. Android/iOS 平台节点

Android：

- 包名 `com.algive.jizhang_app`，Java/Kotlin 17，Flutter embedding v2。
- 声明录音权限、网络权限和 Notification Listener Service。
- `MainActivity.kt` 通过 `jizhang/payment_notifications` MethodChannel 暴露权限、开关、读取队列和确认接口。
- `PaymentNotificationListenerService.kt` 只接收微信、支付宝、云闪付通知，过滤支付关键词后写入 `SharedPreferences` 队列。
- `PaymentNotificationStore.kt` 去重并把待处理通知限制在 100 条。
- 已配置中文应用名、自适应图标、圆形图标、单色图标和暖色启动页；图标资源统一从 `assets/images/icon.png` 生成。
- Release 没有正式 keystore 时使用 debug signing，仅适合本地验收，不适合上架。

iOS：

- Flutter/iOS 工程目录存在，Dart 侧语音服务有跨平台抽象。
- 当前机器 `xcode-select` 指向 CommandLineTools，`xcodebuild` 不可用；本轮没有可重复的 iOS 构建、签名、真机或支付能力验收。
- Android 专属支付通知能力在 iOS 上会返回不可用。

## 9. 测试与验证证据

本轮实际执行：

```text
flutter analyze
→ No issues found

flutter test --reporter compact
→ All tests passed（230 个）

flutter build apk --release
→ Built build/app/outputs/flutter-apk/app-release.apk（77,656,758 bytes）

server: npm run typecheck && npm test && npm run build
→ typecheck、2 个真实 HTTP 测试、TypeScript build 全部通过
```

当前 APK 文件：`build/app/outputs/flutter-apk/app-release.apk`，大小 77,656,758 bytes，SHA-256 为 `ea3a57599c3b5d1d52598bb93ce2eae304d89130676d31b77fdce80b54464de1`。

此前交易详情切片的历史 Release APK 曾在 Pixel 7 Android emulator 安装并打开：[首页截图](../../qa/home-book-icon-2026-09-09.png)、[立体书架抽屉截图](../../qa/bookshelf-book-icon-2026-09-09.png)、[系统桌面图标截图](../../qa/launcher-book-icon-2026-09-09.png)。本次阶段二 Release APK 未安装；启动图标统一源为 `assets/images/icon.png`。

测试覆盖数据库、seed、Repository、余额事务、目标、预算、分析、智能分类/去重、会员记账幂等、支付通知、语音解析、家庭策略、广告策略、核心路由和小屏/大字体 Widget 布局。

测试期间出现 Drift 的 debug warning：Widget 审计测试重复创建内存数据库实例。它没有导致测试失败，但后续可统一测试容器生命周期或显式关闭测试数据库，减少噪声并避免未来误用同一 executor。

## 10. 需要优先关注的架构风险

1. **数据规模边界**：流水、分析和去重使用 `watchAll/getAll` 全量读入；新流水去重会与全部历史逐条比较，长期使用需增加 SQL 时间窗口、分页和索引查询。
2. **AI 入口语义容易误导**：`CachedRetryingAiTransactionParser` 和严格 JSON decoder 已存在，但没有真实 `AiParsingGateway` Provider 注入；“AI 记账”当前不能调用云端模型。
3. **外部系统范围**：共享后端只完成本地双端联调；公网部署、TLS、会员授权、订单验签、对象存储、云 ASR/LLM、第三方广告和生产埋点仍需要独立协议与测试环境。Android 后台任务已接入，但 iOS 后台策略和系统通知仍需平台验收。
4. **完整备份仍有边界**：用户卸载应用可能丢失本地数据库；当前 SQLite 备份虽包含独立附件记录，但不包含文件内容，也没有加密/密码保护。
5. **文档有历史漂移**：旧状态记录已移到 `docs/development/archive/audits/DEVELOPMENT_STATUS_legacy.md`，其中仍有旧 schema 和测试数字；后续以本文件、`CURRENT_STATUS.md` 和带日期的实施记录为准。
6. **发布准备未完成**：Android 正式签名、隐私/通知权限说明、iOS Xcode/Team/Bundle ID、真机语音识别和通知适配仍需单独验收。
7. **构建工具链提示**：`speech_to_text` 当前仍使用 Kotlin Gradle Plugin；本轮 Release 构建成功，但后续需随插件迁移到 Built-in Kotlin。

## 11. 下一窗口建议入口

如果继续开发，建议按以下顺序选一个切片，不要同时扩展多个外部系统：

1. 设计并实现“数据库＋附件文件”的版本化备份、校验、加密和可回滚恢复。
2. 优化流水和分析的查询边界，再增加月份、账户等筛选。
3. 完成押金/结算模型和账本模板后，再把附件纳入共享同步协议。
4. 如要开通 AI/会员/支付/广告，先取得真实服务端协议、测试环境和密钥托管方案；客户端不内置供应商秘密。
5. 每次修改 Drift 表必须提升 schema version、补 forward-only migration、重新生成 `app_database.g.dart` 并新增升级测试。

本文件是当前项目的架构交接基线；功能实现以源码为准，外部联调状态必须单独记录“代码完成但未实际联调”。

## 12. 页面入口可达性审计（2026-09-08）

### 12.1 已有正常入口，但层级较深的页面

| 页面/路由 | 当前入口 | 入口问题 |
| --- | --- | --- |
| `/profile/assets` 资产总览 | 首页“净资产”卡片；我的 → 账户与资产 | 入口存在，但账户管理没有在“我的”中单独列出 |
| `/profile/accounts` 账户管理 | 资产总览底部“管理账户与排序” | 只能从资产总览二次进入，容易被误认为没有页面 |
| `/goals/:goalId` 目标详情 | 目标列表卡片；首页目标卡片 | 动态路由，没有独立菜单项，必须先进入目标列表或首页目标卡片 |
| `/transactions/search` 流水搜索 | 流水页搜索按钮；首页搜索按钮 | 仅通过图标按钮进入 |
| `/transactions/inbox` 账单收件箱 | 流水页“账单收件箱”入口 | 不在底部导航中 |

### 12.2 当前没有独立页面或入口的功能

- `features/settings/data/app_settings_repository.dart` 只有设置数据访问层，没有设置页面。
- 个人页中的“提醒设置”是不可点击的 `_MenuItem`，显示“暂未开启”，不是隐藏路由。
- `BookSelectorButton` 和账本管理是首页顶部“我的账本”下拉 Sheet，不是独立账本页面。
- 快速记账和语音记账是底部中央 `+` 按钮的 Sheet；语音入口通过长按触发。

### 12.3 发现的无效/未接入路由配置

`features/ads/data/placement_repository.dart` 为广告策略预留了 `/splash` 和 `/analysis/reward`，但 `app_router.dart` 没有注册这两个路由；当前内置配置也没有使用它们，因此暂时不会被普通用户触发。若以后启用对应广告位，必须先补页面或改成已注册路由，避免点击后进入 404。

结论：当前已注册的业务 Page 基本都能从正常 UI 到达；最容易被遗漏的是“资产总览 → 账户管理”的二级关系。真正缺少入口的是提醒设置，以及尚未接入页面的广告预留节点。
