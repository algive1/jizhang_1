import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_card.dart';
import '../../sharing/application/shared_book_sync_service.dart';

class UnavailableDraftsCard extends ConsumerWidget {
  const UnavailableDraftsCard({super.key});
  String _describe(Json row) {
    final data = jsonDecode(row['data_json'] as String) as Json;
    final kind = switch (row['kind']) {
      'transactions' => '流水',
      'accounts' => '账户',
      'categories' => '分类',
      'budgets' => '预算',
      'goals' => '目标',
      'goal_contributions' => '目标贡献',
      'goal_milestones' => '目标节点',
      _ => '账本',
    };
    final amount = data['amount_in_cents'];
    return '$kind · ${data['name'] ?? data['merchant'] ?? data['note'] ?? '未命名记录'}${amount is num ? ' · ${(amount / 100).toStringAsFixed(2)} ${data['currency'] ?? '元'}' : ''}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(unavailableSharedDraftsProvider).value ?? [];
    if (drafts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '无法提交的本地草稿',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Text('这些修改尚未确认同步。你可以保留，或复制内容后另行记账。'),
            for (final draft in drafts)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(draft['name'] as String),
                subtitle: Text(
                  '${(draft['pending'] as List).length} 项 · ${draft['last_error'] ?? '账本当前不可用'}',
                ),
                children: [
                  for (final row in (draft['pending'] as List).cast<Json>())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_describe(row)),
                      trailing: IconButton(
                        tooltip: '复制草稿',
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: _describe(row)),
                        ),
                      ),
                    ),
                  if (draft['phase'] != 'promoting')
                    TextButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('移除这些本地草稿？'),
                            content: const Text('未同步的修改将被丢弃。服务端账务数据不受影响。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('移除草稿'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await ref
                                .read(sharedBookSyncProvider)
                                .discardUnavailableDrafts(
                                  draft['book_id'] as String,
                                );
                          } catch (e) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                          }
                        }
                      },
                      child: const Text('移除本地草稿'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
