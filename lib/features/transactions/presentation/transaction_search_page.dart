import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../../accounts/data/account_repository.dart';
import '../../recurring/data/recurring_bill_repository.dart';
import '../../../core/models/recurring_bill.dart';
import '../data/transactions_repository.dart';
import 'transaction_actions.dart';
import '../../../app/theme/app_theme_tokens.dart';

class TransactionSearchPage extends ConsumerStatefulWidget {
  const TransactionSearchPage({
    super.key,
    this.month,
    this.transactionIds = const {},
  });
  final DateTime? month;
  final Set<String> transactionIds;

  @override
  ConsumerState<TransactionSearchPage> createState() =>
      _TransactionSearchPageState();
}

class _TransactionSearchPageState extends ConsumerState<TransactionSearchPage> {
  static const _pageSize = 100;
  final _controller = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  String _effectiveQuery = '';
  int _visibleLimit = _pageSize;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _effectiveQuery = value;
        _visibleLimit = _pageSize;
      });
    });
  }

  void _clearQuery() {
    _searchDebounce?.cancel();
    _controller.clear();
    setState(() {
      _query = '';
      _effectiveQuery = '';
      _visibleLimit = _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = _effectiveQuery.trim();
    final transactionState = widget.transactionIds.isNotEmpty
        ? ref.watch(
            transactionsByIdsProvider(
              transactionIdsProviderKey(widget.transactionIds),
            ),
          )
        : trimmedQuery.isNotEmpty
        ? ref.watch(
            transactionSearchProvider((
              query: trimmedQuery,
              year: widget.month?.year,
              month: widget.month?.month,
              limit: _visibleLimit,
            )),
          )
        : widget.month != null
        ? ref.watch(
            transactionsForMonthProvider((
              year: widget.month!.year,
              month: widget.month!.month,
            )),
          )
        : ref.watch(recentTransactionsPageProvider(_visibleLimit));
    final all = transactionState.value ?? const <TransactionRecord>[];
    final accounts = ref.watch(allAccountsProvider).value ?? const [];
    final recurringBills =
        widget.transactionIds.isEmpty && trimmedQuery.isNotEmpty
        ? ref.watch(recurringBillsAllProvider).value ?? const <RecurringBill>[]
        : const <RecurringBill>[];
    final accountNames = {
      for (final account in accounts) account.id: account.displayName,
    };
    final results = all.where((transaction) {
      if (widget.transactionIds.isNotEmpty &&
          !widget.transactionIds.contains(transaction.id)) {
        return false;
      }
      if (widget.month != null &&
          (transaction.occurredAt.year != widget.month!.year ||
              transaction.occurredAt.month != widget.month!.month ||
              transaction.occurredAt.isAfter(DateTime.now())))
        return false;
      return _matchesSearch(transaction, accountNames);
    }).toList();
    final recurringResults = recurringBills
        .where((bill) => _matchesRecurring(bill, accountNames))
        .toList();
    final canLoadMore =
        widget.transactionIds.isEmpty &&
        all.length >= _visibleLimit &&
        (trimmedQuery.isNotEmpty || widget.month == null);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
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
                        autofocus: widget.transactionIds.isEmpty,
                        onChanged: _onQueryChanged,
                        decoration: InputDecoration(
                          hintText: '搜索商户、分类或备注',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _clearQuery,
                                  icon: Icon(Icons.close),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.transactionIds.isNotEmpty
                      ? '相关流水 · ${results.length} 笔'
                      : trimmedQuery.isEmpty
                      ? widget.month == null
                            ? '最近记录 · ${results.length} 笔'
                            : '本月记录 · ${results.length} 笔'
                      : canLoadMore
                      ? '已显示 ${results.length} 笔匹配记录'
                      : '找到 ${results.length} 笔记录',
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                if (results.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 72),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          color: context.appSecondaryText,
                          size: 44,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '没有找到匹配的记录',
                          style: TextStyle(color: context.appSecondaryText),
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
                              accountName: _accountLabel(
                                entry.value,
                                accountNames,
                              ),
                              showDivider: entry.key != results.length - 1,
                              showDate: true,
                              onTap: () =>
                                  openTransactionDetail(context, entry.value),
                              onLongPress: () =>
                                  _showTransactionActions(entry.value),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (canLoadMore) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: OutlinedButton.icon(
                      key: const ValueKey('transaction-search-load-more'),
                      onPressed: () =>
                          setState(() => _visibleLimit += _pageSize),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text(
                        trimmedQuery.isEmpty
                            ? '加载更多流水'
                            : '加载更多匹配记录',
                      ),
                    ),
                  ),
                ],
                if (widget.transactionIds.isEmpty &&
                    trimmedQuery.isNotEmpty &&
                    recurringResults.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    '匹配的周期账单',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: recurringResults
                          .map(
                            (bill) => ListTile(
                              leading: const Icon(Icons.event_repeat_outlined),
                              title: Text(bill.name),
                              subtitle: Text(
                                '${bill.amount.toStringAsFixed(2)} · ${_recurringCycleLabel(bill)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  context.push('/profile/recurring-bills'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(
    TransactionRecord transaction,
    Map<String, String> accountNames,
  ) {
    final query = _effectiveQuery.trim();
    if (query.isEmpty) return true;
    final amountMatch = RegExp(
      r'^(>=|>|<=|<)?\s*([0-9]+(?:\.[0-9]+)?)\s*(?:元|块)?(?:以上|以下)?$',
    ).firstMatch(query);
    if (amountMatch != null) {
      final amount = double.tryParse(amountMatch.group(2)!);
      if (amount == null) return false;
      final value = transaction.isExpense
          ? transaction.netExpenseAmount
          : transaction.amount;
      final operator = amountMatch.group(1);
      if (query.contains('以上')) return value >= amount;
      if (query.contains('以下')) return value <= amount;
      return switch (operator) {
        '>=' => value >= amount,
        '>' => value > amount,
        '<=' => value <= amount,
        '<' => value < amount,
        _ => value == amount,
      };
    }
    final date =
        '${transaction.occurredAt.year}-${transaction.occurredAt.month.toString().padLeft(2, '0')}-${transaction.occurredAt.day.toString().padLeft(2, '0')}';
    final metadata = transaction.metadataJson ?? '';
    return (transaction.merchant?.contains(query) ?? false) ||
        transaction.displayCategoryPath.contains(query) ||
        (transaction.note?.contains(query) ?? false) ||
        (accountNames[transaction.accountId]?.contains(query) ?? false) ||
        (transaction.destinationAccountId != null &&
            (accountNames[transaction.destinationAccountId]?.contains(query) ??
                false)) ||
        date.contains(query) ||
        metadata.contains(query) ||
        _statusLabel(transaction).contains(query);
  }

  String? _accountLabel(
    TransactionRecord transaction,
    Map<String, String> accountNames,
  ) {
    final source = accountNames[transaction.accountId];
    final destination = transaction.destinationAccountId == null
        ? null
        : accountNames[transaction.destinationAccountId!];
    if (source == null) return null;
    return destination == null ? source : '$source → $destination';
  }

  bool _matchesRecurring(RecurringBill bill, Map<String, String> accountNames) {
    final query = _effectiveQuery.trim();
    if (query.isEmpty) return false;
    final amountMatch = RegExp(
      r'^(>=|>|<=|<)?\s*([0-9]+(?:\.[0-9]+)?)\s*(?:元|块)?(?:以上|以下)?$',
    ).firstMatch(query);
    if (amountMatch != null) {
      final amount = double.tryParse(amountMatch.group(2)!);
      if (amount == null) return false;
      final operator = amountMatch.group(1);
      if (query.contains('以上')) return bill.amount >= amount;
      if (query.contains('以下')) return bill.amount <= amount;
      return switch (operator) {
        '>=' => bill.amount >= amount,
        '>' => bill.amount > amount,
        '<=' => bill.amount <= amount,
        '<' => bill.amount < amount,
        _ => bill.amount == amount,
      };
    }
    return bill.name.contains(query) ||
        _recurringCycleLabel(bill).contains(query) ||
        (bill.accountId != null &&
            (accountNames[bill.accountId]?.contains(query) ?? false));
  }

  String _recurringCycleLabel(RecurringBill bill) => switch (bill.cycle) {
    RecurringBillCycle.daily => '每天',
      RecurringBillCycle.weekly => '每周',
    RecurringBillCycle.monthly => '每月',
    RecurringBillCycle.quarterly => '每季度',
    RecurringBillCycle.halfYear => '每半年',
    RecurringBillCycle.yearly => '每年',
    RecurringBillCycle.custom => '自定义',
  };

  String _statusLabel(TransactionRecord value) =>
      switch (value.reimbursementStatus) {
        ReimbursementStatus.none => '无需报销',
        ReimbursementStatus.pending => '待报销',
        ReimbursementStatus.partial => '部分报销',
        ReimbursementStatus.reimbursed => '已报销',
      };

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
