import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/formatters/transaction_date_formatter.dart';
import '../../../core/widgets/transaction_date_group.dart';
import '../../../core/widgets/transaction_summary_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../categories/data/category_repository.dart';
import '../../intelligence/data/bill_inbox_repository.dart';
import '../data/transactions_repository.dart';
import 'transaction_actions.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key, this.month});
  final DateTime? month;

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  int _typeFilter = 0;
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final all =
        (ref.watch(transactionsProvider).value ?? const <TransactionRecord>[])
            .where(
              (t) =>
                  widget.month == null ||
                  (t.occurredAt.year == widget.month!.year &&
                      t.occurredAt.month == widget.month!.month &&
                      !t.occurredAt.isAfter(DateTime.now())),
            )
            .toList();
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final inboxCount = ref.watch(pendingInboxProvider).value?.length ?? 0;
    final typedTransactions = switch (_typeFilter) {
      1 => all.where((item) => item.isExpense),
      2 => all.where((item) => item.isIncome),
      _ => all,
    };
    final transactions = typedTransactions
        .where(
          (item) =>
              _categoryFilter == null || item.categoryName == _categoryFilter,
        )
        .toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _TransactionsHeader(
                  inboxCount: inboxCount,
                  onInbox: () => context.go('/transactions/inbox'),
                ),
                if (widget.month != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text(
                        '${widget.month!.year}年${widget.month!.month}月账单',
                      ),
                      onDeleted: () => context.go('/transactions'),
                    ),
                  ),
                const SizedBox(height: 16),
                _TransactionsToolbar(
                  selectedIndex: _typeFilter,
                  hasCategoryFilter: _categoryFilter != null,
                  onTypeChanged: (value) => setState(() => _typeFilter = value),
                  onSearch: () => context.push(
                    '/transactions/search${widget.month == null ? '' : '?month=${widget.month!.year}-${widget.month!.month.toString().padLeft(2, '0')}'}',
                  ),
                  onFilter: () => _openFilter(categories),
                  onAnalysis: () => context.push(
                    '/analysis${widget.month == null ? '' : '?month=${widget.month!.year}-${widget.month!.month.toString().padLeft(2, '0')}'}',
                  ),
                ),
                const SizedBox(height: 14),
                TransactionSummaryCard(
                  periodLabel: widget.month == null
                      ? '本月'
                      : '${widget.month!.month}月',
                  spending: _monthlyTotal(all, expense: true),
                  income: _monthlyTotal(all, expense: false),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '月度汇总为 CNY · 全部分类 · 截至当前',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (_categoryFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        label: Text(_categoryFilter!),
                        selected: true,
                        selectedColor: AppColors.primarySoft,
                        labelStyle: const TextStyle(
                          color: AppColors.primaryDark,
                        ),
                        side: BorderSide.none,
                        onDeleted: () => setState(() => _categoryFilter = null),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        '没有找到匹配的记录',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ..._buildGroups(transactions),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroups(List<TransactionRecord> transactions) {
    final groups = <DateTime, List<TransactionRecord>>{};
    for (final transaction in transactions) {
      final date = DateUtils.dateOnly(transaction.occurredAt);
      groups.putIfAbsent(date, () => []).add(transaction);
    }
    return groups.entries.map((entry) {
      final label = TransactionDateFormatter.groupLabel(entry.key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TransactionDateGroup(
          dateLabel: label,
          transactions: entry.value,
          onTransactionTap: (transaction) =>
              openTransactionDetail(context, transaction),
          onTransactionLongPress: _showTransactionActions,
        ),
      );
    }).toList();
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

  Future<void> _openFilter(List<Category> categories) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .68,
          child: Material(
            color: AppColors.surface,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '筛选分类',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: ['全部', ...categories.map((item) => item.name)]
                          .map(
                            (item) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              title: Text(item),
                              trailing: item == (_categoryFilter ?? '全部')
                                  ? const Icon(
                                      Icons.check,
                                      color: AppColors.primary,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _categoryFilter = selected == '全部' ? null : selected);
  }

  double _monthlyTotal(
    List<TransactionRecord> transactions, {
    required bool expense,
  }) {
    final now = DateTime.now();
    return transactions
            .where(
              (item) =>
                  item.currency.toUpperCase() == 'CNY' &&
                  item.deletedAt == null &&
                  !item.occurredAt.isAfter(now) &&
                  item.occurredAt.year == (widget.month ?? now).year &&
                  item.occurredAt.month == (widget.month ?? now).month &&
                  (expense ? item.isExpense : item.isIncome),
            )
            .fold<int>(
              0,
              (total, item) => total + (item.amount * 100).round(),
            ) /
        100;
  }
}

class _TransactionsHeader extends StatelessWidget {
  const _TransactionsHeader({required this.inboxCount, required this.onInbox});

  final int inboxCount;
  final VoidCallback onInbox;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('流水', style: Theme.of(context).textTheme.headlineLarge),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onInbox,
              icon: const Icon(Icons.inbox_outlined, size: 28),
              tooltip: '账单收件箱',
            ),
            if (inboxCount > 0)
              Positioned(
                right: 1,
                top: 0,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: AppColors.warning,
                  child: Text(
                    inboxCount > 9 ? '9+' : '$inboxCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        const UserAvatar(radius: 24),
      ],
    );
  }
}

class _TransactionsToolbar extends StatelessWidget {
  const _TransactionsToolbar({
    required this.selectedIndex,
    required this.hasCategoryFilter,
    required this.onTypeChanged,
    required this.onSearch,
    required this.onFilter,
    required this.onAnalysis,
  });

  final int selectedIndex;
  final bool hasCategoryFilter;
  final ValueChanged<int> onTypeChanged;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onAnalysis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FilterSegment(
            selectedIndex: selectedIndex,
            onChanged: onTypeChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSearch,
          icon: const Icon(Icons.search, size: 30),
          tooltip: '搜索流水',
        ),
        IconButton(
          onPressed: onAnalysis,
          icon: const Icon(Icons.insights_outlined, size: 28),
          tooltip: '收支分析',
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onFilter,
              icon: const Icon(Icons.filter_alt_outlined, size: 28),
              tooltip: '筛选流水',
            ),
            if (hasCategoryFilter)
              const Positioned(
                right: 6,
                top: 5,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: AppColors.primary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['全部', '支出', '收入'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3DECF)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: labels.asMap().entries.map((entry) {
          final selected = entry.key == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: selected
                      ? const [
                          BoxShadow(color: AppColors.shadow, blurRadius: 7),
                        ]
                      : null,
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
