import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../data/transactions_repository.dart';
import 'transaction_actions.dart';

class TransactionSearchPage extends ConsumerStatefulWidget {
  const TransactionSearchPage({super.key, this.month});
  final DateTime? month;

  @override
  ConsumerState<TransactionSearchPage> createState() =>
      _TransactionSearchPageState();
}

class _TransactionSearchPageState extends ConsumerState<TransactionSearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(transactionsProvider).value ?? const [];
    final results = all.where((transaction) {
      if (widget.month != null &&
          (transaction.occurredAt.year != widget.month!.year ||
              transaction.occurredAt.month != widget.month!.month ||
              transaction.occurredAt.isAfter(DateTime.now())))
        return false;
      final query = _query.trim();
      return query.isEmpty ||
          (transaction.merchant?.contains(query) ?? false) ||
          (transaction.categoryName?.contains(query) ?? false) ||
          (transaction.note?.contains(query) ?? false);
    }).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    IconButton(
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: '返回流水',
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: '搜索商户、分类或备注',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _query.isEmpty ? '全部记录' : '找到 ${results.length} 笔记录',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                if (results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 72),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          color: AppColors.textSecondary,
                          size: 44,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '没有找到匹配的记录',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: results
                          .asMap()
                          .entries
                          .map(
                            (entry) => TransactionTile(
                              transaction: entry.value,
                              showDivider: entry.key != results.length - 1,
                              showDate: true,
                              onTap: () => _showTransactionActions(entry.value),
                              onLongPress: () =>
                                  _showTransactionActions(entry.value),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTransactionActions(TransactionRecord transaction) {
    return showTransactionActions(
      context,
      ref,
      transaction,
      onCorrectCategory: transaction.type == TransactionType.transfer
          ? null
          : () => showTransactionCategoryCorrection(context, ref, transaction),
    );
  }
}
