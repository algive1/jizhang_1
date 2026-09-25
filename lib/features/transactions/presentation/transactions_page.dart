import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/formatters/transaction_date_formatter.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/transaction_date_group.dart';
import '../../../core/widgets/transaction_summary_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../categories/data/category_repository.dart';
import '../../accounts/data/account_repository.dart';
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
    final accounts = ref.watch(allAccountsProvider).value ?? const [];
    final accountNames = {
      for (final account in accounts) account.id: account.displayName,
    };
    final inboxCount = ref.watch(pendingInboxProvider).value?.length ?? 0;
    final typedTransactions = switch (_typeFilter) {
      1 => all.where((item) => item.isExpense),
      2 => all.where((item) => item.isIncome),
      _ => all,
    };
    final transactions = typedTransactions
        .where(
          (item) =>
              _categoryFilter == null ||
              item.categoryName == _categoryFilter ||
              item.subcategoryName == _categoryFilter,
        )
        .toList();

    final groups = _groupTransactions(transactions);
    final summary = _monthlySummary(all);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                  onTypeChanged: (value) {
                    if (value != _typeFilter) {
                      setState(() => _typeFilter = value);
                    }
                  },
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
                  spending: summary.expense,
                  income: summary.income,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '月度汇总为 CNY · 全部分类 · 截至当前',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appSecondaryText,
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
                        selectedColor: context.appPrimarySoft,
                        labelStyle: TextStyle(color: context.appPrimary),
                        side: BorderSide.none,
                        onDeleted: () => setState(() => _categoryFilter = null),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
              ]),
            ),
          ),
          if (groups.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                AppScaffold.reservedBottomInset(context),
              ),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      '没有找到匹配的记录',
                      style: TextStyle(color: context.appSecondaryText),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                AppScaffold.reservedBottomInset(context),
              ),
              sliver: SliverList.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final entry = groups[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TransactionDateGroup(
                      dateLabel: TransactionDateFormatter.groupLabel(entry.date),
                      transactions: entry.transactions,
                      accountNames: accountNames,
                      onTransactionTap: (transaction) =>
                          openTransactionDetail(context, transaction),
                      onTransactionLongPress: _showTransactionActions,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<({DateTime date, List<TransactionRecord> transactions})>
      _groupTransactions(List<TransactionRecord> transactions) {
    final groups = <DateTime, List<TransactionRecord>>{};
    for (final transaction in transactions) {
      final date = DateUtils.dateOnly(transaction.occurredAt);
      groups.putIfAbsent(date, () => []).add(transaction);
    }
    return [
      for (final entry in groups.entries)
        (date: entry.key, transactions: entry.value),
    ];
  }

  ({double expense, double income}) _monthlySummary(
    List<TransactionRecord> transactions,
  ) {
    final now = DateTime.now();
    final target = widget.month ?? now;
    var expenseCents = 0;
    var incomeCents = 0;
    for (final item in transactions) {
      if (item.currency.toUpperCase() != 'CNY' ||
          item.deletedAt != null ||
          item.occurredAt.isAfter(now) ||
          item.occurredAt.year != target.year ||
          item.occurredAt.month != target.month) {
        continue;
      }
      if (item.isExpense) {
        expenseCents += (item.netExpenseAmount * 100).round();
      } else if (item.isIncome) {
        incomeCents += (item.amount * 100).round();
      }
    }
    return (expense: expenseCents / 100, income: incomeCents / 100);
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
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .68,
          child: Material(
            color: context.appSheetSurface,
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
                      color: context.appDivider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
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
                                  ? Icon(
                                      Icons.check,
                                      color: context.appPrimary,
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
        IconButton(
          onPressed: () => context.push('/transactions/reimbursements'),
          icon: const Icon(Icons.receipt_long_outlined, size: 27),
          tooltip: '报销管理',
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
          icon: Icon(Icons.search, size: 30),
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
              icon: Icon(Icons.filter_alt_outlined, size: 28),
              tooltip: '筛选流水',
            ),
            if (hasCategoryFilter)
              Positioned(
                right: 6,
                top: 5,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: context.appPrimary,
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
        border: Border.all(color: context.appDivider),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: labels.asMap().entries.map((entry) {
          final selected = entry.key == selectedIndex;
          return Expanded(
            child: GestureDetector(
              key: ValueKey('transactions-filter-${entry.key}'),
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? context.appSurface : Colors.transparent,
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
                        ? context.appPrimary
                        : context.appSecondaryText,
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
