# Luna 实施与验收记录（2026-09-07）

## 本轮结论

本轮完成源码复核、数据库 native asset 检查、分析、Flutter 测试和 Android release 产物检查。当前工作区没有 `.git`，没有重置或覆盖其他改动，也没有读取、写入或调用用户提供的 API key。

## 已完成

- `flutter analyze`：通过，`No issues found`。
- `flutter test`：当前 `source: system/name: sqlite` 配置下发现 71 个测试，39 个通过、32 个失败；失败均在 macOS 测试主机加载缺失的 `libsqlite.dylib` 时触发，不是删除或放宽断言。此前使用临时 `source: process` 配置的 71/71 结果不代表当前最终配置。
- `test/audit_probe_test.dart`：本轮被 SQLite FFI 初始化失败阻断，未修改或放宽小屏、大字体、键盘断言。
- Android release APK 产物：`build/app/outputs/flutter-apk/app-release.apk`，60,575,726 bytes（60.6 MB），SHA-256 `373420e060ad1dbc83929ddd431499bb1d0e91d727f182f1cc960ebdea260029`。
- 模拟器：Pixel 7 AVD 已启动到 `emulator-5554 device`，APK 卸载旧包后安装成功，包名 `com.algive.jizhang_app`，启动 Activity 为 `MainActivity`，未观察到 `FATAL EXCEPTION`。
- 模拟器首页 UI dump 能确认“我的账本”“今日安心可花”“本月结余”“最近交易”和空账本文案；Quick Add 页面可以打开。

## 模拟器未完成项

干净安装后的 APK 首页为空账本，Quick Add 中账户显示“请选择”，账户选择列表和分类列表没有默认项，应用数据目录中也没有生成可检查的 SQLite 文件。因此不能真实声称默认分类/账户加载、新增、编辑、删除和重启持久化已通过。

排查期间验证到：`source: system/name: sqlite` 生成的 hook 输出是 Android `dynamic_loading_system`、URI `libsqlite.so`；APK 不含 sqlite native 库，这是系统库方案的预期。将 Drift Android 连接从 `NativeDatabase.createInBackground` 改为同 isolate `NativeDatabase(file)` 后，debug/release 仍停在打开数据库路径，未完成首个 seed 查询。`source: process` 可使 macOS SQLite 测试通过，但 Android 进程没有可用的 Dart FFI SQLite 符号；显式加载 `libsqlite.so` 未改变结果。依赖缓存只找到官方 `sqlite3-3.5.2` 的 arm Android ELF 和 macOS x64 dylib，没有 Pixel 7 x86_64 对应的完整 `libsqlite3.x64.android.so`；该文件需要按包内 SHA 校验从官方 native asset 源获取。没有把外部二进制写入项目，也没有继续尝试其他配置。

由于模拟器数据链路仍未确认，以下操作状态均为未完成：真实新增一笔、编辑金额/备注、删除、强制停止后重启读取。

## 当前 P0 阻塞

需要为 `sqlite3 3.5.2` 提供可用的 Android x86_64 native asset，或升级到已验证能在当前 Flutter/Dart hooks 环境完成 Android system SQLite 加载的依赖/工具链。安全下一步是允许官方包按其内置 SHA-256 校验获取 `libsqlite3.x64.android.so`，或由 Android NDK/应用构建链提供可审计的 SQLite；不能用未校验二进制、Mock 数据库或业务层固定数据绕过。

## 明确未实现

CSV 导入导出、含附件的备份恢复、支付与认证、云同步、云 AI、家庭共享服务端、第三方广告 SDK/后台上报、iOS Xcode 构建和真机语音权限验收仍未实现或未联调。代码完成不等于这些外部系统已接通。

## 下一窗口入口

先解决 `sqlite3` 在 Android 与 macOS 测试环境的统一 native asset/FFI 配置，再在干净模拟器上完成默认账户/分类、新增、编辑、删除和重启验收；完成后重跑 `flutter analyze`、`flutter test` 和 `flutter build apk --release`，更新本文件与两份状态文档。

## 2026-09-07 首页安心可花卡片溢出修复

### 根因

`_CalmSpendingCard` 原来把卡片高度固定为窄屏 `184`、其他屏幕 `150`，并把正文放在 `Positioned.fill` 中。正文 `Column` 使用 `Spacer` 把状态文案推到底部；系统字体放大后，标题、金额、本月结余和未设置预算的第二行文案的自然高度超过固定高度，因而在 Android 设备上触发 `BOTTOM OVERFLOWED BY 21 PIXELS`。已设置预算时，正文列宽较窄，大字体下状态行也可能横向溢出。

### 修改

- `lib/features/home/presentation/home_page.dart`：卡片高度改为保留原视觉高度的 `minHeight`，正文改为 Stack 的非定位自然尺寸子节点，内容变高时卡片随内容增长。
- 移除依赖固定高度的 `Spacer`，让底部状态文案参与自然布局；预算状态使用可换行的 `Wrap`，金额继续通过 `FittedBox` 适配宽度。
- 背景图片继续使用 Stack 中的定位子节点，并先于正文绘制；正文列按卡片宽度保留文字安全区，文字始终位于装饰图上层。
- `test/audit_probe_test.dart`：增加 `360x800 + textScale 1.3 + 无预算` 和 `393x873 + textScale 1.6 + 已设置预算` 的 widget 回归覆盖，并为卡片专项测试注入空交易列表，避免既有 `TransactionTile` 的独立大字体横溢出干扰结果。

### 验证与剩余风险

- 卡片专项测试：3/3 通过，包含原有 `320x568 + textScale 1.3 + 键盘` 测试。
- `flutter analyze` 已通过；本轮卡片专项 `flutter test test/audit_probe_test.dart` 为 3/3 通过。
- 全量 `flutter test --reporter compact`：73 tests passed，无失败；本轮未出现 SQLite native asset/FFI 初始化失败。
- `flutter build apk --release`：通过，产物为 `build/app/outputs/flutter-apk/app-release.apk`，65,749,140 bytes（65.7 MB），SHA-256 `1cf8fe269f9fee493d2bf9ed89563e5eb85bccfc4748af04c16ccbd3c06964a0`。
- 构建仅输出 `speech_to_text` 使用旧 Kotlin Gradle Plugin 的未来兼容性 warning；本次 release APK 已成功生成。

## 2026-09-07 P0 完成复核

### 根因

`source: system/name: sqlite` 让 `sqlite3 3.5.2` 通过 `dynamic_loading_system` 查找 Android 的 `libsqlite.so`。在当前 Flutter 3.47.2 / Dart 3.13.2 的 x86_64 AVD 上，`NativeDatabase` 返回后第一次 `sqlite3.openInMemory()` 即卡住，数据库文件不会创建；因此 seed 首个查询无法完成。后台 isolate 与同 isolate 连接方式都不能修复系统库 ABI/FFI 调用问题。

### 修复

`pubspec.yaml` 改用 `source: sqlite3`，并显式指定官方 GitHub release URL pattern：

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3
      url_pattern: https://github.com/simolus3/sqlite3.dart/releases/download/$RELEASE_TAG/$FILENAME
```

这是 `sqlite3 3.5.2` 官方 hooks 机制；hook 会按包内 `asset_hashes.dart` 校验下载内容。官方直链实测得到 x64 Android SHA-256 `949965f0eba976f707ae364cdcb42c342b5f0626081f8d7f0378fb7b52848772`，arm64 Android SHA-256 `0c2d3bfc8c87abceb21ed72a4bb49964121c5fe1a8ef3848d83ba907d01b6161`。APK 包含 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三套 `libsqlite3.so`，不依赖系统 SQLite。

### 命令证据

- `flutter analyze`：通过，`No issues found`。
- `flutter test --reporter compact`：通过，`71 tests passed`。
- `flutter build apk --debug`：通过；APK 含三种 Android ABI 的 `libsqlite3.so`。
- `flutter build apk --release`：通过，生成 `build/app/outputs/flutter-apk/app-release.apk`（65.7 MB）。
- 干净安装 `emulator-5554`（Pixel 7 `x86_64` AVD）后，`run-as` 导出数据库并查询：SQLite user version 6、4 个账户、20 个分类、`seed_version=5`。
- UI/数据库验收：Quick Add 保存 ¥123；流水页编辑金额并同步账户余额；删除后写入 `deleted_at` 且账户余额恢复；强制停止/重启后软删除状态与余额仍保持。

### 剩余限制

官方 native asset hook 首次构建需要访问 GitHub release；项目不提交二进制库，也不使用用户提供的 API key。发布 APK 已同时包含 arm64、arm32 和 x86_64 资产，真实 arm64 设备不受 AVD 架构限制。CSV 导入导出、备份恢复、云服务、支付、第三方广告和 iOS 真机仍未联调。

## 2026-09-07 RenderFlex 警戒线复核

### 复现结论

本次针对用户反馈的黄色/黑色警戒线进行了真实 Flutter debug 复现，但没有在当前源码中复现原始截图对应的 `RenderFlex overflow`，因此不把截图来源臆测成某个 Widget。

- `test/audit_probe_test.dart` 原有首页、预算状态、Quick Add/键盘场景与新增矩阵共 `5/5` 个 widget tests 通过。
- 首页矩阵覆盖 `320×568`、`360×800`、`393×873`，`textScaleFactor 1.3/1.6`，有预算/无预算，共 12 个场景；统一捕获 `FlutterErrorDetails`，结果为 0 条 `RenderFlex` 错误。
- `GoalProgressCard` 专项矩阵覆盖上述三种尺寸与两档字体，共 6 个场景；结果为 0 条错误。
- `flutter analyze`：通过，`No issues found`。

### 源码检查范围

- `lib/features/home/presentation/home_page.dart:161-289`：`_CalmSpendingCard` 使用自然高度 `minHeight`，正文不再依赖固定高度和 `Spacer`。
- `lib/core/widgets/app_bottom_navigation.dart:13-117`：底部导航固定 78 logical pixels，导航项使用最小尺寸 Column；目标字体矩阵无溢出。
- `lib/core/widgets/goal_progress_card.dart:20-116`：目标卡主体；标题 Row 位于 `:30-61`，目标卡专项矩阵无横向或纵向溢出。
- `lib/core/widgets/quick_add_button.dart:17-27`：FloatingActionButton 本身未产生布局错误。

### Pixel 7 debug AVD 证据

Pixel 7 AVD 在 debug APK 上检查了默认 `1080×2400`，以及强制 `wm size 320x568`、density 160、system `font_scale 1.6` 的页面。首页卡片、Insight、最近交易和底部导航截图均无黄黑警戒线；`adb logcat` 未出现 `RenderFlex`、`overflow` 或 `FATAL EXCEPTION`。

当前无法从这次复现确认用户原始警戒线来自首页卡片、目标卡、底部导航或系统 debug overlay。若用户仍看到旧警戒线，应先卸载旧 APK/清理旧 debug session，再执行 `flutter clean` 后重新 `flutter run` 或安装最新 release APK；release 构建不会显示 Flutter debug overflow stripes，但源码布局测试仍必须保持通过。

## 2026-09-08 流水删除与中文日期修复

### 根因与修复

- 删除按钮链路本身完整：`TransactionTile` → `showTransactionActions` → 确认弹窗 → `TransactionController.delete` → `TransactionRepository.softDelete`。数据库事务会按流水类型回滚账户余额、写入 `deletedAt`，重复删除会直接返回。问题在动作完成后没有显式刷新流水和账户 provider，异常又被统一吞成“稍后重试”，使旧页面或搜索结果看起来没有删除。
- `transaction_actions.dart` 现在在成功后 invalidate `transactionsProvider` 和 `accountsProvider`，失败时保留真实异常文本并提供“重试”操作。底层 `watchActive`/`getActive` 继续过滤软删除记录，因此流水和搜索均不会显示已删除记录。
- 新增 `TransactionDateFormatter`，统一提供中文月份、星期、今天/昨天/前天、跨月/跨年日期及 24 小时时间；流水分组、流水 tile 和搜索结果共用格式。`main.dart` 初始化 `zh_CN` 的 intl 日期数据，展示 formatter 使用确定的中文映射保证测试和启动早期不出现英文。

### 验证

- `flutter analyze`：通过，`No issues found`。
- `flutter test test/transaction_date_formatter_test.dart test/database_repository_test.dart test/widget_test.dart --reporter compact`：13 tests passed，覆盖中文相对日期、星期、跨月/跨年、软删除、余额回滚、重复删除、确认弹窗。
- 已尝试将 widget 测试切换为真实 Drift stream 验证列表/搜索实时刷新；数据库更新可触发刷新，但 Riverpod/Drift stream teardown 在测试框架中留下 pending timer，因此未将不稳定的测试夹具提交。生产 provider 仍使用真实 `watchActive` stream，并增加了显式 invalidate 作为刷新兜底。

### Release APK

- `flutter build apk --release`：通过（Gradle `assembleRelease`，71.5s）。
- 绝对路径：`/Users/algive/jizhang_01/build/app/outputs/flutter-apk/app-release.apk`。
- 文件大小：66,027,668 bytes（66.0 MB decimal，63.0 MiB）。
- SHA-256：`772b83220160a8fbc6ca05933dededfc49fd5082443e2495ad225cf9e2946daf`。
- 构建仅有 `speech_to_text` 使用旧 Kotlin Gradle Plugin 的未来兼容性 warning；不影响本次 APK 生成。

## 2026-09-08 流水操作入口与搜索删除行为

### 根因与交互决策

- `TransactionTile` 原来只有点击事件，`TransactionDateGroup` 和搜索结果没有长按透传；因此删除虽有完整的数据链路，用户无法通过长按发现操作。
- 现在点击和长按都打开同一个操作菜单。菜单继续提供“编辑流水”“修改分类”（转账不适用时隐藏）和“删除流水”；删除保留二次确认，文案明确会同步撤销账户余额影响。
- `TransactionTile` 增加了 `Semantics` label/hint，TalkBack/VoiceOver 可获知交易内容以及点击或长按操作。没有加入左滑立即删除、批量删除或伪造撤销入口。
- 当前 repository 没有安全的 restore API；删除后只展示成功反馈，失败展示真实错误和“重试”，不把不可验证的撤销动作伪装成已实现。

### 修改文件

- `lib/core/widgets/transaction_tile.dart`：增加 `onLongPress` 与无障碍语义。
- `lib/core/widgets/transaction_date_group.dart`：透传每笔记录的长按回调。
- `lib/features/transactions/presentation/transactions_page.dart`：点击/长按共用操作处理器。
- `lib/features/transactions/presentation/transaction_search_page.dart`：搜索结果支持点击/长按操作，并复用分类修正弹层。
- `lib/features/transactions/presentation/transaction_actions.dart`：共享分类修正入口，保留删除确认、provider 刷新、失败重试。
- `test/widget_test.dart`：覆盖主列表点击/长按共用菜单，以及搜索结果长按删除后记录消失。
- `test/database_repository_test.dart`：覆盖消费、收入、转账删除的余额回滚和重复删除幂等。

### 验证

- 上述相关 widget 与 repository 测试通过，共 13 tests passed。
- 搜索行为测试使用“每次 provider 重算从真实 repository 读取一次”的夹具，避免 Drift query stream teardown 的测试 timer；业务删除仍走真实软删除事务。
- 本轮最终验证：`flutter analyze` 通过（`No issues found`）。
- `flutter test --reporter compact` 通过，`80 tests passed`；期间仅出现 Drift 测试夹具重复创建数据库的 warning，没有 SQLite P0 失败。
- `flutter build apk --release` 通过（Gradle `assembleRelease`）；构建日志只有 `speech_to_text` 使用旧 Kotlin Gradle Plugin 的未来兼容性 warning，不影响 APK 生成。

### 本轮最终 APK

- 绝对路径：`/Users/algive/jizhang_01/build/app/outputs/flutter-apk/app-release.apk`。
- 文件大小：66,027,668 bytes（66.0 MB decimal，63.0 MiB）。
- SHA-256：`07537ef5ddc03d1b963efa5419354c3774d711834ebc025eb6beeb7b31c08668`。
- 安装命令：`adb install -r /Users/algive/jizhang_01/build/app/outputs/flutter-apk/app-release.apk`。
