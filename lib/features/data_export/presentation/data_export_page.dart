import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/analytics/product_analytics.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../accounts/data/account_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../application/local_backup_service.dart';
import '../domain/transaction_csv.dart';
import '../../security/application/app_lock_service.dart';
import '../../../app/theme/app_theme_tokens.dart';

class DataExportPage extends ConsumerStatefulWidget {
  const DataExportPage({super.key});
  @override
  ConsumerState<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends ConsumerState<DataExportPage> {
  bool _saving = false;
  bool _analyticsChanging = false;
  bool? _analyticsEnabled;
  bool? _appLockEnabled;
  bool _appLockChanging = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsPreference();
    _loadAppLockPreference();
  }

  Future<void> _loadAnalyticsPreference() async {
    final enabled = await ref.read(productAnalyticsProvider).isEnabled();
    if (mounted) setState(() => _analyticsEnabled = enabled);
  }

  Future<void> _loadAppLockPreference() async {
    final enabled = await ref.read(appLockServiceProvider).isEnabled();
    if (mounted) setState(() => _appLockEnabled = enabled);
  }

  Future<void> _setAppLockEnabled(bool enabled) async {
    if (_appLockChanging) return;
    setState(() => _appLockChanging = true);
    try {
      final changed = await ref.read(appLockServiceProvider).setEnabled(enabled);
      if (!mounted) return;
      if (changed) {
        setState(() => _appLockEnabled = enabled);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备未完成身份验证，应用锁设置没有改变')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('应用锁设置失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _appLockChanging = false);
    }
  }

  Future<String?> _backupPassword({required bool confirm}) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    String? error;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(confirm ? '设置备份密码' : '输入备份密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: password,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '备份密码',
                  helperText: '至少 8 个字符，请妥善保存；忘记后无法恢复',
                ),
              ),
              if (confirm) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '再次输入'),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.warning),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = password.text.trim();
                if (value.length < 8) {
                  setDialogState(() => error = '密码至少需要 8 个字符');
                  return;
                }
                if (confirm && value != confirmation.text.trim()) {
                  setDialogState(() => error = '两次输入的密码不一致');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: Text(confirm ? '创建备份' : '解密恢复'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    confirmation.dispose();
    return value;
  }

  Future<void> _setAnalyticsEnabled(bool enabled) async {
    if (_analyticsChanging) return;
    setState(() => _analyticsChanging = true);
    try {
      await ref.read(productAnalyticsProvider).setEnabled(enabled);
      if (mounted) setState(() => _analyticsEnabled = enabled);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('统计设置保存失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _analyticsChanging = false);
    }
  }

  Future<void> _exportBackup() async {
    final password = await _backupPassword(confirm: true);
    if (password == null || !mounted) return;
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final bytes = await ref
          .read(localBackupServiceProvider)
          .exportEncryptedArchive(password: password);
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final uri = await FilePicker.saveFile(
        fileName: '好好记账完整备份-$date.hhbackup',
        mimeType: 'application/octet-stream',
        bytes: bytes,
        dialogTitle: '保存加密完整备份',
      );
      if (mounted) {
        setState(
          () => _status = uri == null
              ? '已取消备份，未保存文件'
              : '加密完整备份已保存，数据库与现有附件均已包含',
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _status = '备份失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复本地备份？'),
        content: const Text(
          '恢复会覆盖当前本机账本。应用会先保留恢复前数据库副本；新格式备份还会恢复附件。确认继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await FilePicker.pickFile(
      dialogTitle: '选择好好记账备份',
      type: FileType.custom,
      allowedExtensions: ['hhbackup', 'sqlite', 'db'],
    );
    final bytes = result == null ? null : await result.readAsBytes();
    if (bytes == null || !mounted) {
      setState(() => _status = '已取消恢复，未修改当前账本');
      return;
    }

    String? password;
    if (LocalBackupService.isEncryptedArchive(bytes)) {
      password = await _backupPassword(confirm: false);
      if (password == null || !mounted) return;
    }

    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final service = ref.read(localBackupServiceProvider);
      if (password != null) {
        await service.restoreEncryptedArchive(bytes, password: password);
      } else {
        // Backward compatibility with the old raw SQLite backup format.
        await service.restoreDatabase(bytes);
      }
      if (mounted) {
        setState(
          () => _status = '备份已安全暂存。请完全关闭并重新打开应用后切换到恢复的数据。',
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _status = '恢复失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(allAccountsProvider);
    final databaseState = ref.watch(databaseBootstrapProvider);
    final ready =
        transactions.hasValue &&
        accounts.hasValue &&
        !transactions.hasError &&
        !accounts.hasError;
    final databaseReady = databaseState.hasValue && !databaseState.hasError;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/profile'),
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
              ),
              Expanded(
                child: Text(
                  '数据与安全',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导出流水 CSV', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text('导出全部未删除流水，含币种、账户、分类、备注及转账和校准记录。归档账户的名称也会保留。'),
                const SizedBox(height: 12),
                if (transactions.isLoading || accounts.isLoading)
                  const LinearProgressIndicator()
                else if (!ready) ...[
                  Text('本地数据读取失败，暂时无法导出'),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(transactionsProvider);
                      ref.invalidate(allAccountsProvider);
                    },
                    child: Text('重新加载'),
                  ),
                ] else
                  Text(
                    '可导出 ${transactions.value!.length} 笔记录',
                    style: TextStyle(color: context.appSecondaryText),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: !ready || _saving
                      ? null
                      : () async {
                          setState(() {
                            _saving = true;
                            _status = null;
                          });
                          try {
                            final csv = TransactionCsv.encode(
                              transactions.value!,
                              accounts.value!,
                            );
                            final date = DateTime.now()
                                .toIso8601String()
                                .substring(0, 10);
                            final uri = await FilePicker.saveFile(
                              fileName: '记账流水-$date.csv',
                              mimeType: 'text/csv',
                              bytes: Uint8List.fromList(utf8.encode(csv)),
                              dialogTitle: '保存流水 CSV',
                            );
                            if (mounted) {
                              setState(
                                () => _status = uri == null
                                    ? '已取消导出，未保存文件'
                                    : '流水 CSV 已保存到所选位置',
                              );
                            }
                          } on Object catch (error) {
                            if (mounted) {
                              setState(() => _status = '导出失败：$error');
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(_saving ? '正在导出…' : '选择位置并保存'),
                ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_status!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('完整本地备份', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('导出密码加密的完整备份，包含 SQLite 账本与现有附件。备份密码不会上传或保存，恢复时必须重新输入。'),
                SizedBox(height: 12),
                if (databaseState.isLoading)
                  const LinearProgressIndicator()
                else if (databaseState.hasError)
                  Text('本地数据库读取失败，暂时无法备份或恢复')
                else
                  Text(
                    '恢复前会校验密码、文件完整性与数据库结构，并安全暂存到下次启动再切换，避免替换正在使用的数据库。',
                    style: TextStyle(color: context.appSecondaryText),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: !databaseReady || _saving ? null : _exportBackup,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: Text(_saving ? '正在处理…' : '导出加密完整备份'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: !databaseReady || _saving ? null : _restoreBackup,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('从备份恢复'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('隐私与设备安全', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  '本地 SQLite 数据库已使用设备随机密钥加密；密钥保存在系统安全存储中，不写入数据库或备份文件。',
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('应用锁'),
                  subtitle: const Text('从后台返回时使用面容、指纹或设备密码验证'),
                  value: _appLockEnabled ?? false,
                  onChanged: _appLockEnabled == null || _appLockChanging
                      ? null
                      : _setAppLockEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '使用情况统计',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  '帮助我们了解哪些页面和功能更常用。默认关闭，只有你主动开启后才会上传匿名使用事件。',
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('允许匿名使用情况统计'),
                  subtitle: const Text(
                    '不上传金额、商户、备注、分类名、附件路径、账户信息或流水内容。',
                  ),
                  value: _analyticsEnabled ?? false,
                  onChanged: _analyticsEnabled == null || _analyticsChanging
                      ? null
                      : _setAnalyticsEnabled,
                ),
                TextButton(
                  onPressed: () => context.push('/profile/privacy'),
                  child: const Text('查看隐私协议'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本机存储',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('当前账本保存在本机。CSV 适合表格查看和对账；完整 SQLite 备份可用于应用内恢复。'),
                const SizedBox(height: 8),
                Text(
                  '卸载应用可能丢失本地账本，请先导出加密完整备份。新格式 .hhbackup 同时包含数据库与现有附件；旧 .sqlite/.db 备份仍可兼容恢复但不含附件。',
                  style: TextStyle(color: context.appSecondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
