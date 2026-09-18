# 当前开发状态

更新时间：2026-09-18

## 最新任务交接（2026-09-18 全工程 Git 跟踪）

把此前游离在工作区外的整份工程纳入版本管理：一次性提交 120 个未跟踪文件与 130 个修改文件（投资管理、循环账单、自动记账与诊断日志、会员法律文档、服务端诊断接口、QA 截图归档、`scripts/package_source.sh`），工作区提交后干净无遗漏。`.gitignore` 只保留生成物忽略规则：`build/`、`dist/`、`.dart_tool/`、`android/.gradle/`、`ios/Pods/`、`server/node_modules/`、`jizhang_app/`、`jizhang_app_source_*.zip`、签名材料；安装包改为 `dist/` 整体忽略，需要分发时上传 GitHub Release（`git rm --cached` 后本地文件保留）。跟踪范围与远端说明见根目录 [`README.md`](../../README.md) 的「版本管理（Git）」。远端 `origin/main` 原本只有一个无关的 `Initial commit`（LICENSE + 单行 README），已用 `--allow-unrelated-histories` 合并后推送；本地历史里 2026-09-17 之前的两个 release APK 版本（约 169MB）仍留在提交历史中，如需给远端瘦身需重写历史并强推。

## 最新任务交接（2026-09-18 Android 自动记账与诊断日志）

[Android 自动记账与诊断日志收尾](2026-09-18-android-autobookkeeping-diagnostics.md)：修复首页长按编辑流水时底部导航栏透出、备注行撑开卡片、编辑周期流水无法打开规则页三个问题；并把通知/无障碍自动记账统一为“保守识别 → 本地待确认 → 悬浮层或系统通知 → 用户确认后入账”。已覆盖微信、支付宝、云闪付和美团包名，过滤收款/到账/退款通知，金额歧义和重复指纹不入账；新增本地脱敏诊断环形队列与登录后可手动上传的服务端批量幂等接口。Flutter 全量 408 项、Android 单测/lint、服务端 11 项测试和 build 已通过。遗留：没有连接实体 Android 设备，支付 App 版本差异、无障碍节点、浮窗和后台存活尚未做真机验收。

## 最新任务交接（2026-09-17 投资账务联动）

[投资账务联动](2026-09-17-investment-ledger-linkage.md)：投资买入/卖出镜像为主流水 `assetPurchase`/`assetSale`，出资账户余额同步增减；投资市值计入资产总览净资产；买入不再计入首页月支出与消费日历；共享同步协议类型枚举加入 `assetSale`。106 项 Flutter 测试与 10 项服务端测试通过。遗留：分红/利息未生成主流水、存量持仓不回溯补写。

## 上一轮任务交接（2026-09-17 投资管理 MVP）

[投资管理 MVP](2026-09-17-investment-management-mvp.md)：资产总览「分类统计」入口改为「投资管理」；新增股票/基金/债券/虚拟币统一页面结构，含总览、分类持仓、投资详情、添加投资（搜索/手动）、交易记录（买入/卖出/分红/利息）；schema 17→18 新增 4 张投资表（纯新增，不改既有列）；行情走 `MarketDataProvider` + `QuoteCache` 抽象，当前为 `MockMarketDataProvider` + `MemoryQuoteCache`。

## 上一轮任务交接（2026-09-14）

[资产详情弹窗布局调整](2026-09-14-asset-detail-popup-layout.md)：去掉详情卡片内部重复标题，弹窗标题居中；资产变化区间按钮右移并与金额同排；未来流水按日期判断。

[金额右对齐与 Android 卡顿排查](2026-09-14-amount-alignment-and-performance.md)：去掉金额清空 X；常规数据库操作移出 Android UI isolate。手机当前仍是调试包，尚未完成新版本真机帧率对比。

[记一笔布局与首页实时流水修复](2026-09-14-entry-layout-and-live-transactions.md)：当前分类、金额、键盘及流水样式以此文档为准。修复首页监听固定时间截止导致新增交易不显示的问题，保留原有账本隔离与未来流水过滤。

## 项目定位

当前产品是 Flutter 本地优先记账应用。核心账务使用 Drift/SQLite 持久化；个人账本保持本机私有，家庭/企业账本已支持本地 Node.js 共享后端联调。Android 自动记账采用待确认语义并覆盖微信、支付宝、云闪付和美团；本地诊断日志可在登录后上传服务端。会员 catalog、订单和微信/支付宝支付协议已接入本地服务端，生产公网部署、短信、附件云存储和企业报税仍需后续配置与验收。

## 已完成的本地能力

- 首页、流水、目标、我的四个一级导航及核心页面。
- 手动支出、收入、转账；编辑、分类修正和软删除。
- 交易与账户余额在同一数据库事务内联动。
- 账户、分类、预算、资产/负债汇总和余额校准。
- 目标、里程碑、贡献、调整、排序、预测和完成庆祝。
- 收支趋势、分类构成、消费习惯、热力图和本地洞察。
- 商户分类记忆、指纹去重和账单收件箱。
- Android 支付通知与无障碍自动记账：微信专用解析 + 支付宝/云闪付/美团保守通用解析，统一待确认队列、去重指纹和确认后入账。
- 本地诊断日志：应用启动、生命周期、记账成功/失败、通知处理等事件进入脱敏环形队列，可通过已登录共享服务批量幂等上传。
- 设备语音识别和本地规则解析。
- CSV 流水导出。
- 可校验的完整 SQLite 本地备份/恢复；恢复采用安全暂存，应用完全重启后切换数据库。
- 个人、家庭、企业账本的账户、分类、预算、流水、目标和通知目标已按 `bookId` 隔离；schema 8→9 会在迁移前保存副本并校准期初余额。
- 首页已改为暖米白实色细边框卡片；月账单支持年月切换，今日额度与目标独立紧凑展示，账本名从顶部书架抽屉切换。
- schema 9→10 新增共享版本、ID 映射、待同步队列和 SQLite 触发器；本地两端可真实注册、邀请、同步、断网记账、冲突处理和撤权。
- Android 本地联调后端位于 `server/`，使用 Node.js 22、Fastify 5、SQLite/better-sqlite3；会话仅保存在系统安全存储。
- 本轮收尾审计修正交易 Provider、目标 Repository、收件箱和支付通知的账本边界；余额校准及目标贡献写入当前真实操作者，固定通知账本不会随浏览账本切换。
- 书架抽屉已增加真实书本层次：顶部把手、木质层板、书脊、封面内框、高光和投影；桌面 `/Users/algive/Desktop/icon.png` 已复制为 `assets/images/icon.png`，并生成 Android/iOS 启动图标。
- 2026-09-10 抽屉切片 1 已统一账本数量规则：Free 10、Pro 20、Family 50；共享他人账本不占创建额度；预览沿创建顺序展示，活动账本在前三本之外时替换第三位。
- 2026-09-10 抽屉切片 2 已完成可搜索的全部账本管理视图、显式管理入口和一体化新建表单；新建默认个人用途，成功后真实持久化并切换，320dp/1.6 字号回归无布局异常。
- 2026-09-10 抽屉切片 2 已通过 `flutter build apk --debug`，产物为 `build/app/outputs/flutter-apk/app-debug.apk`；本机本次未连接 Android 设备，未虚报安装截图验收。
- 2026-09-10 抽屉切片 3 已新增无内置账本的木质书架背景，并将个人/家庭/企业账本改为独立 Flutter 书本层；QA 预缓存清单同步更新，避免截屏在新素材加载前完成。
- 2026-09-10 抽屉切片 3 已完成全量回归：153 个 Flutter tests、analyze 和 Debug APK 构建均通过；本机仍无 Android 设备，未虚报安装验收。
- 2026-09-10 抽屉切片 3 的 Release APK 已成功构建，且 APK 内确认包含 `bookshelf_empty_background_v1.png`；构建仍有既存 `speech_to_text` KGP 兼容性 warning。
- 2026-09-11 抽屉切片 4 已将首页最近交易改为当前账本数据库限量查询（10 条）、本地日期分组和本地时间显示；保留完整流水给预算/分析统计。
- 2026-09-11 抽屉切片 4 已补充 SQL 级未来流水过滤，确保计划流水不会占用最近 10 条名额。
- 2026-09-11 交易详情切片 5 已统一首页、流水、搜索三个入口：点击进入详情，长按保留操作菜单；详情展示金额、类型、发生时间、账户、分类、备注、记录人和同步状态。
- 2026-09-11 交易详情切片 5 已补齐旧 metadata 附件的图片缩略图/全屏缩放、PDF/其他文件系统打开、无处理器提示、文件缺失提示和重新添加入口；编辑、分类修正和软删除复用既有 Service/权限链路。
- 2026-09-11 阶段二附件切片已将 schema 从 10 升到 11：新增独立 `transaction_attachments` 记录、按账本和交易隔离查询、顺序维护及软删除；旧 `metadata.attachments` 会在升级时迁移，其他 metadata 和 malformed 项保留。
- 2026-09-11 阶段二附件切片已接入新建/编辑记账和交易详情；保存会等待附件加载，附件后处理失败会明确提示“流水已入账”，不隐式重复记账。
- 2026-09-11 阶段二附件切片已通过全量 165 个 Flutter tests、analyze、Drift code generation 和 Release APK 构建；本次 `adb devices` 无连接设备，未安装本次 APK，未虚报 UI 验收。
- 2026-09-12 财务扩展已完成统一流水关联、报销、退款、消费日历、周期账单、信用卡分期、账户详情和增强搜索；schema 12→15 migration、共享协议、230 个 Flutter tests、analyze 与 Debug APK 均通过。周期账单 `auto_record` 会在应用启动/回到前台时幂等补齐到期流水。
- 2026-09-12 收尾补充：退款回款支持编辑/撤销并同步恢复原消费状态；分期页可按还款日批量执行到期期间；附件保存状态支持保存中、失败保留和重试，失败附件阻止流水提交。
- 2026-09-12 后台调度补充：Android 已接入每日 `AlarmManager`、开机重排和后台 Flutter isolate，用于周期账单与分期到期流水；iOS/桌面继续使用启动或回前台补齐策略。
- 2026-09-12 完整性收尾：通用流水软删除现在强制当前账本作用域，并阻止删除仍有退款/报销/还款或分期计划的流水；共享同步 ID 映射补齐退款、报销、分期账户引用。
- 2026-09-13 记一笔页面按原型重构（仅动该页面）：类型页签扩为支出/收入/转账/**债务**（债务展开借入/借出/还款，复用既有 borrow/lend/repayment 与余额影响规则）；一级分类 5 列网格 + 真实子分类横滑条（`Category.parentId`，无子分类时整条隐藏）；金额支持**计算器表达式**（`+ − × ÷`、乘除优先、取整到分、未输完/除零/负数拒绝保存）；账户/报销/账本/附件/图片/日期/定期付/更多收敛为 chip；键盘常驻并新增**再记**（保存后留页连续记账）；原「更多选项」（商户/计划内/一次性/周期/标签/附件管理）与语音、AI 入口全部保留。
- 2026-09-13 联动修正：还款（repayment）与转账一致，智能分类不再给它打默认消费分类。
- 2026-09-13 记一笔验证：`test/amount_input_test.dart`（14 例）+ `test/quick_add_redesign_test.dart`（9 例）共 23 例通过；`flutter analyze` 无问题；Pixel 7 AVD 完成 12 张截图验收（含 320dp × 字号 1.6），模拟器上发现并修复备注行挤压、子分类条 2.4px 溢出、金额行横向溢出三个真实缺陷。详见 [`2026-09-13-quick-add-prototype-redesign.md`](2026-09-13-quick-add-prototype-redesign.md)。
- 2026-09-13 未完成：记一笔右上角「编辑」按钮经确认本轮不实现；会员页存在既有的 `pumpAndSettle` 超时失败（与本轮无关）。
- 2026-09-17 投资管理 MVP：`investment_assets` / `investment_holdings` / `investment_transactions` / `investment_snapshots` 四表 + `InvestmentDao`；`/profile/investments` 路由组；四类资产共用 `InvestmentOverviewPage` / `InvestmentDetailPage` / `InvestmentAddPage`，模板组件 `InvestmentSummaryCard`、`InvestmentCategoryCard`、`HoldingItem`、`ProfitText`、`QuoteStatus`、`InvestmentChart`、`TransactionItem`。
- 2026-09-17 投资口径：买入投资**不写入** `transactions`，因此不会被计为消费支出，也不会减少净资产；`InvestmentRepository` 接口已按「资产转换」而非「收支」建立，账户余额打通留待产品确认后实施。
- 2026-09-17 投资 snapshot 策略：用户当天第一次打开投资管理时懒写入当天快照，无后台定时任务；空组合不写入任何行。
- 2026-09-18 Android 收尾：首页编辑入口的 modal 层级、记一笔备注行和周期账单编辑联动已修复，详见 [Android 自动记账与诊断日志收尾](2026-09-18-android-autobookkeeping-diagnostics.md)。

## 当前未完成或未联调

- OCR 账单识别和独立账单导入入口。
- 云端 ASR/LLM；当前“AI 记账”实际仍以本地规则解析为主。
- 会员支付的真实商户证书、公网 HTTPS 回调、沙箱/小额真实订单验收；本地订单、支付签名适配、回调验签和权益刷新代码已完成。
- 公网云部署、对象存储、家庭短信邀请和企业报税。
- 第三方广告 SDK、后台 placement、Rewarded 和 Splash。
- iOS 真机、签名和发布验收；当前 `flutter build ios --no-codesign` 被既有 `Application not configured for iOS` 配置问题阻断。
- 账本抽屉计划中的阶段二仅完成独立附件记录和旧 metadata 迁移；版本化数据库＋附件文件备份、押金/结算、模板以及阶段三同步能力尚未完成。
- Android 自动记账已完成四类付款应用的保守识别、待确认队列、悬浮层/系统通知回退和本地单测；不同支付 App 版本、无障碍节点、浮窗权限、后台进程存活仍未真机联调，京东/拼多多/抖音尚未接入。
- 第三方 Crashlytics / Sentry / Firebase 尚未接入；当前只有本地脱敏诊断环形队列和自建服务端上传接口，不能替代公网崩溃平台与生产监控。
- 投资管理真实行情 API 未接入（当前是 `MockMarketDataProvider`，代码完成但未实际联调）；`RedisQuoteCache` 只有接口占位，未实现 Redis 客户端调用。
- 投资买入尚未与账户余额联动（银行卡余额不会因买入而减少），投资资产也未计入资产总览净资产；两者都会改动既有被测试锁定的口径，需产品确认后实施。

## 当前架构风险

1. 流水、分析和去重仍存在全量加载/内存计算，长期大数据量需要分页和 SQL 聚合。
2. Android Release 未配置正式 keystore，当前产物只能作为本地验收包。
3. 共享服务已完成本地真实联调，尚未进行公网部署、TLS 证书、监控和生产备份验收。
4. 提醒设置仍只有未启用的菜单项；支付代码已接入，但真实商户配置、回调公网可达性和生产风控仍未验收，短信、附件云存储和企业报税未接入。
5. Release 构建仍收到 `speech_to_text` 使用 Kotlin Gradle Plugin 的未来兼容性 warning；当前构建成功，后续需等待插件迁移到 Built-in Kotlin。
6. 当前账本创建顺序的兼容排序使用 SQLite `rowid` 作为同时间戳的 tie-breaker；后续若需要跨导入/跨设备保持业务创建序号，应在账本模型中增加显式稳定序号并纳入同步协议。
7. 交易详情的系统文件打开依赖 Android/iOS 系统处理器；iOS 尚未完成可编译项目配置和真机验证。独立附件记录已完成，但附件文件内容尚未纳入备份/同步。
8. 自动记账解析器需要真实 Android 通知和页面样本持续校准；当前测试验证的是规则边界与队列幂等，不代表已覆盖所有支付 App 版本。
9. 诊断事件上传已具备认证、脱敏、批量和幂等，但服务端仍是本地联调形态，没有公网 TLS、保留策略、告警和监控后台。

## 实际验证结果

### 2026-09-18 Android 自动记账与诊断日志本轮实际执行

```text
flutter analyze
→ No issues found

flutter test --reporter compact
→ All tests passed（408 项）

cd android && ./gradlew :app:testDebugUnitTest :app:lintDebug
→ BUILD SUCCESSFUL；应用模块 lint 无 error

cd server && npm run typecheck && npm test && npm run build
→ typecheck、11 项服务端测试、TypeScript build 全部通过
```

本轮未连接 Android 实体设备或模拟器；`adb devices` 无设备。因此未声称真实支付通知文案、无障碍节点、系统浮窗、通知权限和后台存活已验收。

### 2026-09-17 投资管理 MVP 本轮实际执行

```text
dart run build_runner build
→ Built with build_runner/aot；app_database.g.dart 重新生成并包含 4 张投资表与 InvestmentDao

flutter analyze lib/
→ No issues found

flutter test（投资管理新增用例 + 受影响的回归子集，共 113 项）
→ All tests passed
   · investment_domain_test（17）investment_repository_test（14）
     investment_market_test（16）investment_flow_test（12）
     investment_responsive_test（4）= 63
   · privacy_amount_test + home_amount_visibility_test = 8
   · asset_management_test / asset_overview_layout_test /
     asset_overview_interaction_test / home_asset_card_test /
     home_asset_scope_test / app_scaffold_navigation_test = 17
   · recurring_schedule_regression_test /
     transaction_attachment_repository_test / budget_and_management_test /
     book_scope_test / home_redesign_domain_test = 20
   · membership_feature_prompt_test / asset_visual_qa_test /
     product_visual_regression_test /
     asset_membership_prototype_capture_test = 5（抽查）

响应式测试实际查出并已修复 3 处真实溢出缺陷（320dp × 字号 1.6）：
   1. 持仓列表行 HoldingItem / HoldingMiniRow 的尾部金额列无宽度约束，
      PrivacyAmount 的 FittedBox 拿不到上界 → 用 LayoutBuilder + 46% 上限修复；
   2. 分类汇总卡「累计收益」行、详情页「累计收益」行、交易记录行、
      详情页涨跌列的非弹性子项 → 改为 Flexible / ConstrainedBox；
   3. ProfitText 在 1.6 字号下自然宽度超过所在半栏 → 与 InvestmentAmountText
      一致地包一层 scaleDown FittedBox，并按左右对齐传入 alignment。
```

全量回归（排除 3 个会员页相关测试文件后，83 个测试文件）：

```text
flutter test --reporter compact <83 个测试文件>
→ 354 个测试全部通过，EXIT=0
```

Debug APK 构建：

```text
flutter build apk --debug
→ ✓ Built build/app/outputs/flutter-apk/app-debug.apk
   （221,615,858 bytes；Gradle assembleDebug 53.7s；无 warning / error 输出）
```

### 全量测试中 5 项既有失败（与本轮投资管理改动无关）

`flutter test`（全部 86 个文件）跑出 5 项失败，**全部集中在会员页**，且都在本轮未改动的文件里：

| 失败用例 | 原因 |
| --- | --- |
| `home_header_cards_test.dart: header cards interaction and layout at 320.0` | `membership_page.dart:376` 的 Column 在 320dp 下溢出 6.6px |
| `widget_test.dart: membership navigation closes the ledger drawer` | 找不到「会员与数据安全」标题 |
| `widget_test.dart: quick add and membership share the same back-button target` | `pumpAndSettle` 超时 |
| `widget_test.dart: opens account, category and budget management pages` | `pumpAndSettle` 超时 |
| `membership_page_ui_test.dart: membership page stays usable at 320.0 scale 1.0 / 1.6` | 1.0 溢出；1.6 `pumpAndSettle` 超时导致整轮挂起 |

判定依据（不是猜测）：

1. 失败点全部指向 `lib/features/membership/presentation/membership_page.dart`，而本轮**没有修改任何 membership 文件**。
2. 该文件在工作区中本就有**未提交的大量改动**（`git diff --stat`：`membership_page.dart` 892 行、`membership_visuals.dart` 1081 行），是上一轮「开通会员页原型复刻」留下的在途改动。
3. `CURRENT_STATUS.md` 早在 2026-09-13 就记录过「会员页存在既有的 `pumpAndSettle` 超时失败（与本轮无关）」。

因此本轮用「83 个文件 / 354 项」的干净全量结果作为回归证据，会员页 5 项失败保持原样、未修改、未掩盖。

本轮未连接 Android 物理设备或模拟器，未做截图验收，未虚报 UI 验收结论。

### 历史轮次（2026-09-14 及更早）

```text
flutter test --reporter compact
→ All tests passed（230 个）

flutter build apk --debug
→ Built build/app/outputs/flutter-apk/app-debug.apk

android: `./gradlew :app:testDebugUnitTest`
→ BUILD SUCCESSFUL

android: `./gradlew :app:lintDebug`
→ BUILD SUCCESSFUL（应用模块 lint 通过）

android: `./gradlew test lint`
→ lint 被 `speech_to_text` 和 `flutter_secure_storage` 依赖源码的既有 MissingPermission 错误阻断；应用模块单测和 APK 编译均通过，未修改依赖源码。

flutter build apk --release
→ Built build/app/outputs/flutter-apk/app-release.apk（77,656,758 bytes）

server: npm run typecheck && npm test && npm run build
→ typecheck、2 个真实 HTTP 测试及 1 个关联完整性测试、TypeScript build 全部通过
```

历史 APK：`build/app/outputs/flutter-apk/app-debug.apk`；Debug 构建包含 Android `AlarmManager` 后台周期账单/分期处理入口。历史轮次未连接 Android 物理设备，未虚报安装验收。

此前交易详情切片的历史 Release APK 曾在 Pixel 7 Android emulator 安装并打开首页、流水列表和交易详情页；本次阶段二 Release APK 未安装：
[首页截图](../../qa/home-book-icon-2026-09-09.png) · [立体书架抽屉截图](../../qa/bookshelf-book-icon-2026-09-09.png) · [系统桌面图标截图](../../qa/launcher-book-icon-2026-09-09.png)。这是本地 Pixel 7 模拟器证据，不是物理手机验收。
以上三个链接仍是历史版本截图；本次详情页的当前截图保存在本机 `/tmp/jizhang-slice5-release-final.png`，并已在模拟器窗口保持打开供人工查看。

测试期间有 Drift Widget 测试重复创建内存数据库的 debug warning，但没有测试失败；后续应统一测试数据库生命周期。Release 构建另有既存 `speech_to_text` KGP 兼容性 warning，但构建成功。

完整备份使用 SQLite 文件并校验核心表与 schema 版本；恢复不会在当前页面强制关闭活动数据库，而是先写入待恢复文件，应用下一次启动数据库连接前完成替换。备份不包含独立文件系统中的附件，且没有加密或密码保护。

## 推荐后续顺序

1. 为共享后端补充部署环境的 TLS、数据库备份、监控和限流验收，再配置支付回调并用沙箱/小额订单完成真实链路验收。
2. 优化流水和分析的查询边界，再扩展筛选能力。
3. 继续补充短信、附件存储和企业报税服务，同时保持个人账本默认不上云。
