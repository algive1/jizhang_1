import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_intelligence.dart';
import '../../../core/widgets/app_card.dart';
import '../../categories/data/category_repository.dart';
import '../data/bill_inbox_repository.dart';
import '../data/merchant_rule_repository.dart';
import '../application/transaction_intelligence_service.dart';
import '../../transactions/data/transactions_repository.dart';

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
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '账单收件箱',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '分类不确定、疑似重复和缺少账户的记录会留在这里，系统不会自动删除流水。',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                items.when(
                  data: (values) => values.isEmpty
                      ? const AppCard(child: Center(child: Text('暂无待确认账单')))
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
              const Icon(Icons.fact_check_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(detail, style: const TextStyle(color: AppColors.textSecondary)),
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
    final transaction = (await ref.read(transactionRepositoryProvider).getAll())
        .where((value) => value.id == transactionId)
        .firstOrNull;
    if (!context.mounted) return;
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    if (transaction == null) return;
    final options = categories
        .where(
          (category) =>
              category.type ==
              (transaction.isIncome
                  ? CategoryType.income
                  : CategoryType.expense),
        )
        .toList(growable: false);
    if (options.isEmpty) return;
    var selectedId = options.any((value) => value.id == transaction.categoryId)
        ? transaction.categoryId!
        : options.first.id;
    var remember = false;
    final result = await showModalBottomSheet<(String, bool)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择正确分类',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: selectedId,
                  onChanged: (value) {
                    if (value != null) setState(() => selectedId = value);
                  },
                  child: Column(
                    children: options
                        .map(
                          (category) => RadioListTile<String>(
                            value: category.id,
                            title: Text(category.name),
                          ),
                        )
                        .toList(),
                  ),
                ),
                CheckboxListTile(
                  value: remember,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('记住这个商户的分类'),
                  onChanged: (value) =>
                      setState(() => remember = value ?? false),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext, (selectedId, remember)),
                    child: const Text('保存分类'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref
          .read(merchantRuleRepositoryProvider)
          .correctTransaction(
            transactionId: transaction.id,
            categoryId: result.$1,
            rememberForMerchant: result.$2,
          );
      await _resolve(ref, InboxStatus.accepted);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('分类已更新')));
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('分类更新失败，请稍后重试')));
      }
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
