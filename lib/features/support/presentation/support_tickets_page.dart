import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sharing/data/session_repository.dart';
import '../application/support_ticket_service.dart';

class SupportTicketsPage extends ConsumerStatefulWidget {
  const SupportTicketsPage({super.key});

  @override
  ConsumerState<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends ConsumerState<SupportTicketsPage> {
  bool _loading = true;
  bool _guest = false;
  Object? _error;
  List<SupportTicketSummary> _tickets = const [];

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
      final tickets = await ref.read(supportTicketServiceProvider).listMine();
      if (mounted) {
        setState(() {
          _guest = false;
          _tickets = tickets;
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('我的工单'),
          actions: [
            IconButton(
              tooltip: '新建反馈',
              onPressed: () => context.push('/profile/feedback'),
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const ListView(
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
                    const Icon(Icons.support_agent_outlined, size: 54),
                    const SizedBox(height: 16),
                    const Text(
                      '登录后查看工单记录',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '游客可以匿名提交反馈，但匿名工单不会出现在账号历史记录中。',
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
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text('工单读取失败：$_error', textAlign: TextAlign.center),
                  ],
                )
              : _tickets.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.inbox_outlined, size: 54),
                    const SizedBox(height: 12),
                    const Text('还没有工单', textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton.tonal(
                      onPressed: () => context.push('/profile/feedback'),
                      child: const Text('提交第一个反馈'),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: _tickets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final ticket = _tickets[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(_statusIcon(ticket.status)),
                        title: Text(
                          ticket.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_statusLabel(ticket.status)} · ${ticket.messageCount} 条消息 · ${_date(ticket.updatedAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await context.push(
                            '/profile/support-tickets/${ticket.id}',
                          );
                          await _load();
                        },
                      ),
                    );
                  },
                ),
        ),
      );

  static String _statusLabel(String status) => switch (status) {
        'open' => '待处理',
        'in_progress' => '处理中',
        'resolved' => '已解决',
        'closed' => '已关闭',
        _ => status,
      };

  static IconData _statusIcon(String status) => switch (status) {
        'open' => Icons.markunread_mailbox_outlined,
        'in_progress' => Icons.support_agent_outlined,
        'resolved' => Icons.check_circle_outline,
        'closed' => Icons.archive_outlined,
        _ => Icons.help_outline,
      };

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
