import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../application/account_session_controller.dart';
import '../application/dataset_binding_service.dart';
import '../application/personal_cloud_bootstrap_service.dart';
import '../application/personal_cloud_backup_service.dart';

class DatasetBindingPage extends ConsumerWidget {
  const DatasetBindingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = ref.watch(datasetBindingProvider);
    final account = ref.watch(accountSessionProvider).value?.user;

    return Scaffold(
      appBar: AppBar(title: const Text('本地数据绑定')),
      body: binding.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (value) {
          final boundUserId = value.boundUserId;
          final isCurrent = account != null && boundUserId == account.id;
          final isOther = boundUserId != null && !isCurrent;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '这台设备的本地数据',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '数据集 · …${value.datasetId.substring(value.datasetId.length > 8 ? value.datasetId.length - 8 : 0)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      _StatusRow(
                        icon: isCurrent
                            ? Icons.verified_user_outlined
                            : isOther
                            ? Icons.warning_amber_rounded
                            : Icons.link_off_outlined,
                        title: isCurrent
                            ? '已绑定当前账号'
                            : isOther
                            ? '已绑定其他账号'
                            : '尚未绑定账号',
                        subtitle: isCurrent
                            ? '后续开启云同步时，只允许使用当前账号同步这份本地数据。'
                            : isOther
                            ? '为了避免串号，这份数据不会自动同步到当前登录账号。'
                            : '登录本身不会绑定，也不会上传数据。',
                      ),
                      const SizedBox(height: 12),
                      _StatusRow(
                        icon: Icons.cloud_outlined,
                        title: value.cloudSyncEnabled ? '云同步已启用' : '云同步未启用',
                        subtitle: value.cloudSyncEnabled
                            ? value.lastSyncAt == null
                                ? '云同步通道已建立，可手动上传首份云端备份。'
                                : '最近备份：${value.lastSyncAt!.toLocal()}'
                            : '尚未建立个人云同步通道。登录和绑定都不会自动上传数据。',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (account == null)
                FilledButton(
                  onPressed: () => context.push('/account/login'),
                  child: const Text('登录后绑定'),
                )
              else if (boundUserId == null)
                FilledButton(
                  onPressed: () => _bind(context, ref),
                  child: Text('绑定到 ${account.preferredName}'),
                )
              else if (isCurrent) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('绑定关系已建立'),
                    subtitle: Text(
                      value.cloudSyncEnabled
                          ? '个人云数据集已经登记，可检查云端状态。'
                          : '可以继续建立云同步通道；此操作仍不会上传账务数据。',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!value.cloudSyncEnabled)
                  FilledButton.icon(
                    onPressed: () => _bootstrapCloud(context, ref),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('启用云同步通道'),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: () => _uploadCloudBackup(context, ref),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      value.lastSyncAt == null ? '首次备份到云端' : '立即备份到云端',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showCloudStatus(context, ref),
                    icon: const Icon(Icons.cloud_done_outlined),
                    label: const Text('检查云端状态'),
                  ),
                ],
              ]
              else
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('已阻止自动改绑'),
                    subtitle: Text('切换账号不会改变本地数据归属，也不会自动上传。'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _bootstrapCloud(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('启用云同步通道？'),
        content: const Text(
          '本步骤只在服务器登记你的个人云数据集，不上传账本、流水或附件。真正首次上传会在下一步再次确认。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final result = await ref
          .read(personalCloudBootstrapServiceProvider)
          .bootstrap();
      if (!context.mounted) return;
      if (!result.datasetMatches) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('云端已有个人数据'),
            content: const Text(
              '这个账号已经有另一份云端数据。当前本地数据不会被上传或覆盖；后续需要选择恢复或合并。',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return;
      }
      ref.invalidate(datasetBindingProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('云同步通道已建立，尚未上传账务数据')),
      );
    } on CloudSyncMembershipRequired {
      if (!context.mounted) return;
      final upgrade = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('云同步是会员功能'),
          content: const Text('开通有效会员后即可建立个人云同步通道。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('查看会员'),
            ),
          ],
        ),
      );
      if (upgrade == true && context.mounted) {
        context.push('/profile/membership');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  static Future<void> _uploadCloudBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('备份到云端？'),
        content: const Text(
          '将当前本地 SQLite 账务备份上传到当前账号的个人云数据集。此操作不会删除或覆盖本机数据，也不会自动恢复到其他设备。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('开始备份'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final result = await ref
          .read(personalCloudBackupServiceProvider)
          .uploadSnapshot();
      ref.invalidate(datasetBindingProvider);
      if (!context.mounted) return;
      final size = result.snapshotSize == null
          ? ''
          : '，${(result.snapshotSize! / 1024).toStringAsFixed(0)} KB';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('云端备份完成 · 版本 ${result.revision}$size')),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  static Future<void> _showCloudStatus(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final status = await ref
          .read(personalCloudBootstrapServiceProvider)
          .status();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('个人云同步状态'),
          content: Text(
            status.datasetMatches
                ? '云端数据集已登记。版本 ${status.revision}，'
                    '${status.hasSnapshot ? '已有云端备份。' : '尚未上传首份账务备份。'}'
                : '账号云端存在另一份数据集，当前设备需要先恢复或合并。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  static Future<void> _bind(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('绑定本地数据？'),
        content: const Text(
          '绑定只记录“这份本地数据属于哪个服务器账号”。本操作不会上传数据，也不会修改现有账本和流水的 owner/user_id。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认绑定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(datasetBindingServiceProvider).bindCurrentAccount();
      ref.invalidate(datasetBindingProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
