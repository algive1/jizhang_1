import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../sharing/data/session_repository.dart';
import '../application/account_session_controller.dart';
import '../application/dataset_binding_service.dart';
import '../domain/account_session_status.dart';

class AccountCenterPage extends ConsumerWidget {
  const AccountCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(accountSessionProvider).value;
    final user = session?.user;
    final status = session?.status ?? AccountSessionStatus.initializing;
    final binding = ref.watch(datasetBindingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('账号中心')),
      body: status == AccountSessionStatus.initializing
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? _GuestAccountCenter(status: status)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary.withValues(alpha: .12),
                          child: Text(
                            user.preferredName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.preferredName,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '@${user.username}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '修改昵称',
                          onPressed: () => _editDisplayName(context, ref, user.preferredName),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  title: '账号与会员',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('会员中心'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/profile/membership'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.people_outline),
                      title: const Text('共享账本'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/profile/family'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Section(
                  title: '账号安全',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.password_outlined),
                      title: const Text('修改密码'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _changePassword(context, ref),
                    ),
                    ListTile(
                      leading: const Icon(Icons.key_outlined),
                      title: const Text('恢复密钥'),
                      subtitle: const Text('忘记密码时用于恢复账号'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _rotateRecoveryKey(context, ref),
                    ),
                    ListTile(
                      leading: const Icon(Icons.devices_outlined),
                      title: const Text('登录设备'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showSessions(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Section(
                  title: '数据',
                  children: [
                    ListTile(
                      leading: Icon(_cloudIcon(binding)),
                      title: const Text('云同步'),
                      subtitle: Text(_cloudSubtitle(binding)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/profile/account/data-binding'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.link_outlined),
                      title: const Text('本地数据绑定'),
                      subtitle: const Text('控制这份本地数据可以同步到哪个账号'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/profile/account/data-binding'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('数据与安全'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/profile/data'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: () => _logoutAll(context, ref),
                  child: const Text('退出全部设备'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await ref.read(sessionRepositoryProvider).logout();
                    if (context.mounted) context.pop();
                  },
                  child: const Text('退出当前账号'),
                ),
              ],
            ),
    );
  }

  static IconData _cloudIcon(AsyncValue<DeviceDataBinding> binding) {
    final value = binding.value;
    if (value == null) return Icons.cloud_outlined;
    if (value.hasRemoteUpdate) return Icons.cloud_download_outlined;
    if (value.cloudSyncEnabled) return Icons.cloud_done_outlined;
    return Icons.cloud_off_outlined;
  }

  static String _cloudSubtitle(AsyncValue<DeviceDataBinding> binding) {
    if (binding.isLoading) return '正在读取同步状态…';
    if (binding.hasError) return '同步状态暂不可用';
    final value = binding.value;
    if (value == null) return '尚未启用';
    if (value.hasRemoteUpdate) {
      return '云端版本 ${value.lastSeenRemoteRevision} 待恢复';
    }
    if (!value.cloudSyncEnabled) return '尚未启用';
    if (value.lastSyncAt == null) return '已启用 · 尚未首次备份';
    return '已同步 · 本机版本 ${value.lastCloudRevision}';
  }

  static Future<void> _editDisplayName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(labelText: '昵称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    try {
      await ref.read(sessionRepositoryProvider).updateDisplayName(value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('昵称已更新')),
        );
      }
    } catch (error) {
      if (context.mounted) _error(context, error);
    }
  }

  static Future<void> _changePassword(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: '当前密码'),
            ),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新密码（至少 10 个字符）'),
            ),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: '确认新密码'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              next.text.length >= 10 && next.text == confirm.text,
            ),
            child: const Text('确认修改'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      current.dispose();
      next.dispose();
      confirm.dispose();
      return;
    }
    try {
      await ref.read(sessionRepositoryProvider).changePassword(
            currentPassword: current.text,
            newPassword: next.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码已修改，其他设备已退出登录')),
        );
      }
    } catch (error) {
      if (context.mounted) _error(context, error);
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
  }

  static Future<void> _rotateRecoveryKey(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final key = await ref.read(sessionRepositoryProvider).rotateRecoveryKey();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('新的恢复密钥'),
          content: SelectableText(key),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: key));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('已复制')),
                  );
                }
              },
              child: const Text('复制'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('我已保存'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _error(context, error);
    }
  }

  static Future<void> _showSessions(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      var sessions = await ref.read(sessionRepositoryProvider).deviceSessions();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text(
                      '登录设备',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final session in sessions)
                    ListTile(
                      leading: Icon(
                        session.current
                            ? Icons.smartphone
                            : Icons.devices_other_outlined,
                      ),
                      title: Text(
                        session.current
                            ? '${session.deviceName} · 当前设备'
                            : session.deviceName,
                      ),
                      subtitle: Text('有效至 ${_date(session.expiresAt)}'),
                      trailing: session.current
                          ? null
                          : TextButton(
                              onPressed: () async {
                                await ref
                                    .read(sessionRepositoryProvider)
                                    .revokeDeviceSession(session);
                                sessions = sessions
                                    .where((item) => item.id != session.id)
                                    .toList(growable: false);
                                if (sheetContext.mounted) setSheetState(() {});
                              },
                              child: const Text('退出'),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) _error(context, error);
    }
  }

  static Future<void> _logoutAll(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出全部设备？'),
        content: const Text('包括当前设备在内的所有登录会话都会失效，本机账务数据不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出全部设备'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionRepositoryProvider).logoutAll();
    if (context.mounted) context.pop();
  }

  static String _date(DateTime value) =>
      "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}";

  static void _error(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

class _GuestAccountCenter extends StatelessWidget {
  const _GuestAccountCenter({required this.status});

  final AccountSessionStatus status;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_outlined, size: 58),
              const SizedBox(height: 16),
              Text(
                status == AccountSessionStatus.expired
                    ? '登录状态已失效'
                    : '当前使用本地记账',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '本地记账无需账号。登录后可管理会员、共享账本与账号安全。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.push('/account/login'),
                child: Text(
                  status == AccountSessionStatus.expired ? '重新登录' : '登录',
                ),
              ),
              TextButton(
                onPressed: () => context.push('/account/register'),
                child: const Text('创建账号'),
              ),
            ],
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: [
            ListTile(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            ...children,
          ],
        ),
      );
}
