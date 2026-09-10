# 好好记账阶段四—阶段十三开发交接

> 2026-09-07 Luna 复核覆盖：本文件早期章节中的 65/65 与旧 APK hash 是历史记录，不代表本轮结果。当前验收记录以 [LUNA_IMPLEMENTATION_2026-09-07.md](/Users/algive/jizhang_01/docs/LUNA_IMPLEMENTATION_2026-09-07.md) 和 `STRICT_AUDIT_2026-09-07.md` 的最终复核为准。

更新时间：2026-09-01

## 当前结论

已逐段读取并检查 `阶段四.txt` 至 `阶段十三.txt`。阶段四、五、六、八、九目前应标为“本地基础/部分完成”，阶段七的目标与贡献核心闭环基本完成；阶段十—阶段十三中能够由当前客户端真实完成的部分已经落地，但认证/支付服务端、PostgreSQL、对象存储、家庭共享服务端、云 ASR/LLM、广告平台 SDK 和后台配置仍未联调。当前仅建立真实领域模型、权限边界和 Provider/Service 契约，未用 Mock 或固定成功冒充联调完成。

当前 Flutter 工程 `flutter analyze` 通过，Android Release 构建通过；最终 `source: system/name: sqlite` 配置下 macOS 测试主机发现 71 个测试但因缺少 `libsqlite.dylib` 失败 32 个（39 个通过）。iOS Simulator 目录中保留历史构建产物，但当前机器的 `xcode-select` 指向 Command Line Tools，`xcodebuild` 不可用，暂不能复现 iOS 构建。

## 2026-09-07 SQLite P0 更新

数据库 native asset 阻塞已解决。`pubspec.yaml` 现在使用 `sqlite3 3.5.2` 官方 hook（`source: sqlite3`）并固定官方 GitHub release URL；hook 按包内 SHA-256 清单校验下载内容。`flutter analyze` 通过，`flutter test --reporter compact` 通过 71/71，`flutter build apk --release` 通过并生成 65.7 MB APK。APK 包含 Android `arm64-v8a`、`armeabi-v7a`、`x86_64` 的 `libsqlite3.so`，不依赖系统 `libsqlite.so`。

Pixel 7 x86_64 AVD 干净安装后已创建 SQLite 文件并完成默认 seed（4 个账户、20 个分类、seed_version=5）；Quick Add 保存、编辑、删除和强制停止/重启持久化均以 UI 与导出的 SQLite 查询验证。首次构建缺失 ABI 时仍需要访问 GitHub release，仓库不提交外部二进制。云同步、支付、第三方广告及 iOS 真机仍未联调。

## 阶段四：持久化数据基础（本地基础完成）

- 使用 Drift + SQLite 替换 Mock/内存账本，数据库当前为 schema v6。
- 建立 `accounts`、`categories`、`transactions`、`goals`、`goal_milestones`、`goal_contributions`、`app_settings` 等基础表、DAO、索引和种子数据。
- `TransactionRecord` 覆盖交易类型、账户、转账目标、分类、时间、商户、备注、标记、来源、同步状态和软删除字段。
- `TransactionRepository` 的新增、更新、转账和软删除均在 SQLite transaction 内同步更新账户余额。
- 默认初始化不再写入演示流水、演示目标、演示预算或非零演示余额；旧 seed 版本会通过 seed v5 清理固定演示数据。
- `TransactionRecord.currency` 已贯通模型、Repository 和快速记账服务，写入不再固定覆盖为 CNY。
- 流水、首页、目标等页面已改用真实 Repository 数据。
- 数据关闭并重新打开后仍可读取；转账保持总资产不变。

## 阶段五：快速记账（部分完成）

- 中央 `+` 打开快速记账 BottomSheet，支持支出、收入、转账。
- 自定义数字键盘限制非法小数状态，金额、分类、账户、时间、商户、备注、计划/一次性/周期、标签和本地附件均可保存。
- 记忆上次使用账户；转账要求两个不同账户；保存按钮有重复点击保护。
- OCR/AI 入口只明确提示“暂未接入 API”，没有伪造识别结果。
- 新增 `saveAll` 批量接口；语音多笔入账和余额变更现在原子提交，任意一笔失败会整批回滚。
- 流水列表已提供编辑、分类修正和软删除入口，搜索结果也可打开同一操作菜单。
- **仍未完成**：OCR/AI API、附件详情查看，以及所有扩展交易类型的专用编辑体验。

## 阶段六：账户、分类和预算（部分完成）

- 账户支持新增、编辑、归档；类型包含现金、微信、支付宝、储蓄卡、信用卡、其他和预留的 liability。
- 账户管理支持拖拽排序，排序通过 Repository 持久化到 `sortOrder`；信用卡/liability 单独汇总为负债，不再计入总资产。
- 分类支持支出/收入、一级/二级、新增、编辑、排序、归档；默认分类仅隐藏，不物理删除。
- 月度总预算和分类预算均持久化，并与真实流水联动计算已使用、剩余、比例、剩余天数和日均可用。
- `SafeToSpendService` 独立实现“剩余预算 ÷ 本月剩余天数”的 V1 公式。
- App 内预算状态为正常、接近预算、已超预算；按要求未接 Push。

## 阶段七：财务目标（完成）

- 支持买车、旅行、首付、应急金、结婚、装修、教育、医疗、养老、还债等 17 种目标类型。
- 目标创建支持名称、类型、目标金额、已有金额、日期、描述、封面和可编辑节点。
- 节点由金额动态生成，最后一个节点始终等于目标金额，不使用固定百分比假数据。
- 支持存入、取出、校准；贡献记录不可被“当前金额”覆盖。
- 节点跨越和目标完成有一次性庆祝状态，完成目标不会删除历史。
- 根据最近 30/60/90 天存入速度给出完成日期预测。
- `sourceTransactionId` 已为目标与流水后续关联预留。

## 阶段八：统计洞察（部分完成）

- 分析范围支持 7/30/90 天、本月和上月，全部来自真实流水。
- 建立交易时间特征、7×24 热力图、分类趋势、频次与客单价比较；时间段严格按 00–05、05–08、08–11、11–14、14–17、17–22、22–24 划分。
- `AnalysisInsight` 已提供 period、amount、baselineAmount、deltaAmount、deltaPercent、reasonCode、categoryId、timeSegment、metadata 和 generatedAt 等稳定字段，展示描述由结构化事实派生。
- 对深夜、外卖/餐饮等可验证行为输出结构化原因，不生成无法解释的自然语言结论。
- 一次性大额和资产购置单独标记，避免污染日常消费基线。
- 建立 7/30/90/180 天行为基线与异常检测。
- 覆盖正常消费、深夜消费、车辆购置排除、餐饮频次和分布异常测试。

## 阶段九：智能分类与去重（本地产品链路完成，导入入口待补）

- 分类优先级为个人商户记忆 > 精确规则 > 关键词规则 > 默认分类 > 待确认。
- 商户名称先标准化再匹配；用户修改可选择仅本次或记住该商户。
- 指纹综合金额、时间、商户、账户、来源、支付渠道、卡号尾号和订单号。
- 区分无关记录、疑似重复、高置信重复和同一经济事件；绝不自动删除交易。
- 待确认箱持久化疑似重复项；手动和语音保存会统一执行分类、指纹检查并写入收件箱。
- 收件箱支持为不确定记录修改分类并选择记住商户；疑似重复可明确选择保留/删除，跨渠道同一经济事件可确认关联，所有操作都会落到真实交易或收件箱状态。
- **仍未完成**：当前工程没有独立的账单导入入口；经济事件服务端同步和更复杂的合并策略仍待补充。

## 阶段十：商业基础（客户端基础完成，外部联调待接入）

- 已完成旧资产检索，结论见 `docs/STAGE_10_ASSET_AUDIT.md`；当前可访问目录未发现所述旧项目商业源码。
- 建立 `Membership`、`Subscription`、`Entitlement`、`UsageQuota`，套餐为 Free/Pro/Family。
- 页面只通过 Entitlement 判断能力；当前真实状态为本地 Free，只开放本地记账、数据导出和基础备份权益。
- 建立 Payment、Object Storage、Cloud Sync 契约；未配置时明确返回不可用，不创建假订单、假上传或假同步。
- 会员页保持暖米白/鼠尾草绿，说明云同步、数据安全、AI 和无广告价值，不使用虚假会员身份。
- **代码完成但未实际联调**：认证、订单、微信支付、Apple IAP、服务端回调验签、PostgreSQL、对象存储和云同步。

## 阶段十一：AI 语音记账（本地链路完成，外部服务/真机待验）

- 长按中央 `+` 打开语音记账；短按仍进入手动记账。
- `SpeechRecognitionService` 与 UI 解耦，优先请求设备端识别，不可用时降级到系统识别能力。
- 规则解析优先，支持多笔语句、金额、支出/收入、分类、账户，以及今天、昨天、昨晚、前天、上周六和具体时刻。
- 复杂解析保留会员权益/额度门控、缓存、超时、重试和严格 JSON 解码契约；未配置 LLM 时不会发送或伪造结果。
- 确认页允许修改识别文字和每笔金额/分类/账户，存在未解析片段时拒绝保存。
- 用户改正商户分类后写入个人 MerchantRule。
- 多笔语音账单通过单个 SQLite transaction 原子保存。
- iOS/Android 已声明麦克风及语音识别权限。
- **代码完成但未实际联调**：云 ASR、LLM 解析和会员 AI 额度服务；麦克风需在 Android/iPhone 真机完成权限、噪音和中文识别验收。

## 阶段十二：家庭共享账本（客户端模型完成，服务端共享待接入）

- 建立 Family、Book、FamilyMember、Invitation、OperationLog、FamilyBudget 表和模型。
- 角色为 owner/admin/member；账本区分 personal/shared；流水支持 private/shared。
- 家庭预算可只公开汇总，个人预算和私人流水不向其他成员展开。
- 共同目标展示总进度、“你的贡献”和“家庭成员贡献”，没有排行榜。
- 流水和目标增加 `bookId`、`createdBy`、`updatedBy`、`version`，为权限和冲突控制提供数据基础。
- 客户端策略覆盖角色、隐私、家庭预算聚合和乐观版本校验。
- 当前 `FamilyService` 在未配置服务端时明确拒绝创建共享关系，避免仅靠客户端隐藏伪装权限安全。
- **代码完成但未实际联调**：邀请生成/接受/过期/撤销、服务端鉴权、跨设备实时同步和冲突合并。

## 阶段十三：广告与推广位（架构和内部推广完成，第三方平台待接入）

- 建立 Placement System，位置包括 `home_promo`、`profile_promo`、`goal_promo`。
- Placement 配置支持 enabled、受众、起止时间、每日频控、优先级、provider 和跳转路由。
- `AdProvider` 抽象 Splash、Native、Rewarded；业务页面不直接依赖广告 SDK。
- 核心路径保护覆盖快速记账、编辑、确认、目标完成、恢复、支付和登录安全页面。
- `ad_free` 权益、Free 受众、新用户 24 小时、每日上限和内容安全分类均由策略层判断。
- 当前展示的是有明确“推广 · 好好记账”边界的内部会员/功能推广，不冒充第三方广告。
- 展示、点击、完成、关闭和广告后退出事件持久化。
- Rewarded 只有用户主动选择且 Provider 回报完成后才发放奖励。
- **代码完成但未实际联调**：第三方广告 SDK、远程后台 Placement 配置和生产埋点上报。

## 数据库与核心文件

- `lib/core/database/app_database.dart`：schema v6、DAO、升级迁移和索引。
- `lib/features/transactions/data/transactions_repository.dart`：流水/余额事务和批量原子写入。
- `lib/features/bookkeeping/`：手动快速记账与附件。
- `lib/features/accounts/`、`categories/`、`budgets/`：账户、分类、预算。
- `lib/features/goals/`：目标创建、节点、贡献、预测和完成。
- `lib/features/analysis/`：统计分析与洞察。
- `lib/features/intelligence/`：商户规则、指纹、经济事件和待确认箱。
- `lib/features/membership/`：会员权益与商业服务契约。
- `lib/features/voice/`：语音识别、文本解析和确认页。
- `lib/features/family/`：家庭模型、权限策略和未配置服务边界。
- `lib/features/ads/`：广告 Provider、Placement 策略、内部推广和事件。

## 自动化验证

- `flutter analyze`：通过，`No issues found`。
- `flutter test`：65/65 通过（含默认干净 seed、旧 seed 清理、交易编辑、转账统计、统计时间段、智能保存管线和账户排序回归测试）。
- 覆盖 SQLite 持久化、账户余额、转账、软删除、批量回滚、预算联动、目标、统计分析、分类/去重、会员权益、语音解析、家庭权限、广告频控/事件和核心 Widget 路由。
- 敏感信息扫描：项目文件中未发现 API key/secret 候选。
- 无 TODO/FIXME/HACK；策略方法中的布尔返回为正常业务分支。

## 构建与 UI 验收

- Android Release：`flutter build apk --release` 通过。
- APK：`build/app/outputs/flutter-apk/app-release.apk`，Flutter 报告 61.2 MB。
- SHA-256：`f336bca978ec8da606678c538188c24d21133db3114a8f9bb3dbe2e252134dc3`。
- iOS：工作区保留历史 `build/ios/iphonesimulator/Runner.app` 和截图，但当前机器没有可用 `xcodebuild`，本轮未能复现构建、安装或模拟器验收。
- Widget 测试覆盖核心页面、小屏布局、筛选/搜索、管理入口和语音确认流程。

## 已知风险与下一步所需输入

1. Xcode 目前位于 `/Users/algive/Downloads/Xcode.app`，系统 `xcode-select` 仍指向 Command Line Tools。建议移到 `/Applications/Xcode.app` 后执行：

   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

2. iPhone 真机/Archive 仍需在 Xcode 为 Runner 选择 Apple Development Team，并配置正式 Bundle ID、证书和 Provisioning Profile；本轮只验证了无签名 Simulator 构建。
3. Android Release 当前仍没有生产 keystore，不能直接提交 Play Console。
4. `speech_to_text` 7.4.0 当前可构建，但 Flutter 提示该插件仍自行应用 Kotlin Gradle Plugin；未来 Flutter 移除兼容后需升级插件或跟进 Built-in Kotlin 迁移。
5. 商业、家庭和第三方广告服务必须在提供旧项目路径、API 协议、测试环境和密钥管理方案后继续真实联调。
6. `quick_add_sheet.dart` 已超过 1,100 行，功能正常且有测试，但后续扩展前建议按表单区块拆分，降低维护成本；本轮未为纯重构扩大改动范围。
7. 交易列表和智能去重目前适合本地中小数据量；数据规模增大或接入云端前应增加分页和时间窗口查询。

## 新窗口继续工作的起点

1. 先阅读本文件、`docs/STAGE_10_ASSET_AUDIT.md` 和对应阶段原始 `.txt`。
2. 运行 `flutter analyze && flutter test`，确认 65 个测试仍通过。
3. 若开始商业/家庭/广告外部联调，先取得服务端协议和测试环境，不要把客户端本地实现标记成云端完成。
4. 若做 iOS 真机发布，先完成 Xcode 全局路径、Signing & Capabilities 和 Bundle ID 配置。
5. 修改数据库表时必须提高 `schemaVersion`、补充 forward-only migration、重新生成 `app_database.g.dart` 并新增升级测试。

## Android 模拟器预览

- 已配置的 AVD：`pixel_7`，Android 16 / API 36，设备分辨率 1080×2400。
- AVD 数据目录：`/Users/algive/.android/avd/pixel_7.avd`。
- Android SDK：`/Users/algive/Library/Android/sdk`。
- 当前设备 ID：`emulator-5554`；本轮已启动并安装 `app-release.apk`，包名为 `com.algive.jizhang_app`。
- 启动模拟器：

  ```bash
  flutter emulators --launch pixel_7
  ```

- 在模拟器中运行项目并支持热更新：

  ```bash
  cd /Users/algive/jizhang_01
  flutter run -d emulator-5554
  ```

- `flutter run` 运行时按 `r` 热更新、`R` 完整重启、`q` 退出。

## 2026-09-07 Luna 历史复核（临时 SQLite 配置，已被最新复核取代）

- `flutter analyze`：通过，`No issues found`。
- `flutter test`：71/71 通过；包含 `audit_probe` 小屏 + 大字体 + 键盘，以及本地保存/编辑/归档引用/父子预算/负金额/transfer/指纹 `bookId` 与 `currency` 回归。
- `flutter build apk --release`：APK 产物为 `build/app/outputs/flutter-apk/app-release.apk`，61,181,930 bytes，SHA-256 `8872a788174fe9676f60d5fdb6aee4d39fb8c501e97a424002a948ea0c74bfdf`。本轮 build session 在最终输出阶段被中断，但该路径的 APK 已生成；下一窗口应重新执行并记录明确的成功行。
- Pixel 7 `emulator-5554`：模拟器启动、APK 卸载旧包并安装成功、`MainActivity` 启动成功；首页 UI dump 显示空账本、本月结余和快速记账入口。
- 模拟器未通过项：干净安装后快速记账账户为“请选择”，默认分类/账户没有加载，SQLite 文件未出现；因此真实新增、编辑、删除、重启持久化均未完成，不能声称已通过。
- 仍未实现：CSV 导入导出、备份恢复、支付/认证/云同步、云 AI、家庭服务端、第三方广告 SDK/后台，以及 iOS 无 Xcode。

## 2026-09-07 最新数据库复核

- `flutter analyze`：通过，`No issues found`。
- `flutter test --reporter compact`：`+39 -32`，共发现 71 个测试；32 个失败均为 macOS 测试主机加载 `libsqlite.dylib` 失败。临时 `source: process` 的 71/71 结果未作为最终配置结论。
- `flutter build apk --release`：通过。APK 路径 `build/app/outputs/flutter-apk/app-release.apk`，60,575,726 bytes，SHA-256 `373420e060ad1dbc83929ddd431499bb1d0e91d727f182f1cc960ebdea260029`。
- `emulator-5554`：APK 卸载/安装成功，`MainActivity` 启动，无 `FATAL EXCEPTION`；首页 UI dump 确认空账本和“本月结余”。Quick Add 账户仍为“请选择”，默认账户/分类未加载，SQLite 文件未生成。
- 根因证据：`sqlite3 3.5.2` hook 的 Android system 输出为 `libsqlite.so`，APK 不含该系统库；seed 在打开应用数据库路径后卡在首个查询。同 isolate `NativeDatabase(file)` 仍卡住。缓存中没有 emulator 所需的官方 x86_64 Android `libsqlite3.so`，需要官方 SHA 校验 native asset 或可审计 NDK/工具链后再完成 emulator CRUD/重启验收。
- 模拟器真实新增、编辑、删除、强制停止后重启持久化：未完成，不能声称通过。
