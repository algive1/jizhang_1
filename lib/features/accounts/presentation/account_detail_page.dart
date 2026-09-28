import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/account.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../data/account_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/transaction_actions.dart';
import '../../../app/theme/app_theme_tokens.dart';

class AccountDetailPage extends ConsumerStatefulWidget {
  const AccountDetailPage({required this.accountId, super.key});

  final String accountId;

  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  static const _pageSize = 100;
  int _filter = 0;
  int _visibleLimit = _pageSize;

  @override
  Widget build(BuildContext context) {
    final allAccounts =
        ref.watch(assetDashboardAccountsProvider).value ?? const <Account>[];
    final account = allAccounts
        .where((item) => item.id == widget.accountId)
        .firstOrNull;
    if (account == null) {
      return const SafeArea(child: Center(child: Text('账户不存在')));
    }
    final all =
        ref
            .watch(
              accountTransactionsProvider((
                accountId: account.id,
                limit: _visibleLimit,
              )),
            )
            .value ??
        const <TransactionRecord>[];
    final transactions = all.where(_matchesFilter).toList(growable: false);
    final monthSummary =
        ref.watch(accountMonthSummaryProvider(account.id)).value ??
        (inflow: 0.0, outflow: 0.0);
    final inflow = monthSummary.inflow;
    final outflow = monthSummary.outflow;
    final canLoadMore = all.length >= _visibleLimit;
    final accountNames = {
      for (final item in allAccounts) item.id: item.displayName,
    };
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/profile/assets'),
                icon: Icon(Icons.arrow_back),
                tooltip: '返回资产总览',
              ),
              Expanded(
                child: Text(
                  key: const ValueKey('account-detail-title'),
                  account.displayName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          AppCard(
            color: context.appPrimarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.type.label,
                  style: TextStyle(color: context.appSecondaryText),
                ),
                const SizedBox(height: 5),
                MoneyText(
                  account.balance,
                  currency: account.currency,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: context.appPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: '本月流入',
                        value: inflow,
                        positive: true,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: '本月流出',
                        value: outflow,
                        positive: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('全部')),
                ButtonSegment(value: 1, label: Text('收入')),
                ButtonSegment(value: 2, label: Text('支出')),
                ButtonSegment(value: 3, label: Text('转账')),
                ButtonSegment(value: 4, label: Text('调整')),
              ],
              selected: {_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
            ),
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            AppCard(
              child: Column(
                children: [
                  Text(
                    '暂无该账户流水',
                    style: TextStyle(color: context.appSecondaryText),
                  ),
                  if (canLoadMore) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      key: const ValueKey('account-transactions-load-more-empty'),
                      onPressed: () =>
                          setState(() => _visibleLimit += _pageSize),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('继续加载更早流水'),
                    ),
                  ],
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: transactions.asMap().entries.map((entry) {
                  final source = accountNames[entry.value.accountId];
                  final destination = entry.value.destinationAccountId == null
                      ? null
                      : accountNames[entry.value.destinationAccountId!];
                  return TransactionTile(
                    transaction: entry.value,
                    accountName: source == null
                        ? null
                        : destination == null
                        ? source
                        : '$source → $destination',
                    showDate: true,
                    showDivider: entry.key != transactions.length - 1,
                    onTap: () => openTransactionDetail(context, entry.value),
                    onLongPress: () => showTransactionActions(
                      context,
                      ref,
                      entry.value,
                    ),
                  );
                }).toList(),
              ),
            ),
          if (transactions.isNotEmpty && canLoadMore) ...[
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                key: const ValueKey('account-transactions-load-more'),
                onPressed: () => setState(() => _visibleLimit += _pageSize),
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('加载更多流水'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _matchesFilter(TransactionRecord item) => switch (_filter) {
    1 => item.isIncome,
    2 => item.isExpense || item.isDebtRepayment,
    3 => item.type == TransactionType.transfer,
    4 => item.type == TransactionType.adjustment,
    _ => true,
  };


}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.positive,
  });
  final String label;
  final double value;
  final bool positive;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 12, color: context.appSecondaryText),
      ),
      MoneyText(
        value,
        showSign: true,
        positive: positive,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ],
  );
}
