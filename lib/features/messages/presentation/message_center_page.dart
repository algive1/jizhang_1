import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../sharing/data/session_repository.dart';
import '../application/system_message_service.dart';

class MessageCenterPage extends ConsumerStatefulWidget {
  const MessageCenterPage({super.key});

  @override
  ConsumerState<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends ConsumerState<MessageCenterPage> {
  SystemMessageInbox? _inbox;
  Object? _error;
  bool _loading = true;
  bool _guest = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final session = ref.read(sessionRepositoryProvider);
      await session.initialize();
      if (session.userId == null) {
        if (mounted) {
          setState(() {
            _guest = true;
            _loading = false;
          });
        }
        return;
      }
      final inbox = await ref.read(systemMessageServiceProvider).load();
      if (mounted) {
        setState(() {
          _guest = false;
          _inbox = inbox;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(SystemMessage message) async {
    if (!message.isRead) {
      try {
        await ref.read(systemMessageServiceProvider).markRead(message.id);
      } on Object {
        // Opening the message is still useful while offline.
      }
    }
    if (!mounted) return;
    if (message.route case final route? when route.startsWith('/')) {
      if (mounted) context.push(route);
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(message.title),
          content: SingleChildScrollView(child: Text(message.body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
    await _load();
  }

  Future<void> _readAll() async {
    try {
      await ref.read(systemMessageServiceProvider).markAllRead();
      await _load();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    return Scaffold(
      appBar: AppBar(
        title: Text('消息中心'),
        actions: [
          if ((inbox?.unread ?? 0) > 0)
            TextButton(onPressed: _readAll, child: const Text('全部已读')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _guest
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.mark_email_unread_outlined, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    '登录后查看系统消息',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '公告、账号安全提醒和服务通知会集中显示在这里。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.push('/account/login'),
                    child: const Text('登录'),
                  ),
                ],
              )
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text('消息读取失败：$_error', textAlign: TextAlign.center),
                ],
              )
            : (inbox?.messages.isEmpty ?? true)
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.inbox_outlined, size: 54, color: context.appSecondaryText),
                  const SizedBox(height: 12),
                  const Text('暂时没有系统消息', textAlign: TextAlign.center),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: inbox!.messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final message = inbox.messages[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        message.isRead
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_rounded,
                        color: message.isRead
                            ? context.appSecondaryText
                            : context.appPrimary,
                      ),
                      title: Text(
                        message.title,
                        style: TextStyle(
                          fontWeight: message.isRead
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        message.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(message),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
