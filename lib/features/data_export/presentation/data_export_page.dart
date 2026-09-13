import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../accounts/data/account_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../application/local_backup_service.dart';
import '../domain/transaction_csv.dart';

class DataExportPage extends ConsumerStatefulWidget {
  const DataExportPage({super.key});
  @override
  ConsumerState<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends ConsumerState<DataExportPage> {
  bool _saving = false;
  String? _status;

  Future<void> _exportBackup() async {
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final bytes = await ref.read(localBackupServiceProvider).exportDatabase();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final uri = await FilePicker.saveFile(
        fileName: '好好记账完整备份-$date.sqlite',
        mimeType: 'application/vnd.sqlite3',
        bytes: bytes,
        dialogTitle: '保存完整本地备份',
      );
      if (mounted) {
        setState(
          () => _status = uri == null ? '已取消备份，未保存文件' : '完整本地备份已保存到所选位置',
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
        content: const Text('恢复会覆盖当前本机账本。应用会先保留一份恢复前的数据库副本，确认继续吗？'),
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

    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final result = await FilePicker.pickFile(
        dialogTitle: '选择好好记账完整备份',
        type: FileType.custom,
        allowedExtensions: ['sqlite', 'db'],
      );
      final bytes = result == null ? null : await result.readAsBytes();
      if (bytes == null) {
        if (mounted) setState(() => _status = '已取消恢复，未修改当前账本');
        return;
      }
      await ref.read(localBackupServiceProvider).restoreDatabase(bytes);
      if (mounted) {
        setState(() => _status = '完整备份已准备，请完全关闭并重新打开应用后生效');
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
                  const Text('本地数据读取失败，暂时无法导出'),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(transactionsProvider);
                      ref.invalidate(allAccountsProvider);
                    },
                    child: const Text('重新加载'),
                  ),
                ] else
                  Text(
                    '可导出 ${transactions.value!.length} 笔记录',
                    style: const TextStyle(color: AppColors.textSecondary),
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
                const Text('备份当前 SQLite 账本，包含流水、账户、分类、目标、预算、账本和本地设置，可在本机恢复。'),
                const SizedBox(height: 12),
                if (databaseState.isLoading)
                  const LinearProgressIndicator()
                else if (databaseState.hasError)
                  const Text('本地数据库读取失败，暂时无法备份或恢复')
                else
                  const Text(
                    '恢复前会自动保留一份恢复前数据库副本。恢复后需完全关闭并重新打开应用才会切换账本。',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: !databaseReady || _saving ? null : _exportBackup,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: Text(_saving ? '正在处理…' : '导出完整备份'),
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
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本机存储',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('当前账本保存在本机。CSV 适合表格查看和对账；完整 SQLite 备份可用于应用内恢复。'),
                SizedBox(height: 8),
                Text(
                  '卸载应用可能丢失本地账本，请先导出完整备份。备份文件不包含独立保存的附件文件，跨设备恢复前需另行保留附件。',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
