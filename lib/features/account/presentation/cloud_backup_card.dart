import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../settings/data/app_settings_repository.dart';
import '../application/account_session_controller.dart';
import '../application/cloud_backup_preferences.dart';
import '../application/dataset_binding_service.dart';
import 'dataset_binding_page.dart';
import '../../app_runtime/application/device_heartbeat_service.dart';
import '../../app_runtime/data/app_runtime_repository.dart';

class CloudBackupCard extends ConsumerStatefulWidget {
  const CloudBackupCard({super.key});
  @override
  ConsumerState<CloudBackupCard> createState() => _CloudBackupCardState();
}

class _CloudBackupCardState extends ConsumerState<CloudBackupCard> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(datasetBindingProvider);
      ref.invalidate(cloudAutoBackupEnabledProvider);
    } on Object {
      if (mounted) setState(() => _error = '操作未完成，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountSessionProvider);
    final bindingState = ref.watch(datasetBindingProvider);
    final auto = ref.watch(cloudAutoBackupEnabledProvider);
    final binding = bindingState.value;
    final userId = account.value?.isAuthenticated == true
        ? account.value?.user?.id
        : null;
    final ready =
        userId != null &&
        binding?.boundUserId == userId &&
        binding?.cloudSyncEnabled == true;
    final loading = account.isLoading || bindingState.isLoading;
    final failed = account.hasError || bindingState.hasError || auto.hasError;
    final last = binding?.lastSyncAt;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('云备份', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (loading)
            const LinearProgressIndicator()
          else
            Text(
              failed
                  ? '备份状态读取失败'
                  : !ready
                  ? '登录并设置后，将账本备份到自己的账号'
                  : binding!.hasRemoteUpdate
                  ? '云端有更新，自动备份已暂停，请先检查云端数据'
                  : last == null
                  ? '尚未完成首次备份'
                  : '最近成功：${DateFormat('yyyy-MM-dd HH:mm').format(last)}',
              style: TextStyle(color: context.appSecondaryText),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          if (failed)
            TextButton.icon(
              onPressed: () {
                ref.invalidate(datasetBindingProvider);
                ref.invalidate(cloudAutoBackupEnabledProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            )
          else if (!loading && !ready)
            FilledButton.tonalIcon(
              onPressed: () => context.push(
                userId == null
                    ? '/account/login'
                    : '/profile/account/data-binding',
              ),
              icon: const Icon(Icons.cloud_outlined),
              label: Text(userId == null ? '登录后使用云备份' : '设置云备份'),
            )
          else if (ready) ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动备份'),
              subtitle: const Text('首次备份后，打开或回到应用时检查，间隔至少 6 小时'),
              value: auto.value ?? false,
              onChanged: _busy || auto.isLoading || auto.hasError
                  ? null
                  : (value) => _run(() async {
                      final current = await ref
                          .read(datasetBindingServiceProvider)
                          .status();
                      final session = ref.read(accountSessionProvider).value;
                      if (session?.isAuthenticated != true ||
                          session?.user?.id != userId ||
                          current.boundUserId != userId)
                        throw StateError('账号已变化');
                      if (value) await ref.read(appRuntimeRepositoryProvider).require(AppCapability.cloudBackup);
                      if (!mounted) return;
                      await ref
                          .read(appSettingsRepositoryProvider)
                          .set(
                            cloudAutoBackupKey(userId, current.datasetId),
                            '$value',
                          );
                      if (mounted) unawaited(ref.read(deviceHeartbeatServiceProvider).sendIfDue(force: true));
                    }),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy || binding!.hasRemoteUpdate
                      ? null
                      : () => _run(
                          () => DatasetBindingPage.uploadCloudBackup(
                            context,
                            ref,
                          ),
                        ),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(_busy ? '正在处理…' : '立即备份'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => DatasetBindingPage.restoreCloudBackup(
                            context,
                            ref,
                          ),
                        ),
                  icon: const Icon(Icons.restore),
                  label: const Text('从云端恢复'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.push('/profile/account/data-binding'),
                  child: const Text('查看云端状态'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
