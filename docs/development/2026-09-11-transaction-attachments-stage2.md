# 阶段二执行记录：独立附件记录与旧 metadata 迁移

日期：2026-09-11

## 结论

阶段二的第一项“独立附件记录和旧 `metadata.attachments` 迁移”已完成。当前 schema 从 10 升到 11，新建和编辑流水会把附件写入独立表；打开旧数据库时会把可识别的 metadata 附件迁移为记录，并保留标签等其他 metadata。

本切片没有把附件文件复制进备份包，也没有加入共享同步协议。SQLite 中的附件记录会随数据库导出，但外部文件内容仍不在备份范围内；这两项属于后续切片。

## 问题原因

- 旧流程只在交易 `metadata_json` 中保存附件路径数组，不能按附件查询、排序、软删除或为后续备份/同步提供稳定 ID。
- 详情页和编辑页只能解析旧 JSON，无法确认当前账本的独立附件状态。
- 旧数据可能包含字符串路径、带 `path` 的对象、重复路径或 malformed 项，迁移必须避免重复和静默丢失异常信息。

## 修改文件与核心逻辑

- `lib/core/database/app_database.dart`
  - 新增 `transaction_attachments` 表，包含账本、交易、路径、文件名、MIME、顺序、大小/校验和预留字段、创建/更新时间和软删除时间。
  - schema 10→11 创建表和索引；迁移只在旧交易表存在 `metadata_json` 时读取，兼容极简旧 schema。
  - 可识别路径去重后写入独立记录；保留 malformed 附件项，删除已成功迁移的旧 `attachments` 字段但不改动其他 metadata。
- `lib/features/transactions/data/transaction_attachment_repository.dart`
  - 增加按 `bookId + transactionId` 隔离的查询、响应式订阅和替换接口。
  - 替换时保留可复用记录 ID，删除项软删除，重新添加项可恢复；输入路径去空并去重，顺序由 `sortOrder` 保持。
- `lib/features/transactions/domain/transaction_attachment.dart`
  - 扩展附件领域模型，支持独立记录的 ID、账本、交易、MIME、顺序、大小和校验和，同时保留旧 metadata 解析能力。
- `lib/features/bookkeeping/application/quick_bookkeeping_service.dart`
  - 手动记账 Provider 接入附件 Repository；新链路不再把附件数组写回交易 metadata，新建/编辑后同步替换独立记录。
  - 附件写入失败沿用 `BookkeepingCommittedException`，明确“流水已入账但附件后处理失败”，不触发隐式重复记账。
- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`
  - 编辑已有流水时优先加载独立附件，旧 metadata 作为兼容回退；保存会等待附件加载完成，避免快速点击保存清空附件。
- `lib/features/transactions/presentation/transaction_detail_page.dart`
  - 详情优先展示独立附件，保留旧 metadata 快照的即时兼容展示和缺失文件状态。
- `lib/core/database/app_database.g.dart`
  - 由 Drift 重新生成，包含新表、Entity、Companion、DAO 和表管理器。
- `test/transaction_attachment_repository_test.dart`、`test/quick_bookkeeping_service_test.dart`、`test/transaction_detail_test.dart`、`test/asset_management_test.dart`
  - 覆盖独立记录隔离、顺序、软删除、schema 10→11 迁移、malformed 保留、新记账/编辑链路和 schema 版本更新。

## 验证结果

```text
dart run build_runner build
→ 成功生成 Drift 输出

flutter analyze
→ No issues found

flutter test --reporter compact
→ All tests passed（165 个）

flutter build apk --release
→ Built build/app/outputs/flutter-apk/app-release.apk（77,656,758 bytes）
→ SHA-256: ea3a57599c3b5d1d52598bb93ce2eae304d89130676d31b77fdce80b54464de1

adb devices
→ 当前无连接设备；本次未安装 APK，未做模拟器/真机 UI 验收
```

Release 构建仍有既存 `speech_to_text` 使用 Kotlin Gradle Plugin 的未来兼容性 warning，但构建成功。

## 未完成与风险

1. 当前备份会包含 `transaction_attachments` 的 SQLite 记录，但不会包含附件文件本身；附件文件没有 manifest、校验和计算、加密、随数据库安全暂存和回滚。
2. 独立附件表暂未加入 `SharedSyncSchema.syncKinds`，共享账本的附件不会随现有交易同步；必须等阶段三定义附件同步协议后接入。
3. 附件文件仍由 `AttachmentStorageService` 放在应用文档目录，记录软删除不会立即物理删除文件；清理策略应和备份/恢复一起设计。
4. 附件记录是在核心流水提交后的本地次级写入，失败会显式报告但不会回滚已提交流水；后续如要求严格原子性，需要把附件写入纳入记账事务边界。
5. iOS 项目仍被既有 `Application not configured for iOS` 配置问题阻断，未完成 iOS 编译和真机验收。

## 下一步

优先设计“数据库＋附件文件”的版本化备份包：先生成 manifest 和 SHA-256，安全暂存数据库与附件，校验全部通过后再切换 pending restore；失败时保留当前数据和可恢复的安全副本。完成本地备份/恢复验收后，再进入押金/结算模型与附件云同步协议。
