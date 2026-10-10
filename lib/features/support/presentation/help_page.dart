import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_runtime/data/app_runtime_repository.dart';

const _localFaqs = [
  AppOperation(
    id: 'start',
    title: '如何开始记账？',
    body: '首页底部“记一笔”可以手动录入；Android 还可以在支付后通过自动记账或支付通知生成待确认记录。',
  ),
  AppOperation(
    id: 'books',
    title: '多账本和共享账本有什么区别？',
    body: '多账本用于把个人、家庭、企业等账务分开；共享账本允许成员共同记录。共享默认账户时，账户详情会汇总相关账本流水。',
  ),
  AppOperation(
    id: 'backup',
    title: '备份和云同步有什么区别？',
    body: '本地完整备份由你主动导出，使用备份密码加密并包含现有附件；云备份需要登录并绑定本地数据，自动备份由你单独开启。',
  ),
  AppOperation(
    id: 'restore',
    title: '为什么恢复后需要重启？',
    body: '应用运行时可能同时有前台、定时任务和自动记账连接占用数据库。恢复采用安全暂存，完全重启后再切换数据库，避免运行中替换造成损坏。',
  ),
  AppOperation(
    id: 'privacy',
    title: '如何保护金额隐私？',
    body: '金额隐私掩码只隐藏展示层数字；本地数据库同时使用设备密钥加密。你还可以在“数据与安全”中开启应用锁。',
  ),
];

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(appRuntimeRepositoryProvider).operations('faq', force: true);
    ref.invalidate(appOperationsProvider('faq'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appOperationsProvider('faq'));
    final result = state.value;
    final faqs = result?.items.isNotEmpty == true ? result!.items : _localFaqs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用手册'),
        actions: [
          IconButton(
            tooltip: '刷新帮助内容',
            onPressed: state.isLoading ? null : () => _refresh(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (state.isLoading) const LinearProgressIndicator(),
            if (result?.unavailable == true || state.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  result?.items.isNotEmpty == true
                      ? '暂时无法更新，正在显示已保存的帮助内容。'
                      : '暂时无法更新，正在显示内置使用手册。',
                ),
              ),
            for (final faq in faqs)
              Card(
                child: ExpansionTile(
                  key: ValueKey('${faq.id}:${faq.body}'),
                  title: Text(
                    faq.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(faq.body)],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/profile/feedback'),
              icon: const Icon(Icons.feedback_outlined),
              label: const Text('仍有问题，提交反馈'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/profile/support-tickets'),
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('查看我的工单'),
            ),
          ],
        ),
      ),
    );
  }
}
