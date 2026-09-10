# 好好记账完成度审计

审计日期：2026-09-01  
审计范围：`docs/DEVELOPMENT_STATUS.md`、阶段四至阶段十三原始需求、`lib/` 真实调用链、测试与构建产物。  
审计方式：按 correctness、architecture、security、performance、maintainability 五个维度核对；重点检查“页面入口 → Provider → Service → Repository/数据库”的闭环，而不是只看类型或单元测试是否存在。

## 结论先行

当前工程已经是一个可运行的本地记账 MVP，但不能把阶段四至阶段九全部标为“完成”，也不能把阶段十至阶段十三理解为可交付的商业版本。

- 本地持久化、手动快速记账、账户余额联动、预算、目标和部分统计规则已经具备真实实现。
- 阶段六、八、九存在“底层代码有了，但产品闭环或需求细节未完成”的情况。
- 阶段十至十三的认证/支付/云同步/家庭共享/云 AI/第三方广告均未完成真实联调；当前实现是本地基础、契约和安全拒绝边界。
- 首次启动自动写入演示流水、演示目标并修改账户余额，是最高优先级的数据正确性问题。真实用户会看到并非自己产生的财务记录。
- 当前机器上的 iOS 构建不能复现：`xcode-select` 指向 Command Line Tools，`xcodebuild` 不可用；状态文档中“iOS Simulator 构建通过”应视为历史产物记录，而不是本次可重复验证结果。

因此，建议对外状态改为：**本地记账核心可演示；统计、智能分类和管理功能部分完成；商业、家庭、云 AI、广告尚未交付；尚未达到完整产品开发目的。**

## 阶段完成度

| 阶段 | 审计结论 | 尚未达到的开发目的 |
| --- | --- | --- |
| 四 持久化数据基础 | 基本完成 | 默认 seed 污染和 currency 写入问题已修复；多币种输入/汇总 UI 仍未达成。 |
| 五 快速记账 | 本地基础基本完成 | 已补流水编辑/删除和搜索操作；OCR 入口仍未接 API，附件详情和扩展交易类型专用编辑仍未完成。 |
| 六 账户、分类和预算 | 部分完成 | 账户排序与资产/负债汇总已补齐；多币种资产换算和更完整的负债偿还规则仍未完成。 |
| 七 财务目标 | 基本完成 | 目标与贡献底层闭环较完整；`sourceTransactionId` 仍只是预留，流水与目标没有真正自动关联；首页优先目标选择规则未显式提供。 |
| 八 统计洞察 | 部分完成 | 时间段边界和结构化 Insight 字段已补齐；异常检测仍没有完整的持续时长/次数判定，统计仍全量加载到内存。 |
| 九 智能分类与去重 | 部分完成 | 手动/语音保存和收件箱决策已接通；当前没有独立账单导入入口，经济事件的服务端同步与复杂合并仍未完成。 |
| 十 商业基础 | 未完成（仅客户端基础） | 认证、服务端会员、订单幂等、微信支付、Apple IAP、回调验签、对象存储、云同步和真实导出/备份均未联调；当前 Provider 永远返回本地 Free。 |
| 十一 AI 语音记账 | 本地规则部分完成 | 设备语音和规则解析可用；没有云 ASR/LLM Gateway，Provider 没有注入 AI parser，因此即使未来有权益也不会从当前生产 Provider 发起 AI 解析。真机权限、噪音和中文识别未验收。 |
| 十二 家庭共享账本 | 未完成（仅模型/策略） | `UnconfiguredFamilyService` 会明确拒绝所有服务端操作；无真实建家、邀请、接受、成员管理、共享账本和跨设备同步。 |
| 十三 广告与推广位 | 未完成（内部推广部分完成） | `AdProvider` 为 `UnconfiguredAdProvider`；无第三方 Splash/Native/Rewarded、远程 Placement、生产埋点、真实广告退出事件；“新用户 24 小时”使用固定 2020 年用户时间。 |

## 必须修复（Critical / Required）

### 1. 首次启动写入假流水并改变余额（Critical，已修复）

`lib/core/database/database_seeder.dart:240-328` 在首次初始化时无条件写入瑞幸、滴滴、盒马、工资、美团等演示交易，并同步调整账户余额；`_seedGoal` 也无条件创建“买车计划”。这不是可选 Demo 模式，而是真实用户的默认账本数据。

影响：余额、首页汇总、预算、分析、深夜消费洞察和目标进度全部被污染，用户无法区分系统数据与本人数据。

处理：默认只创建空余额账户、默认分类和个人账本；演示数据改为显式 `includeDemoData: true`，并增加 seed v5 迁移和“新装后无交易、余额为零”测试。

### 2. 已保存流水无法从产品界面完整编辑或删除（Required，已修复）

`lib/features/transactions/presentation/transactions_page.dart:106-207` 点击流水只打开“修改分类”弹窗，不能编辑金额、类型、账户、时间、商户、备注或删除。`lib/features/transactions/presentation/transaction_search_page.dart:110-118` 的搜索结果连点击回调都没有。Repository 虽有 update/softDelete，但没有形成用户可用的 UI 闭环。

影响：阶段五要求的“编辑/删除/重启后验证”只在底层测试层面成立，实际用户无法纠错金额或撤销误记。

处理：新增交易操作菜单，编辑复用快速记账表单，删除使用软删除并同步撤销余额；搜索结果复用同一菜单，并增加 Widget/Service 回归测试。

### 3. 转账被日期分组统计为支出（Required，已修复）

`lib/core/widgets/transaction_date_group.dart:23-25` 用 `!item.isIncome` 计算 spending，因此 transfer、adjustment 等所有非收入类型都会被算入“支出”。转账本身不应进入收入或支出汇总。

处理：日期分组支出已改为 `item.isExpense`，并增加转账不计入收入/支出的 Widget 测试。

### 4. 货币字段在模型与写入层丢失（Required，已修复基础链路）

数据库表有 currency 字段，但 `lib/core/models/transaction_record.dart:20-87` 没有 currency；`lib/features/transactions/data/transactions_repository.dart:227-235` 每次写入都固定 `currency: 'CNY'`。这会把未来或导入的非 CNY 交易静默改写为 CNY。

处理：已在领域模型、Repository、快速记账请求/更新和回归测试中贯通 currency；当前输入和汇总展示仍以 CNY 为默认，非 CNY 的编辑/多币种汇总 UI 另列为后续工作。

### 5. 首页“较平时 +0%”是固定值（Required，已修复）

`lib/features/home/data/home_data.dart:29-48` 计算了本月深夜消费金额，但 `increasePercent` 永远为 `0`。截图中因此显示“较平时 +0%”，不能反映基线比较，也与阶段八的行为洞察目标不一致。

处理：首页改用 `StatisticalAnalysisService` 的 30 天深夜行为基线计算 delta；没有足够历史样本时显示“暂无基线”，并且正负变化使用正确符号。

### 6. 智能分类/去重没有接入真实保存链路（Required，已修复本地链路）

审计时 `TransactionIntelligenceService` 只在服务和测试中出现，生产手动/语音保存未调用；当时 `BillInboxPage` 也只能把条目标为 dismissed/accepted。

处理：`QuickBookkeepingService.saveAll` 统一执行分类 → 指纹检查 → 待确认箱，手动和语音入口复用；收件箱可修改分类并记住商户，可确认重复后软删除当前流水，或确认跨渠道经济事件关联。当前没有独立导入入口，服务端事件合并仍未联调。

### 7. 统计时间段和 Insight 契约不符合原始需求（Required，已修复基础契约）

审计时 `StatisticalAnalysisService` 只有六段，边界是 00–06、06–11、11–14、14–18、18–22、22–24；这会把 05–06、08–11、17–18 分错。

审计时 `AnalysisInsight` 只保留 id/type/title/description/metric/current/baseline/change/reason/category 等字段，缺少结构化事实；异常主要是当前期与上一期的阈值比较，未完整实现持续时长/次数维度。

处理：时间段已对齐为 00–05、05–08、08–11、11–14、14–17、17–22、22–24；`AnalysisInsight` 已补齐 period、amount、baselineAmount、deltaAmount、deltaPercent、timeSegment、metadata 和 generatedAt。异常持续时长/次数模型仍是后续工作。

### 8. 账户“排序”在状态文档中被宣称完成，但没有实现（Required，已修复）

处理：`AccountRepository.reorder` 和 `AccountDao.reorderActive` 已加入，账户管理页提供持久化拖拽排序。

此外，账户页和个人页现在分开统计资产与信用卡/liability 负债，负债不会再直接计入总资产；多币种换算和更细的负债偿还规则仍需明确业务口径。

### 9. 已展示的个人功能仍是占位（Required）

`lib/features/profile/presentation/profile_page.dart:47-79, 292-309` 中“数据与安全”“提醒设置”“帮助与反馈”没有路由，点击只提示“尚未实现”；`_ProfileHero` 在约 190 行将连续记账天数固定为 `28 天`。会员仓储 `LocalOnlyMembershipRepository` 永远返回 Free，并授予 dataExport/basicBackup 权益，但代码中没有真实导出、备份、恢复流程。

建议：未实现功能从正式入口隐藏或明确标记 Beta；实现数据导出/备份/恢复后再授予对应 entitlement，并根据真实流水计算连续记账天数。

## 外部联调未完成（不能标记为交付）

以下不是单纯补 UI，而是需要服务端、供应商账号、协议和密钥管理方案：

- 商业：登录/认证、会员状态、订单幂等、微信支付、Apple IAP、Webhook 验签、PostgreSQL、对象存储、云同步。
- AI：云 ASR、LLM JSON 解析网关、额度扣减、缓存/重试的真实请求与监控。当前 `voiceTransactionParserProvider` 只注入规则 parser，未注入 AI parser。
- 家庭：服务端角色鉴权、邀请生命周期、共享/私有数据隔离、版本冲突合并、操作日志同步。
- 广告：第三方 SDK、Splash/Native/Rewarded 实际展示、placement 后台配置、同意/隐私流程、生产事件上报。当前 `adProviderProvider` 返回 `UnconfiguredAdProvider`，只能用于测试“不展示”。

在获得服务端协议、测试环境、供应商应用 ID 和密钥托管方案之前，不应把这些能力改写成“已完成”。

## 质量与维护风险（Optional / Nit）

- 本地 SQLite 和附件文件没有看到加密、导出恢复校验或隐私擦除策略；“数据与安全”目前只能理解为本地保存，而不是完整安全方案。
- 分析和部分智能去重通过 `getAll()` 后在 Dart 内存遍历，流水页也没有分页；小数据可用，云端或长期账本会出现启动、内存和响应时间问题。
- `quick_add_sheet.dart` 超过 1,100 行，`app_database.dart`、`goal_detail_page.dart` 也较大；继续扩展前应按表单/领域拆分并补组件级测试。
- `README.md` 已同步为 Drift/SQLite 现状；后续大规模数据仍需分页、时间窗口查询和更细的性能基准。
- `DashboardSnapshot.forecastBalance` 实际是本月已发生收入减支出，却在首页标为“本月预计结余”；没有未来计划数据时应改名为“本月结余”或补充真正预测模型。
- 保存语音流水后，商户规则修正发生在保存事务之外；规则写入失败可能让用户看到保存失败并重复提交，需要明确幂等和错误提示策略。

## 已验证项目

在当前工作区重新执行：

- `flutter analyze`：通过，`No issues found`。
- `flutter test`：65/65 通过。
- `flutter build apk --release`：通过，生成 61.2 MB APK；构建仍提示 `speech_to_text` 自行应用 Kotlin Gradle Plugin 的未来兼容警告。
- APK SHA-256：`f336bca978ec8da606678c538188c24d21133db3114a8f9bb3dbe2e252134dc3`。
- `flutter build ios --simulator --debug`：当前失败，原因是 `xcrun` 找不到 `xcodebuild`；`xcode-select -p` 为 `/Library/Developer/CommandLineTools`。工作区中仍有历史 `build/ios/iphonesimulator/Runner.app` 和截图，但本轮不能把它们当作可重复构建证明。
- 项目根目录没有 `.git`，无法通过提交历史确认状态文档所述改动的版本来源。

## 后续建议实施顺序

1. 增加真实账单导入入口，并复用现有保存后的分类/指纹/收件箱管线。
2. 为异常洞察补充持续时长/次数判定，随后将分析与去重改为按时间窗口/分页查询。
3. 实现数据导出、备份/恢复和提醒/帮助等当前占位入口，再按真实流水计算连续记账天数。
4. 取得服务端协议和测试环境后，推进商业、云 AI、家庭共享和广告 SDK 外部联调。
5. 配置完整 Xcode、iOS Signing、Android production keystore 后，再做真机、Archive、隐私权限和发布验收。

## 新窗口继续工作的起点

先阅读本文件、`docs/DEVELOPMENT_STATUS.md`、`docs/STAGE_10_ASSET_AUDIT.md` 及阶段原始需求。后续改动先从账单导入、异常持续模型或导出/备份中选择一个切片，完成后重新运行 `flutter analyze && flutter test && flutter build apk --release`，并在有完整 Xcode 后重新验证 iOS。

## 2026-09-01 首批修复记录

- 默认 `DatabaseSeeder.seedIfNeeded()` 只创建空余额账户、默认分类和个人账本；演示流水、目标、预算和初始余额改为 `includeDemoData: true` 显式启用。
- seed version 升至 v5；旧版本数据库会按固定 seed ID 软删除演示流水、删除演示目标并撤销演示初始余额。
- 流水操作菜单已接入列表和搜索结果，支持复用快速记账表单编辑，以及软删除并同步余额。
- 日期分组支出改为按 `TransactionRecord.isExpense` 统计，转账不会再计入支出。
- `TransactionRecord.currency`、Repository 和快速记账更新链路已贯通，新增 USD/EUR 持久化回归测试。
- 新增默认干净 seed、旧 seed 清理、交易编辑、转账统计和流水操作 Widget 测试；首批修复后全量测试由 54 个增至 62 个并通过。

## 2026-09-01 统计、智能链路与账户管理修复记录

- 首页深夜洞察复用统计服务 30 天基线；无历史样本时不再显示固定 `+0%`。
- 统计时间段改为七段精确边界，并扩充结构化 `AnalysisInsight` 字段与回归测试。
- 快速记账保存后的手动/语音流水统一经过商户分类、重复指纹和待确认箱；转账/调整不会误入分类收件箱。
- 收件箱支持分类修正/记住商户、重复流水软删除和跨渠道经济事件确认关联。
- 账户支持 Repository/UI 持久化拖拽排序；资产页和个人页分离资产与信用卡/liability 负债。
- 全量 `flutter analyze` 与 `flutter test` 通过，测试数量增至 65 个。

本轮仍未解决本报告中的账单导入入口、异常持续时长模型、导出/备份、分页和阶段十至十三外部服务问题。
