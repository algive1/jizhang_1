import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../application/support_ticket_service.dart';

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _contact = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.length < 2 || message.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请补充问题标题和具体描述')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final id = await ref.read(supportTicketServiceProvider).submit(
            subject: subject,
            message: message,
            contact: _contact.text,
          );
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      final loggedIn =
          await ref.read(supportTicketServiceProvider).isLoggedIn;
      if (!mounted) return;
      final openTickets = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('反馈已提交'),
          content: SelectableText(
            loggedIn
                ? '工单号：$id\n\n可以在“我的工单”中查看处理状态并继续回复。'
                : '工单号：$id\n\n当前是游客匿名提交。匿名工单不会出现在账号历史记录中，请保存工单号。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('知道了'),
            ),
            if (loggedIn)
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('查看工单'),
              ),
          ],
        ),
      );
      if (openTickets == true && mounted) {
        context.push('/profile/support-tickets/$id');
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('反馈建议')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.support_agent_outlined, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '这里会真实提交到好好记账服务端工单，不再是静态弹窗。请尽量写清发生页面、操作步骤和大致时间。',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subject,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '问题标题',
                hintText: '例如：恢复备份后某个账户余额不对',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _message,
              minLines: 6,
              maxLines: 12,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: '详细描述',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contact,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: '联系方式（可选）',
                hintText: '邮箱、微信号等；不填也可提交',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? '正在提交…' : '提交反馈'),
            ),
          ],
        ),
      );
}
