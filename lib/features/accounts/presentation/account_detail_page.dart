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
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final allAccounts =
        ref.watch(assetDashboardAccountsProvider).value ?? const <Account>[];
    final account = allAccounts
        .where((item) => item.id == widget.accountId)
        .firstOrNull;
    final all =
        ref.watch(allTransactionsProvider).value ?? const <TransactionRecord>[];
    if (account == null) {
      return const SafeArea(child: Center(child: Text('账户不存在')));
    }
    final transactions =
        all
            .where(
              (item) =>
                  item.accountId == account.id ||
                  item.destinationAccountId == account.id,
            )
            .where(_matchesFilter)
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final now = DateTime.now();
    final month = all.where(
      (item) =>
          (item.accountId == account.id ||
              item.destinationAccountId == account.id) &&
          item.occurredAt.year == now.year &&
          item.occurredAt.month == now.month &&
          !item.occurredAt.isAfter(now) &&
          item.deletedAt == null,
    );
    final inflow = month.fold<double>(
      0,
      (sum, item) => sum + _accountInflow(item, account.id),
    );
    final outflow = month.fold<double>(
      0,
      (sum, item) => sum + _accountOutflow(item, account.id),
    );
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
              child: Text(
                '暂无该账户流水',
                style: TextStyle(color: context.appSecondaryText),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: transactions.asMap().entries.map((entry) {
                  final source = allAccounts
                      .where((item) => item.id == entry.value.accountId)
                      .firstOrNull
                      ?.displayName;
                  final destination = entry.value.destinationAccountId == null
                      ? null
                      : allAccounts
                            .where(
                              (item) =>
                                  item.id == entry.value.destinationAccountId,
                            )
                            .firstOrNull
                            ?.displayName;
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

  double _accountInflow(TransactionRecord item, String id) {
    if (item.type == TransactionType.transfer ||
        item.type == TransactionType.repayment)
      return item.destinationAccountId == id ? item.amount : 0;
    return item.accountId == id && item.isIncome ? item.amount : 0;
  }

  double _accountOutflow(TransactionRecord item, String id) {
    if (item.type == TransactionType.transfer)
      return item.accountId == id ? item.amount : 0;
    return item.accountId == id && (item.isExpense || item.isDebtRepayment)
        ? item.amount
        : 0;
  }
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
