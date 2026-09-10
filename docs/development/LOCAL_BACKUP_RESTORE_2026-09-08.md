# 本地完整备份/恢复开发总结（2026-09-08）

## 结果

完成 `/profile/data` 的完整 SQLite 本地备份与恢复。CSV 仍用于表格查看和对账；完整备份用于恢复流水、账户、分类、目标、预算、账本和本地设置。

恢复流程会先校验 SQLite 文件头、核心表和 schema 版本，再写入待恢复文件。当前页面不会关闭活动 Drift 数据库；应用完全重启、建立新连接前才替换数据库，因此不会因 Riverpod 查询流仍在监听而卡在“处理中”。替换前会保留恢复前数据库副本。

## 调用链

```text
数据与安全页
  → LocalBackupService.exportDatabase / restoreDatabase
  → PRAGMA wal_checkpoint(TRUNCATE)
  → FilePicker 导出或选择备份
  → SQLite 文件校验
  → .pending-restore 暂存
  → AppDatabase._openConnection 启动前替换
  → databaseBootstrapProvider / Repository / 页面重新读取
```

## 修改文件

- `lib/features/data_export/application/local_backup_service.dart`
  - 增加 SQLite 导出、核心表校验、schema 兼容校验和安全暂存。
- `lib/features/data_export/presentation/data_export_page.dart`
  - 增加完整备份导出、恢复确认、文件选择和重启生效提示。
- `lib/features/profile/presentation/profile_page.dart`
  - 更新“我的”页的数据与安全入口说明。
- `lib/features/membership/presentation/membership_page.dart`
  - 更新本地数据能力说明，避免继续提示完整备份未开放。
- `lib/core/database/app_database.dart`
  - 在数据库连接建立前应用待恢复文件，并清理 WAL/SHM sidecar。
- `test/local_backup_service_test.dart`
  - 覆盖导出、非法文件、核心表校验和启动替换。
- `docs/development/CURRENT_STATUS.md`
  - 更新完成度、验证结果和剩余边界。
- `docs/development/ARCHITECTURE.md`
  - 更新 `data_export` 调用边界和后续建议。

## 验证结果

- `flutter analyze`：通过，无 issues。
- `flutter test --reporter compact`：109 个测试全部通过。
- `flutter build apk --release`：通过，生成 `build/app/outputs/flutter-apk/app-release.apk`。
- release APK：69,143,052 bytes，SHA-256 为 `1b839a4cb24bb1824949f43d1283add196a6eaf9ce4b57324ecae0c1e161e494`。
- Android 模拟器实测：真实新增 ¥100 → 导出完整备份 → 删除流水至 ¥0 → 选择备份并成功暂存 → 完全重启应用后首页、支出趋势和分类支出恢复为 ¥100。

## 剩余风险

- 备份是原始 SQLite 文件，没有加密或密码保护，不应放入不可信共享位置。
- 独立保存在文件系统中的附件不在 SQLite 文件内，恢复时需要另行保留附件。
- 恢复采用重启生效；用户在看到提示后若不重启，当前页面仍展示旧数据库，这是为了避免强行关闭活动数据库造成数据损坏。
- 云同步、跨设备迁移、会员/支付和第三方服务仍未实际联调。
