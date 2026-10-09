import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/transaction_intelligence.dart';
import '../../../core/widgets/app_card.dart';
import '../data/bill_inbox_repository.dart';
import '../application/transaction_intelligence_service.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/transaction_actions.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../autobookkeeping/presentation/pending_payment_inbox_section.dart';
import '../../autobookkeeping/auto_bookkeeping_inbox.dart';

class BillInboxPage extends ConsumerWidget {
  const BillInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pendingInboxProvider);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    IconButton(
                      onPressed: context.pop,
                      icon: Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '账单收件箱',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '关闭确认浮层的付款记录会保留在这里，确认记账后才会写入流水。',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const PendingPaymentInboxSection(),
                items.when(
                  data: (values) => values.isEmpty
                      ? ((ref
                                    .watch(pendingPaymentInboxProvider)
                                    .value
                                    ?.isNotEmpty ??
                                false)
                            ? const SizedBox.shrink()
                            : const AppCard(
                                child: Center(child: Text('暂无待确认账单')),
                              ))
                      : Column(
                          children: values
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _InboxItemCard(item: item),
                                ),
                              )
                              .toList(),
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => AppCard(child: Text('读取失败：$error')),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxItemCard extends ConsumerWidget {
  const _InboxItemCard({required this.item});

  final BillInboxItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = switch (item.reason) {
      InboxReason.uncertainCategory => '分类不确定',
      InboxReason.suspectedDuplicate => '疑似重复',
      InboxReason.missingAccount => '缺少账户',
    };
    final detail = switch (item.reason) {
      InboxReason.uncertainCategory => '请为这笔记录选择正确分类',
      InboxReason.suspectedDuplicate =>
        '匹配置信度 ${((item.duplicateConfidence ?? 0) * 100).toStringAsFixed(0)}%，需人工确认',
      InboxReason.missingAccount => '原始记录没有可关联的付款账户',
    };
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: context.appPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(detail, style: TextStyle(color: context.appSecondaryText)),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => _dismiss(context, ref),
                child: Text(
                  item.reason == InboxReason.uncertainCategory
                      ? '暂不处理'
                      : '不是问题',
                ),
              ),
              const Spacer(),
              if (item.reason == InboxReason.uncertainCategory)
                FilledButton.tonal(
                  onPressed: () => _correctCategory(context, ref),
                  child: const Text('修改分类'),
                )
              else if (item.reason == InboxReason.suspectedDuplicate)
                FilledButton.tonal(
                  onPressed: () => _resolveDuplicate(context, ref),
                  child: Text(_isEconomicEvent ? '确认已关联' : '确认重复并删除'),
                )
              else
                FilledButton.tonal(
                  onPressed: () => _resolve(ref, InboxStatus.accepted),
                  child: const Text('标记已处理'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(WidgetRef ref, InboxStatus status) {
    return ref.read(billInboxRepositoryProvider).resolve(item.id, status);
  }

  bool get _isEconomicEvent {
    final raw = item.payloadJson;
    if (raw == null || raw.isEmpty) return false;
    try {
      final payload = jsonDecode(raw);
      return payload is Map &&
          payload['reasonCode'] == 'wallet_and_bank_same_payment';
    } on FormatException {
      return false;
    }
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    try {
      await _resolve(ref, InboxStatus.dismissed);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('处理失败，请稍后重试')));
      }
    }
  }

  Future<void> _correctCategory(BuildContext context, WidgetRef ref) async {
    final transactionId = item.transactionId;
    if (transactionId == null) return;
    final transaction = await ref
        .read(transactionRepositoryProvider)
        .getById(transactionId);
    if (!context.mounted) return;
    if (transaction == null) return;
    if (await showTransactionCategoryCorrection(context, ref, transaction)) {
      await _resolve(ref, InboxStatus.accepted);
    }
  }

  Future<void> _resolveDuplicate(BuildContext context, WidgetRef ref) async {
    if (_isEconomicEvent) {
      try {
        final transactionId = item.transactionId;
        if (transactionId == null) return;
        await ref
            .read(transactionIntelligenceServiceProvider)
            .confirmEconomicEvent(transactionId);
        await _resolve(ref, InboxStatus.accepted);
      } on Object {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('处理失败，请稍后重试')));
        }
      }
      return;
    }
    final transactionId = item.transactionId;
    if (transactionId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除重复流水？'),
        content: const Text('系统会保留候选流水，并撤销当前这笔对账户余额的影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(transactionControllerProvider).delete(transactionId);
      await _resolve(ref, InboxStatus.accepted);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('重复流水已删除')));
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
      }
    }
  }
}
