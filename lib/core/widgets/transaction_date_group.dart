import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../formatters/money_formatter.dart';
import '../models/transaction_record.dart';
import 'app_card.dart';
import 'transaction_tile.dart';

class TransactionDateGroup extends StatelessWidget {
  const TransactionDateGroup({
    required this.dateLabel,
    required this.transactions,
    super.key,
    this.onTransactionTap,
    this.onTransactionLongPress,
    this.accountNames = const {},
  });

  final String dateLabel;
  final List<TransactionRecord> transactions;
  final ValueChanged<TransactionRecord>? onTransactionTap;
  final ValueChanged<TransactionRecord>? onTransactionLongPress;
  final Map<String, String> accountNames;

  @override
  Widget build(BuildContext context) {
    final currencies = transactions
        .map((t) => t.currency.toUpperCase())
        .toSet();
    double total(String currency, bool expense) =>
        transactions
            .where(
              (t) =>
                  t.deletedAt == null &&
                  t.currency.toUpperCase() == currency &&
                  (expense ? t.isExpense : t.isIncome),
            )
            .fold<int>(
              0,
              (sum, t) =>
                  sum +
                  ((expense ? t.netExpenseAmount : t.amount) * 100).round(),
            ) /
        100;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              dateLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final currency in currencies)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 12,
                runSpacing: 3,
                children: [
                  Text(
                    '支出 ${currency == 'CNY' ? '¥' : '$currency '}${MoneyFormatter.decimal(total(currency, true))}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '收入 ${currency == 'CNY' ? '¥' : '$currency '}${MoneyFormatter.decimal(total(currency, false))}',
                    style: const TextStyle(
                      color: AppColors.income,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          ...transactions.map((transaction) {
            final source = accountNames[transaction.accountId];
            final destination = transaction.destinationAccountId == null
                ? null
                : accountNames[transaction.destinationAccountId!];
            final accountLabel = source == null
                ? null
                : destination == null
                ? source
                : '$source → $destination';
            return TransactionTile(
              transaction: transaction,
              accountName: accountLabel,
              onTap: onTransactionTap == null
                  ? null
                  : () => onTransactionTap!(transaction),
              onLongPress: onTransactionLongPress == null
                  ? null
                  : () => onTransactionLongPress!(transaction),
            );
          }),
        ],
      ),
    );
  }
}
