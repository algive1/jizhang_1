# 全项目检查报告 · 2026-10-07

本轮检查对象是 `E:\jizhang_1\repo` 当前工作区，包含尚未提交的修改与新增文件。按用户提供的 AGENTS.md，本轮只检查、复现和给出修复范围，未修改业务实现。测试和构建生成了本地日志、截图及构建产物。

## 检查结论

- 没有发现 Git 未合并文件或源码合并冲突标记；但存在业务逻辑、前后端接入、数据库初始化和测试契约之间的不一致。
- **优先修复两项数据问题：账单收件箱记录可能被覆盖；美元行情被保存成人民币。**
- 投资前台每日快照不执行、广告事件 ID 冲突、新数据库缺少查询索引，均有实际复现或现有测试证据。
- **8 个页面的布局溢出在中文字体复查中仍可复现**；另 1 个普通账户表单问题仅在默认测试字体下出现，待真机确认。还有 **2 个页面存在 Material 绘制层问题**。主要触发条件为 320dp 小屏、1.6 倍字号，部分问题还与深色玻璃主题有关。
- 服务端、后台浏览器回归、Android 原生单元测试通过；Flutter 回归仍有 44 项失败，不能将当前状态视为完整回归通过。

优先级：P1 为数据正确性或记录丢失；P2 为功能失效、策略不一致、明显布局问题或关键回归缺口；P3 为文案及后续维护项。

## 实际执行结果

| 检查 | 结果 | 说明 |
|---|---|---|
| Git 未合并文件、冲突标记、差异空白检查 | 未发现冲突 | 审查当前工作区，没有清理、回退现有修改 |
| Flutter 静态分析 | 1 条 info，命令未通过 | 临时截图测试的多余 import；业务代码无 analyzer error |
| Flutter 回归 | **815 通过 / 44 失败** | 170 个测试文件；另一个机器专用截图脚本未执行 |
| App 全路由诊断 | 66 个路由，每轮 264 次页面访问，共两轮 | 393dp/正常字号、320dp/1.6 倍字号，分别检查浅色与深色主题；第二轮加载 Windows 中文字体。诊断脚本收集异常，不以脚本完成代替页面通过 |
| 投资窄屏专项复查 | 失败 | 320×700、1.6 倍字号，手动添加表单横向溢出 63px；中文字体 320×844、浅色/深色也确认相同溢出 |
| 收件箱并发诊断 | 失败 | 40 次写入仅 11 个唯一 ID、11 条实际记录 |
| 投资币种端到端诊断 | 失败 | 行情 USD → 显示 ¥ → 保存 CNY |
| 投资快照执行诊断 | 确认缺陷 | 持仓流打开时调用 0 次，关闭流后才调用 1 次 |
| 服务端 typecheck / 测试 | 通过 / **82 项通过** | 包含权限、账户、同步、支付退款、配置、AI、工单等本地测试 |
| 后台 lint / 生产构建 | 通过 / 通过 | Vite 提示较大分包，属于性能维护项 |
| 后台 Playwright 业务回归 | **9 项通过** | 使用隔离的内存测试服务，覆盖实际本地 API 和交互 |
| 后台全菜单诊断 | **31 个入口 × 2 个宽度通过** | 1440px、390px，未出现 pageerror、API 5xx 或整页横向溢出 |
| Android 原生单元测试 | **109 项通过** | 支付页面解析、状态机、去重、确认门控、扫描节流等 |
| Android 调试 APK 构建 | 通过 | 没有运行会增加版本号的打包脚本 |

本机没有连接 Android 设备，也没有 Docker 或 macOS 构建环境。本轮没有执行真实支付、真实退款、供应商 AI/ASR/行情调用、APNs、生产部署和真机辅助服务运行。相应的本地测试或模拟供应商测试不等于线上实测。

## 已确认的问题与关联范围

### F01 · P1：收件箱 ID 碰撞会静默覆盖待处理账单

位置：[bill_inbox_repository.dart](/E:/jizhang_1/repo/lib/features/intelligence/data/bill_inbox_repository.dart:75)、[app_database.dart](/E:/jizhang_1/repo/lib/core/database/app_database.dart:3590)。

新增条目只使用 `DateTime.now().microsecondsSinceEpoch` 作为 ID，而数据库使用 `insertOnConflictUpdate`。时间戳不保证每次调用唯一，碰撞时覆盖上一条记录，而非报错。

**复现：并发提交 40 条不同 payload 的 missingAccount 待处理记录，返回 40 个结果，但唯一 ID 和数据库记录都只有 11 个。** 这是当前 Windows/Dart 测试环境中的实测数量；其他设备碰撞频率可能不同，不能依赖时钟精度保障正确性。

影响收件箱、缺失账户待确认、模糊分类、重复账单复核，以及调用这些入口的导入/自动记账链路。修复应复用项目现有 `newEntityId()`，并检查同类时间戳 ID：经济事件、商户规则也存在这一写法，后两者目前只确认代码风险，未单独复现。

验收：高频并发与快速连续新增后，返回条数、唯一 ID 数和实际记录数一致，各 payload 完整保留。

### F02 · P1：投资搜索丢失币种，外币行情按人民币保存

位置：[investment_add_page.dart](/E:/jizhang_1/repo/lib/features/investments/presentation/investment_add_page.dart:266)、[保存请求](/E:/jizhang_1/repo/lib/features/investments/presentation/investment_add_page.dart:790)、[默认币种](/E:/jizhang_1/repo/lib/features/investments/data/investment_repository.dart:38)。

搜索结果带有 `currency`，选中后只向表单传递名称、代码、价格和资产类型。表单创建请求没有币种参数，默认为 CNY；搜索行还固定展示 `¥`。

**复现：Mock 行情返回 BTC = USD 100，搜索行显示 ¥100.00；买入 1 个后，数据库持仓币种为 CNY。** 正式 HTTP 行情接口同样允许返回外币，丢失信息发生在共用页面链路。

此外，[investment_portfolio.dart](/E:/jizhang_1/repo/lib/features/investments/domain/investment_portfolio.dart:110)直接将不同持仓金额相加，组合默认标记 CNY。详情、交易弹窗和趋势图部分金额也固定使用人民币符号。只修复保存参数会暴露混合币种相加的问题，因此必须一起处理。

影响搜索添加、持仓数据、成本/盈亏、投资总览、每日快照、计入首页净资产、绑定账户的交易镜像。最小一致方案是保留原币种并按币种分别统计；若需要折算，须定义明确汇率及时间规则后再汇总。现存已错标币种的数据不能无条件批量改写。

验收：USD 行情在搜索、保存、详情、账户流水中均保留 USD；CNY 与 USD 不直接相加或冒充人民币总额。

### F03 · P2：投资前台快照调用位于无限流之后，不会执行

位置：[investment_repository.dart](/E:/jizhang_1/repo/lib/features/investments/data/investment_repository.dart:869)。

`investmentPortfolioProvider` 先 `yield* repository.watchPortfolio()`，之后才执行 `ensureTodaySnapshot()`。持仓监听是持续数据库流，正常使用期间不会结束。

独立诊断使用保持打开的持仓流：收到组合数据后，快照调用仍为 0；只有关闭流之后才变成 1。与注释声称的“首次打开投资管理写当天快照”不一致。后台日任务有另一个调用，但不能保证前台补点。

影响投资管理趋势、每日历史点以及依赖该历史数据的资产展示。修复需调整调用顺序，处理首次持仓加载和异常，并确保写入成功后趋势缓存能刷新；保持一次每日快照的既有语义。

### F04 · P2：新建数据库与升级数据库的索引不一致

位置：[onCreate](/E:/jizhang_1/repo/lib/core/database/app_database.dart:753)、[升级路径](/E:/jizhang_1/repo/lib/core/database/app_database.dart:972)、[索引定义](/E:/jizhang_1/repo/lib/core/database/app_database.dart:1040)。

schema 已是 25。升级到 24 的分支安装 `_createTransactionLookupIndexes()`，新建数据库的 `_createIndexes()` 没有调用它。新安装用户缺少：

- `idx_transactions_related_type`
- `idx_transactions_reimbursement_status`
- `idx_transactions_type_occurred`

现有 `database_repository_test.dart` 对真实索引列表的检查失败，属于有效缺陷，不是旧版本号断言。影响关联流水、报销状态和按类型查询的性能，新老用户表现不一致。修复应统一初始化/升级入口，并考虑已经建好的 v25 数据库如何补齐。

### F05 · P2：广告事件 ID 重复导致数据库写入异常

位置：[placement_repository.dart](/E:/jizhang_1/repo/lib/features/ads/data/placement_repository.dart:255)。

广告事件同样仅使用微秒时间戳做 ID。全量回归中的曝光、点击、退出连续写入测试出现 `UNIQUE constraint failed: ad_events.id`。与 F01 的区别是这里插入失败，而不是静默覆盖。

影响广告曝光计数、每日展示上限、点击/退出记录及可能等待写入结果的 UI 流程。采用统一唯一 ID，并验证事件完整持久化；不要用吞掉异常掩盖数据缺失。

### F06 · P2：后台会员策略与部分本地功能入口未接通

位置：[服务端策略](/E:/jizhang_1/repo/server/src/payment.ts:294)、[客户端访问服务](/E:/jizhang_1/repo/lib/features/membership/data/membership_repository.dart:229)、[自动记账开关](/E:/jizhang_1/repo/lib/features/autobookkeeping/presentation/auto_bookkeeping_page.dart:105)。

后台会返回 automatic_bookkeeping、asset_reports、data_export 等功能策略，App 也有 `membershipFeatureAccessServiceProvider` 和统一校验帮助函数。但检查调用链后发现，自动记账开关/策略和本地自动保存链路没有读取会员策略；分析、资产及导出页面也没有使用上述统一功能门控。后台改变这些配置不能保证相应本地功能行为改变。

这是静态调用链确认的前后端接入缺口，尚未执行收费模式的真机开关验证。云备份和共享功能另有 entitlement 检查，不能概括成所有会员控制都失效。Debug 默认免费、Release 默认校验的测试开关已经存在，本轮没有把旧的“全版本默认免费”问题重复列为现有缺陷。

影响会员套餐/权益后台、会员页、自动记账、资产报表、数据导出和助手中的升级引导。开发前需统一哪些本地能力属于免费能力、哪些受后台开关控制；接入时同时校验入口和实际执行服务。

### F07 · P2：快捷功能与更多服务的 ListTile 绘制层不正确

位置：[profile_quick_actions_page.dart](/E:/jizhang_1/repo/lib/features/profile/presentation/profile_quick_actions_page.dart:363)、[profile_services_page.dart](/E:/jizhang_1/repo/lib/features/profile/presentation/profile_services_page.dart:72)。

两页将 ListTile 放入有背景色的玻璃 DecoratedBox 中，最近的 Material 在装饰层外。浅色正常字号即可复现 Flutter 的 `ListTile background color or ink splashes may be invisible` 断言。该诊断不是缺少根 Scaffold：复现使用了真实 App 路由。

Release 不会显示这一 debug 断言，但点击涟漪或背景绘制仍可能被遮住。修复应在组件内部提供正确的 Material/Ink 绘制层，与玻璃表面保持一致。

### F08 · P2：8 个页面的布局溢出已复核，另 1 项待确认

全路由检查主要条件为 **320×844、字号 1.6**。投资专项另覆盖 **320×700、字号 1.6**。下表数值来自 Widget 环境，不是真机测量；中文字体复查可以改变像素量或溢出形态，同一页面也可能有多个溢出点。

| 页面 | 位置 | 实测问题 |
|---|---|---|
| 账单列表 | [transaction_summary_card.dart:125](/E:/jizhang_1/repo/lib/core/widgets/transaction_summary_card.dart:125) | 固定高度摘要卡，底部溢出 12px；中文字体为 16px |
| 年度报告 | [annual_report_page.dart:97](/E:/jizhang_1/repo/lib/features/analysis/presentation/annual_report_page.dart:97) | 年份下拉框横向溢出 81px；中文字体仍有约 77px 溢出 |
| 消费洞察 | [insights_page.dart:454](/E:/jizhang_1/repo/lib/features/insights/presentation/insights_page.dart:454) | 统计卡文字列底部溢出，代表值 58px、27px |
| 我的，深色玻璃主题 | [liquid_glass_profile_page.dart:1465](/E:/jizhang_1/repo/lib/features/profile/presentation/liquid_glass_profile_page.dart:1465)、[1885](/E:/jizhang_1/repo/lib/features/profile/presentation/liquid_glass_profile_page.dart:1885) | 默认字体有横向 18px；中文字体仍有多处纵向溢出 |
| 添加普通账户，待确认 | [basic_account_form_page.dart:137](/E:/jizhang_1/repo/lib/features/accounts/presentation/basic_account_form_page.dart:137) | 默认测试字体下横向溢出 28px，中文字体未复现；不与其余已复核项同等定性 |
| 添加受限账户 | [restricted_account_form_page.dart:229](/E:/jizhang_1/repo/lib/features/accounts/presentation/restricted_account_form_page.dart:229)、[269](/E:/jizhang_1/repo/lib/features/accounts/presentation/restricted_account_form_page.dart:269) | 开关标题横向 42px，底部提示横向约 8px |
| 分类管理 | [category_management_page.dart:411](/E:/jizhang_1/repo/lib/features/categories/presentation/category_management_page.dart:411) | 分类行名称/标识横向溢出，代表值 95px，多行受影响 |
| 自动记账 | [auto_bookkeeping_visuals.dart:302](/E:/jizhang_1/repo/lib/features/autobookkeeping/presentation/auto_bookkeeping_visuals.dart:302) | 来源/状态行横向溢出 25px |
| 添加投资，手动模式 | [investment_add_page.dart:734](/E:/jizhang_1/repo/lib/features/investments/presentation/investment_add_page.dart:734) | “计入首页账目净资产”开关标题横向溢出 63px |

应统一处理固定高度统计卡、带图标的开关标题、下拉框和分类行的约束，避免逐页硬调字号。修复后补充真实路由下的 320dp/大字号检查，特别覆盖滚动后才出现的表单控件。

### F09 · P2：Flutter 回归基线失效，两个真实同步集成测试无法启动

44 项失败分布在 19 个测试文件。不能直接将它们算作 44 个产品 Bug，也不能忽略它们后宣称全项目通过。

最明确的契约冲突位于 [shared_backend_integration_test.dart](/E:/jizhang_1/repo/test/shared_backend_integration_test.dart:46) 和 [shared_restore_regression_test.dart](/E:/jizhang_1/repo/test/shared_restore_regression_test.dart:37)：测试向服务端传入 `PORT=0` 并等待旧启动日志；[main.ts](/E:/jizhang_1/repo/server/src/main.ts:15)已拒绝 0 端口且修改日志前缀。这两项测试本轮根本没有完成真实 Flutter 数据库之间的同步/恢复验证。

| 失败文件 | 失败数 | 本轮判断 |
|---|---:|---|
| widget_test.dart | 20 | 使用根 App，未配置新增应用锁依赖；另有旧首页文本、导航图标、按钮查找。需要先修测试入口，再看剩余行为差异 |
| audit_probe_test.dart | 4 | 同类根 App/布局探针基线问题；原报告式断言不能证明当前首页行为 |
| transaction_attachment_repository_test.dart | 1 | 仍断言 schema=18，当前为 25 |
| asset_management_test.dart | 1 | 仍断言 schema=22，当前为 25 |
| recurring_schedule_regression_test.dart | 1 | 仍断言 schema=18，当前为 25 |
| ad_placement_test.dart | 1 | 已确认 F05 |
| database_repository_test.dart | 2 | 1 项为 F04；另 1 项为 Windows 临时数据库删除时文件仍被占用，需检查清理顺序 |
| investment_responsive_test.dart | 1 | 已确认 F08 手动投资表单溢出 |
| investment_flow_test.dart | 1 | 首页资产卡检查通过，趋势语义断言不匹配当前“历史估值”展示；需要按选中日期和快照语义修订测试并验证 F03 修复 |
| bill_import_insight_refresh_test.dart | 1 | 找不到预期洞察；当前洞察已改用范围查询 Provider，旧测试刷新源/异步等待需重新校准，尚未判定产品缺陷 |
| home_books_month_test.dart | 1 | 月度摘要改为异步范围查询，测试即时读取仍得到 0；需等待相应数据源并复核切换行为 |
| home_insight_daily_test.dart | 1 | 动画运行状态断言不匹配；需验证新展示时序，尚未定性 |
| home_insight_provider_test.dart | 2 | Binding 未初始化、Provider 旧替身等问题，未形成有效当前功能验证 |
| product_visual_regression_test.dart | 2 | pumpAndSettle 超时；页面读取新的范围查询源，测试仅替换旧数据源，需补正确替身后验证热力图 |
| payment_brand_icon_test.dart | 1 | 独立挂载账户页缺少当前 Material 上下文，生产路由另有 Scaffold；属于测试装配问题 |
| secondary_page_layout_test.dart | 1 | 内容视口约束已移到路由包装，测试仍单独挂载旧壳结构 |
| startup_poster_test.dart | 1 | AssetImage 改为带缓存尺寸的 ResizeImage 后，旧具体类型断言失效 |
| shared_backend_integration_test.dart | 1 | 服务启动契约冲突 |
| shared_restore_regression_test.dart | 1 | 服务启动契约冲突 |

静态分析还有临时文件 [zz_tmp_render_shots_test.dart](/E:/jizhang_1/repo/test/zz_tmp_render_shots_test.dart:4) 的冗余 import；当前 `flutter analyze` 返回非零，CI 中 Analyze 步骤会受影响。该文件包含固定 Windows 字体路径和外部截图输出目录，不适合进入通用回归。本轮明确排除了它，未运行其外部写入。

### F10 · P3：会员协议中的支持说明与现有工单功能不一致

位置：[legal_document_page.dart](/E:/jizhang_1/repo/lib/features/legal/presentation/legal_document_page.dart:274)。

会员协议仍写“当前版本尚未接入在线客服”，而更多服务页已有我的工单，后台已支持回复并进入 App 工单。建议写清“通过反馈和工单处理，是否支持实时聊天”，避免把异步支持与实时客服混为同一能力。

## 已有后台能力但 App 尚未接通的项目

这些是当前代码明确承认的功能缺口，不应被统计成“配置保存成功就已完成闭环”。

| 能力 | 已实现部分 | 缺口及关联页面 |
|---|---|---|
| 远程功能配置 | 修订、发布、灰度、回滚、读取接口 | Documents.vue 明示 App 门控未接入，不能远程改变本地开关 |
| 远程识别规则 | 规则编辑/发布/读取 | Kotlin 继续使用本地规则；自动记账、支付来源识别不会自动应用新修订 |
| Banner、FAQ、活动配置 | Operations.vue 保存及公开读取 API | App 渲染未接入；帮助页和运营展示仍需关联实现 |
| 自动记账完整 trace | 后台事件列表、时间轴、诊断接口 | Events.vue 提示 App 尚未统一上传 trace，列表空不能证明没有失败事件 |
| 云备份完整可观测性 | 服务端备份保存/恢复 API | gzip 内容尚非端到端加密；备份任务遥测与恢复记录待 App 接入。与已加密的本地备份及本地数据库区分 |
| 正式部署执行 | 更新/备份管理、草稿、受控执行接口与本地测试 | 当前环境没有配置真实部署执行服务，不能仅凭控制台草稿证明已上线 |

## App 逐页检查表

以下 66 个注册路由均完成四种布局的真实路由挂载、首屏和可见滚动区诊断，并使用中文字体复查。**“未发现渲染异常”只描述该检查场景**。有效详情样本覆盖流水、目标、普通账户、持仓；应收、分期、工单、洞察详情在此遍历中使用不存在 ID，验证缺失状态，正常业务数据由专门测试另行覆盖。未登录页面只验证未登录状态。

| 页面/路由 | 功能与本轮结果 |
|---|---|
| `/account/login` | 登录表单渲染；账户/会话既有回归通过，未执行生产账号登录 |
| `/account/register` | 注册表单渲染；账户及服务端注册测试通过 |
| `/account/recover` | 找回/恢复页渲染；未执行真实验证码供应商流程 |
| `/assistant` | 助手页及未登录状态；策略、配额、模型路由本地测试通过，真实供应商未验 |
| `/` | 首页账本、摘要、趋势、最近流水相关代码/测试检查；旧首页回归需修，投资快照关联 F03 |
| `/transactions` | 列表、月份、分组、筛选相关回归；发现 F08 摘要卡溢出 |
| `/transactions/search` | 查询页渲染；范围过滤、排序、性能专门测试通过 |
| `/transactions/inbox` | 收件箱页面与待处理链路；发现 F01 数据覆盖 |
| `/transactions/reimbursements` | 报销页渲染及相关业务回归；缺少索引关联 F04 |
| `/transactions/calendar` | 消费日历渲染与专门回归通过 |
| `/transactions/:transactionId` | 有效流水详情、附件/缺失状态专门回归；旧全局编辑入口测试需更新 |
| `/analysis` | 多账本、币种、周期、统计回归；热力图旧测试超时需复核 |
| `/analysis/annual-report` | 年度统计相关回归通过；发现 F08 下拉框溢出 |
| `/insights` | 洞察列表及引擎/策略检查；发现 F08 卡片溢出，刷新旧测试未通过 |
| `/insights/:insightId` | 缺失洞察状态渲染；有效洞察详情有专门测试 |
| `/goals` | 目标列表及创建/存入/类型相关回归通过 |
| `/goals/:goalId` | 有效目标详情渲染；旧全局归档导航测试需校准 |
| `/profile` | 个人页相关专项回归；深色大字号发现 F08 |
| `/profile/account` | 账户中心及游客状态；会话退出/过期/绑定相关回归通过 |
| `/profile/account/data-binding` | 数据绑定页；游客转登录、数据集隔离相关回归通过 |
| `/profile/data` | 数据导出/本地备份恢复/云备份相关测试；远程门控 F06，云端遥测缺口另列 |
| `/profile/assets` | 资产统计及投资入口；多币种账户业务回归，投资币种关联 F02 |
| `/profile/accounts` | 账户列表/归档/分类相关业务测试；图标独立挂载测试需修 |
| `/profile/accounts/add` | 账户类型选择渲染；相关表单与域逻辑测试 |
| `/profile/accounts/add/basic/:category` | 普通账户表单；F08 下拉溢出仅默认测试字体复现，待真机确认 |
| `/profile/accounts/add/restricted` | 受限资金表单；发现 F08 开关与底部提示溢出 |
| `/profile/accounts/receivables` | 应收列表渲染，域/仓库回归通过 |
| `/profile/accounts/receivables/add` | 应收创建表单渲染及业务测试 |
| `/profile/accounts/receivables/:receivableId` | 本遍历检查缺失状态，专门应收详情测试通过 |
| `/profile/accounts/restricted/:accountId` | 不匹配类型状态渲染；受限账户/分期域回归通过 |
| `/profile/accounts/:accountId` | 有效账户详情渲染，账户余额与流水相关回归通过 |
| `/profile/categories` | 分类模板、排序、个人分类回归；发现 F08 行布局溢出 |
| `/profile/budgets` | 月/周预算、偏好、推荐/通知相关回归；旧全局导航测试需更新 |
| `/profile/membership` | 套餐/权益/支付入口本地回归通过；功能门控 F06，真实支付未验 |
| `/profile/membership/records` | 记录页游客状态；本地支付记录和后端订单测试通过 |
| `/profile/membership/agreement` | 协议渲染；支持文案 F10 |
| `/profile/appearance` | 外观选择及夜间模式相关回归通过 |
| `/profile/quick-actions` | 常用功能管理与排序相关回归；真实路由发现 F07 绘制层问题 |
| `/profile/services` | 服务分组与跳转目标检查；发现 F07 绘制层问题 |
| `/profile/privacy` | 隐私文档渲染，云备份描述需与产品接入范围保持一致 |
| `/profile/legal` | 协议入口/展示渲染 |
| `/profile/family` | 共享/家庭相关域与服务端回归；真实两库联调被 F09 阻断 |
| `/profile/messages` | 消息/未读/已读回执本地与服务端回归通过，真实推送设备未验 |
| `/profile/notification-settings` | 通知设置渲染及偏好回归；系统授权真机未验 |
| `/profile/help` | 本地帮助渲染；后台 FAQ 更新尚不作用于 App |
| `/profile/feedback` | 反馈表单渲染；游客/登录工单服务端回归通过 |
| `/profile/support-tickets` | 工单列表未登录状态；服务端列表/状态/回复测试通过 |
| `/profile/support-tickets/:ticketId` | 本遍历为未登录/缺失状态；后台反馈详情交互及 API 回归通过 |
| `/profile/about` | 版本信息与更新相关测试通过，未下载生产更新包 |
| `/profile/payment-notifications` | 支付通知设置渲染、通知解析业务回归；监听真机未验 |
| `/profile/autobookkeeping` | 自动记账、学习/匹配相关回归；F06 策略门控和 F08 布局 |
| `/profile/autobookkeeping/check` | 权限检查页渲染；系统授权/电池限制需设备验证 |
| `/profile/autobookkeeping/shortcut` | iOS 快捷指令说明页渲染；未做 iOS 系统联调 |
| `/profile/autobookkeeping/logs` | 日志列表渲染、原生诊断相关回归；远端完整 trace 待接入 |
| `/profile/autobookkeeping/apps` | 自定义应用页渲染与策略测试；设备应用列表/权限需真机 |
| `/profile/autobookkeeping/confirm` | 确认页及普通路由；overlay/保存完成专门回归通过，原生浮层真机未验 |
| `/profile/recurring-bills` | 周期规则、执行/时间边界相关回归通过；旧 schema 断言需更新 |
| `/profile/receipt-ocr` | OCR 页面与账单截图解析测试；真实相机/系统图库未验 |
| `/profile/bill-import` | CSV/XLSX、字段映射、去重、账户余额回归通过；洞察刷新测试需复核 |
| `/profile/finance-center` | 金融功能聚合页、关联导航渲染 |
| `/profile/installments` | 分期列表渲染、业务仓库/域回归通过 |
| `/profile/installments/:planId` | 本遍历检查缺失计划状态；有效分期详情有专门回归 |
| `/profile/investments` | 总览、各类型持仓、遮挡金额、交易业务回归；F02 币种及 F03 快照 |
| `/profile/investments/holdings/:assetType` | 类别持仓与空状态回归通过；币种统计关联 F02 |
| `/profile/investments/holdings/detail/:holdingId` | 有效持仓详情、买卖/分红/利息测试；外币符号关联 F02 |
| `/profile/investments/add` | 搜索、手动模式、表单验证相关回归；F02 外币保存和 F08 手动表单溢出 |

## 后台逐页/功能检查表

后台有 26 个 Vue 页面组件。公共页面组件会承载多个菜单，例如设备、备份、审计和会话。新增遍历覆盖 31 个获授权菜单入口的桌面/手机渲染；既有 9 个浏览器回归另外覆盖主要详情页与保存交互。所有这些浏览器操作均使用隔离本地服务。

| 页面组件/入口 | 本轮检查 |
|---|---|
| Login | 登录、无会话重定向；通过 |
| Dashboard `/` | 统计、无设备/无事件状态、桌面渲染；通过 |
| Users `/users` | 筛选、用户详情入口、批量管理、密码会话联动；通过 |
| UserDetail | 用户信息、会员调整、详情导航；既有浏览器/API 回归通过 |
| Membership `/membership` | 套餐草稿、权益编辑、服务端保存；通过，App 消费策略缺口 F06 |
| Payments `/payments` | 订单/退款页面及服务端模拟退款回归通过；真实渠道未验 |
| PaymentChannels `/payment-channels` | 渠道配置保存、敏感字段保留、状态；通过，真实渠道凭据未验 |
| Ledger `/ledger` | 账务统计/空状态渲染；通过 |
| Events `/events`、四类子入口 | 通知、页面、合并、失败列表筛选；通过，App trace 缺口另列 |
| EventDetail `/trace/...` | 时间轴与失败原因；既有浏览器回归通过 |
| Documents `/documents/rule` | 新修订/保存/发布接口与权限；通过，Kotlin 远程应用待接入 |
| AssistantPolicy `/assistant-policy` | 策略保存、提示词读取、手机布局；通过 |
| Models `/models` | 模型配置、Key 保存、路由及成本预算；通过，真实调用未验 |
| Documents `/documents/prompt` | 提示词修订及读取；通过 |
| Asr `/asr` | 腾讯 ASR 配置保存与界面；通过，真实音频识别未验 |
| AIUsage `/ai-usage` | 无 Token 使用量时诚实显示未知、调用列表；通过 |
| AICallDetail `/ai-calls/...` | 调用详情/未知成本；既有浏览器回归通过 |
| Releases `/releases` | 版本草稿创建、筛选、发布权限；通过 |
| ReleaseDetail | 草稿编辑与详情；既有浏览器回归通过 |
| Documents `/documents/config` | 修订、读取、权限、手机展示；通过，App 门控待接入 |
| Operations `/operations` | FAQ/Banner 等保存、渲染；通过，App 消费待接入 |
| ResourcePage `/feedback` | 反馈列表及详情入口；通过 |
| FeedbackDetail | 状态处理、回复持久化；既有浏览器/API 回归通过 |
| Push `/push` | 推送草稿列表/创建；通过 |
| PushDetail | 目标、设备缺失状态、详情/管理；既有浏览器回归通过，真实 APNs/设备投递未验 |
| SystemMaintenance `/system-maintenance` | 后端备份、任务及部署配置页面；通过，生产执行未验 |
| Administrators `/administrators` | 管理员页面及密码/权限业务回归；通过 |
| Roles `/roles` | 角色与权限页面；通过，support 角色 API 越权拒绝回归通过 |
| ResourcePage `/devices` | 设备未上报/已有数据展示；通过 |
| ResourcePage `/diagnostics` | 诊断列表/空状态；通过，App 完整上传待接入 |
| ResourcePage `/backups` | 备份列表与隐私说明；通过，遥测/恢复记录待接入 |
| ResourcePage `/audit` | 审计列表；通过 |
| ResourcePage `/logins` | 登录记录；通过 |
| ResourcePage `/sessions` | 会话展示、撤销相关交互回归；通过 |

浏览器回归没有逐个执行所有危险按钮、生产发布或供应商操作。后台构建没有失败，但 charts 和 arco 分包较大，可在核心正确性问题解决后评估加载性能。Android 构建提示 cryptography_flutter 的 Kotlin 插件兼容维护问题；Flutter 反复提示 alipay_kit 的 iOS 默认插件包缺失。本轮 Android 构建成功，iOS 是否受影响需在 macOS 验证，未据此断言 iOS 构建失败。

## 建议的修复顺序和统一影响范围

1. **数据完整性：F01、F02、F05。** 统一唯一 ID；投资币种必须把搜索、保存、展示、汇总、快照、首页和账户镜像一起改。先补能防止记录覆盖和金额误标的回归。
2. **状态/数据库：F03、F04。** 恢复前台每日快照；让新建、升级及已有 v25 数据库拥有一致索引。
3. **前后端策略：F06 与远程接入缺口。** 确认产品开放规则后按同一策略接入口和实际执行，不能只修一个会员按钮。
4. **页面一致性：F07、F08。** 优先复用公共布局约束，统一处理已复核的 8 个页面和玻璃表面的 Material；普通账户表单另做设备确认。
5. **回归可信度：F09、F10。** 修测试入口、异步数据替身、启动协议和旧断言；剩余未定性失败应复核，而非直接删除断言。最后更新用户文案。

修复验收应以“关键数据诊断通过 + Flutter 失败归零 + 逐页布局异常归零 + 服务端/后台/Android 回归通过”为目标。第三方支付、供应商服务、设备权限和生产部署分别安排受控实测。

## 原始证据

全部审计脚本与日志位于 [project-audit-20261007](/E:/jizhang_1/repo/.agent/project-audit-20261007)。主要文件：

- [Flutter 全量结果](/E:/jizhang_1/repo/.agent/project-audit-20261007/flutter-test.log)
- [全路由复查](/E:/jizhang_1/repo/.agent/project-audit-20261007/route-audit-recheck.log)
- [中文字体全路由复查](/E:/jizhang_1/repo/.agent/project-audit-20261007/route-audit-real-font.log)
- [中文字体手动投资表单复查](/E:/jizhang_1/repo/.agent/project-audit-20261007/investment-real-font.log)
- [收件箱与快照诊断](/E:/jizhang_1/repo/.agent/project-audit-20261007/invariants-audit.log)
- [投资币种诊断](/E:/jizhang_1/repo/.agent/project-audit-20261007/currency-audit.log)
- [后台业务回归](/E:/jizhang_1/repo/.agent/project-audit-20261007/admin-test.log)
- [后台全菜单检查](/E:/jizhang_1/repo/.agent/project-audit-20261007/admin-pages-audit.log)
- [Android 原生测试](/E:/jizhang_1/repo/.agent/project-audit-20261007/android-test.log)
- [Android APK 构建](/E:/jizhang_1/repo/.agent/project-audit-20261007/android-build.log)

诊断文件不应未经筛选直接纳入正式测试或发布流程；正式修复时把必要的防回归用例收敛到现有测试结构。
