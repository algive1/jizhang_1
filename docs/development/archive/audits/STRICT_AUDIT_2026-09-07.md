# 严格审查与实施清单（2026-09-07）

## 结论与审查方法

当前是具有真实 SQLite 持久化能力的 Flutter 本地记账应用，不能按十三阶段完整产品验收。手动记账、账户余额事务、目标贡献、预算和部分统计已落地；云端商业、家庭共享、云 AI 和第三方广告仍缺真实系统。此次对照根目录十三阶段需求、历史交接文件、UI → Service → Repository → DAO 链路，并重新运行检查。代码通过测试不代表所有需求完成。

初始基线：`flutter analyze` 无问题；`flutter test` 实际 64 个通过（旧文档写 65，不应沿用）。没有 `.git`，修改前源码快照在 `/tmp/jizhang-audit-20260907/source-before.tgz`。当前无 Android 真机连接，有 Pixel 7 模拟器；没有完整 Xcode。

## 需求覆盖

| 阶段 | 状态 | 真实能力与缺口 |
| --- | --- | --- |
| 1–3 基础与视觉 | 本地基础可用 | 四 Tab、主题、路由存在；旧截图不能替代本轮交互验收；装饰图标与占位入口误导可操作性 |
| 4 数据持久化 | 部分完成 | SQLite、软删除、流水余额事务可用；编辑元数据、归档引用和服务事务边界需修复；缺迁移覆盖 |
| 5 快速记账 | 部分完成 | 支出/收入/转账真实保存；OCR 未接；附件只存储缺查看；编辑未回填标签附件；扩展类型缺专用体验 |
| 6 账户分类预算 | 部分完成 | 新增编辑归档排序、月预算可用；父分类预算不汇总子分类；归档账户缺恢复入口；多币种/负债口径未完善 |
| 7 目标 | 核心闭环可用 | 创建、贡献、节点、预测已实现；进一步核查编辑、校准和庆祝的异常边界 |
| 8 统计 | 部分完成 | 热力图、分类比较、基线可用；月度比较窗口、异常持续时长、全量加载性能需要优化 |
| 9 智能分类去重 | 本地链路可用 | 规则、指纹、待确认箱存在；没有文件导入入口；跨渠道经济事件确认不等于消除重复统计 |
| 10 商业基础 | 契约/说明页 | Free 本地权益；导出备份被展示但没有实现；认证、订单、支付、存储、云同步未接 |
| 11 语音 | 本地链路部分完成 | 系统 ASR + 规则解析 + 确认；云 ASR/LLM 未注入；需真机权限与中文识别验收 |
| 12 家庭 | 模型/策略/说明页 | 未配置服务端，不能创建真实共享关系；邀请、远端鉴权和冲突合并未实现 |
| 13 广告 | 内部推广可用 | 配置策略与本地事件存在；第三方 SDK、后台、生产上报未接 |

## 已确认的问题（修复状态在末尾更新）

### P1：保存成功与失败边界不一致

`quick_bookkeeping_service.dart` 中 `createAll` 先提交流水/余额，再写上次账户与分类/去重；任一步后处理失败都会向 UI 抛出保存失败。`voice_bookkeeping_sheet.dart` 保存后还独立写商户记忆，同样存在误导重试风险。必须建立覆盖本地写入的真实事务，或返回明确的已提交结果及可恢复的后处理状态，不能吞异常或固定成功。验收：故障注入后要么全部回滚，要么 UI 明确已入账且不能重复提交。

### P1：编辑会丢字段，标签/附件无法可靠修改

`QuickAddSheet.initState` 不回填 tags/attachments；`QuickBookkeepingService._toRecord` 未保留 `subcategoryId/isLargeTransaction`，只要新 metadata 非空就覆盖未知键，而空 metadata 又回退旧内容，无法清空。必须完整回填、按字段更新、保留未知元数据；验证备注修改不破坏子分类/大额标记，单独改标签不丢附件，支持清空。

### P1：归档引用静默改账

流水映射只查 active categories，归档后历史分类名称丢失。快速编辑仅查 active 账户/分类，找不到原 ID 就回退第一个，可能把旧账余额影响转移至别的账户。归档不能改变历史事实。编辑应保留原引用或要求明确重选；禁止静默替换。

### P1：父分类预算漏算子分类

`BudgetRepository.calculateOverview` 仅比较 `transaction.categoryId == budget.categoryId`，二级分类支出不计入父预算。需兼容现有子分类 ID 直接保存方式与 `subcategoryId` 结构，避免重复计算；补实际余额/预算联动测试。

### P2：个人页与首页的状态并非真实数据

`profile_page.dart` 固定连续记账 `28 天`、提醒 `每日 22:00`；多个条目仅弹“尚未实现”，头部通知/设置只是 Icon。Free 权益宣称导出/备份但没有入口。首页 `forecastBalance` 只是本月收支差，却展示“预计”。应使用真实记账日期计算连续天数；未开放能力在点击之前明确状态；没有预测模型就称“本月结余”。

### P2：统计与性能边界

月度上一期由当前月份天数倒推，月份长度不同可能混入另一月；本月全月与上月全月直接比较也有期长偏差。大额分布阈值在每笔筛选中重复排序全历史，数据量增长会明显拖慢；流水、分析和去重依赖 `getAll/watchAll`。先修月度边界和重复计算，再做 SQL 时间窗口/分页与基准测试。

### P2：缺少可带走数据的完整闭环

没有 CSV 导入、CSV 导出、含附件的版本化备份与恢复。推荐顺序：先做真实 CSV 导出/明确格式导入；再做完整备份预览、校验、冲突/覆盖策略及失败回滚。普通 CSV 不应命名为完整备份。

### 外部阻塞

客户端不得内置供应商秘密密钥。用户给出的 API key 不足以确定端点、模型、授权、隐私及服务端协议，此次不复制密钥到源码或文档。商业、云 AI、共享和广告接入需已有服务端代码/协议与测试环境；不能用 Mock 冒充完成。

## Luna 实施计划

由一个 `gpt-5.6-luna` 子代理分批实施，主代理继续审查剩余链路、UI 和结果。

1. 修复本地保存事务边界及编辑字段完整性，覆盖语音商户记忆。
2. 修复归档历史引用与父子分类预算联动。
3. 清除固定个人状态、虚假提醒及不可操作的导航暗示，校正首页文案。
4. 根据主代理复核追加已证实的统计、数据导入导出和样式问题。

每个切片先读代码，最小修改，运行相关测试。最终运行 analyze、全量 test、Android release build。不得修改生产数据、发起付费 API 调用、编造外部联调成功；不做无关架构重写。最终交付文档记录已修、未修、验证证据与下一窗口入口。

## 历史复核（临时 SQLite 配置，已被最新复核取代）

本轮复核结果：`flutter analyze` 通过；Flutter 全量测试在测试主机使用可用的 SQLite FFI 配置时为 71/71 通过，包含小屏、大字体、键盘审计。Android release APK 产物存在，路径为 `build/app/outputs/flutter-apk/app-release.apk`，大小 61,181,930 bytes，SHA-256 为 `8872a788174fe9676f60d5fdb6aee4d39fb8c501e97a424002a948ea0c74bfdf`。

Pixel 7 `emulator-5554` 已启动并安装 APK，`MainActivity` 可启动且没有 `FATAL EXCEPTION`；UI dump 确认首页空账本、“本月结余”和快速记账入口。干净安装后默认账户/分类未出现在快速记账选择器，应用数据目录未生成可检查的 SQLite 文件，故真实新增、编辑、删除、重启持久化均未验收，不得标记为通过。

SQLite native asset 配置仍是本轮外部阻塞：`source: sqlite3` 构建需要下载 GitHub 二进制且网络超时；`source: process` 可通过 macOS 测试但 Android 进程无法提供可用 FFI 符号；当前源码已恢复原 Android `source: system/name: sqlite` 配置。CSV 导入导出、备份恢复、支付/认证/云同步、云 AI、家庭服务端、第三方广告和 iOS 无 Xcode 等缺口继续保留。

## 2026-09-07 最新复核（数据库阻塞）

- `flutter analyze`：通过，`No issues found`。
- `flutter test --reporter compact`：发现 71 个测试，`+39 -32`，退出码 1。32 个失败均为 macOS 测试主机无法加载 `libsqlite.dylib`；当前 `pubspec.yaml` 使用 Android 系统库 `source: system/name: sqlite`，不能把先前临时 `source: process` 的 71/71 结果当作最终配置结果。
- `flutter build apk --release`：通过。APK 为 `build/app/outputs/flutter-apk/app-release.apk`，60,575,726 bytes，SHA-256 `373420e060ad1dbc83929ddd431499bb1d0e91d727f182f1cc960ebdea260029`。
- Pixel 7 `emulator-5554`：已卸载旧包、安装成功并启动 `MainActivity`；首页 UI dump 可见“我的账本”“本月结余”“最近交易”和空账本入口，没有 `FATAL EXCEPTION`。
- 数据库 P0：Quick Add 账户为“请选择”，默认账户/分类没有加载，`run-as` 检查不到 `haohao_jizhang.sqlite`。日志证据是 seed 在打开 `/data/user/0/com.algive.jizhang_app/app_flutter/haohao_jizhang.sqlite` 后不再进入首个版本查询；同 isolate `NativeDatabase(file)` 也未改变结果。真实新增、编辑、删除、强制停止后重启持久化全部未验收。
- 依赖检查：`sqlite3 3.5.2` 包内文档确认 `source: system` 只查找系统动态库，默认 `source: sqlite3` 才提供官方预编译库；本地缓存仅有 arm Android ELF 和 macOS x64 dylib，没有 emulator 所需的 x86_64 Android 库。下一步需要官方包 SHA 校验下载或可审计 NDK/工具链配置，不能使用未校验二进制或 Mock 数据。

## 2026-09-07 P0 复核更新

上述数据库阻塞已通过官方 native asset 机制解决。`pubspec.yaml` 使用 `sqlite3 3.5.2` 的 `source: sqlite3`，并把 `url_pattern` 固定到官方 GitHub release；hook 使用包内 SHA-256 清单校验资产。直接验证的 Android x86_64 与 arm64 文件分别匹配 `949965f0eba976f707ae364cdcb42c342b5f0626081f8d7f0378fb7b52848772` 和 `0c2d3bfc8c87abceb21ed72a4bb49964121c5fe1a8ef3848d83ba907d01b6161`。APK 构建产物包含 arm64-v8a、armeabi-v7a、x86_64 三套 `libsqlite3.so`，发布包不依赖系统 `libsqlite.so`。

最终证据：`flutter analyze` 通过；`flutter test --reporter compact` 为 71/71；`flutter build apk --release` 通过并生成 65.7 MB APK。干净安装到 Pixel 7 x86_64 AVD 后创建 SQLite 文件，查询得到 4 个账户、20 个分类和 `seed_version=5`。真实 UI 验收已完成保存、编辑、删除和强制停止/重启后的持久化检查；删除使用软删除，重启后记录仍在数据库但不再出现在流水列表，账户余额保持 0。

这项修复仍有构建网络前提：首次缺失的官方 ABI asset 需要从 GitHub release 获取；没有把未校验二进制写进仓库。其它外部系统缺口（云同步、支付、第三方广告、iOS 真机等）不属于本 P0。
