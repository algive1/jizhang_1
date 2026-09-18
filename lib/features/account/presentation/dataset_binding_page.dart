import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../application/account_session_controller.dart';
import '../application/dataset_binding_service.dart';

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
                        subtitle: '当前阶段只建立绑定关系，不执行上传、下载或合并。',
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
              else if (isCurrent)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('绑定关系已建立'),
                    subtitle: Text('下一阶段接入个人云同步时会继续使用这条绑定关系。'),
                  ),
                )
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
