# 账本抽屉执行记录：切片 5——交易详情与附件本地预览

日期：2026-09-11

## 结论

阶段一的交易详情入口已完成并通过 Android 模拟器验收：首页、流水列表和搜索结果现在统一为“点击看详情、长按看操作菜单”。详情页不会把传入列表快照当作写入授权，编辑/分类修正/软删除仍复用当前账本 Repository 和既有操作菜单链路。

本切片只完成本地体验和旧数据兼容读取。附件仍来自交易的 `metadata.attachments` 路径；独立附件记录、迁移、完整数据库＋附件备份和云同步不属于本切片，不能标记为已完成。

## 问题原因

- 原有 `TransactionTile` 的点击行为直接打开编辑/删除操作菜单，首页、流水和搜索入口无法查看一套统一的只读详情。
- 交易模型已经保留 `metadataJson`，旧记账流程把附件路径写入 `metadata.attachments`，但没有独立的附件读取模型、文件存在性判断或平台打开桥接。
- Android/iOS 没有为本地文件提供统一的 MethodChannel；直接把路径交给外部应用还会遇到文件缺失、没有处理器和应用沙箱路径越界等错误。

## 修改文件与核心逻辑

- `lib/features/transactions/presentation/transaction_detail_page.dart`
  - 新增交易详情页，展示金额、类型、发生时间、账户/转入账户、分类、备注、记录人和同步状态。
  - 解析旧 `metadata.attachments`，图片显示缩略图并支持 `InteractiveViewer` 全屏缩放；PDF 和其他文件显示类型图标并请求系统打开。
  - 异步检查附件存在性；缺失时保留流水记录，显示“文件未找到”和“重新添加”，不把丢文件当成删除流水。
  - 编辑返回后重新从当前账本查询；更多操作复用现有分类修正、软删除和权限链路。
- `lib/features/transactions/domain/transaction_attachment.dart`
  - 为旧 metadata 路径建立轻量读取模型，统一文件名、扩展名、图片/PDF 判断，并对 malformed metadata 给出可见提示。
- `lib/features/bookkeeping/application/local_file_opener.dart`
  - 封装 MethodChannel 调用、存在性预检、MIME 类型和 `missing/noHandler/unsupported` 结果；避免平台错误被伪装成打开成功。
- `lib/core/database/app_database.dart`、`lib/features/transactions/data/transactions_repository.dart`
  - 增加按当前账本、可见性和未软删除条件读取单笔流水的 `getById`。
  - 最近交易查询增加 `onlyOccurred`，在 SQL 层先排除未来流水再限制 10 条；完整流水查询口径不变。
- `lib/features/transactions/presentation/transaction_actions.dart`、`lib/app/router/app_router.dart`
  - 增加 `/transactions/:transactionId` 路由和统一详情导航 helper；路由支持列表传入快照，也可在无快照时按当前账本重新查询。
- `lib/features/home/presentation/home_page.dart`、`transactions_page.dart`、`transaction_search_page.dart`、`lib/core/widgets/transaction_tile.dart`
  - 三个入口点击进入详情，长按继续打开操作菜单；更新无障碍 label/hint。
- `android/app/build.gradle.kts`、`AndroidManifest.xml`、`res/xml/file_paths.xml`、`MainActivity.kt`
  - 使用受限 `FileProvider` 和 `ACTION_VIEW` 打开应用文件目录内的附件；无处理器、非法路径、文件缺失和安全拒绝均返回明确结果。
- `ios/Runner/AppDelegate.swift`
  - 增加文件打开 MethodChannel；检查文件存在性和 app sandbox 目录，解析 symlink 后拒绝越界路径。
- `test/transaction_detail_test.dart`、`test/home_recent_transactions_test.dart`、`test/widget_test.dart`
  - 覆盖 metadata 解析、文件缺失/系统处理器结果、图片缩略图与缩放预览、PDF 无处理器提示、单笔流水账本隔离/软删除、入口点击与长按、未来流水过滤。

## 验证结果

```text
flutter test test/home_recent_transactions_test.dart
→ All tests passed（3 个）

flutter test test/transaction_detail_test.dart
→ All tests passed（5 个）

flutter test --reporter compact
→ All tests passed（162 个）

flutter analyze
→ No issues found

flutter build apk --release
→ Built build/app/outputs/flutter-apk/app-release.apk（77,607,562 bytes）
→ SHA-256: 76576e3e8b1b34d11e4d4875f8387923cc9c179272704597d90f98bf5a445bc8

adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
→ Success；Pixel 7 Android emulator 已打开当前版本交易详情页

flutter build ios --no-codesign
→ 未进入编译：Application not configured for iOS
```

模拟器当前检查到：标题、编辑/更多操作、支出金额、发生时间、账户、分类、记录人、同步状态、附件空状态和底部导航均可见；状态栏图标在米白背景上可读。当前截图为本机临时文件 `/tmp/jizhang-slice5-release-final.png`，模拟器窗口保持在详情页供人工继续查看。

## 未完成与风险

1. 阶段二尚未建立独立附件表，也未执行旧 `metadata.attachments` 迁移；当前仍是兼容读取，不具备附件级版本、校验和、删除策略或随备份恢复能力。
2. Android 的 PDF/其他文件依赖系统已有处理器；没有处理器时会显示明确提示。PDF 当前是系统应用预览，不是应用内 PDF renderer。
3. iOS 项目当前不能进入编译，虽然 MethodChannel 代码已加入 sandbox 校验，但尚未完成 iOS 模拟器/真机联调；不能声称 iOS 已验收。
4. 最近交易的 `occurredAt <= now` 在 SQL 查询创建/失效时计算；应用长时间前台停留时，未来流水到点后需等页面/Provider 刷新才会出现。若要求到点自动出现，需要单独增加定时刷新策略。
5. Release APK 未配置正式 keystore，只能用于本地模拟器验收；构建仍有既存 `speech_to_text` KGP 未来兼容性 warning。

下一切片建议先做阶段二的独立附件记录和迁移设计，再把备份纳入附件文件、校验和、加密/回滚边界，最后才进入云同步协议。
