import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/investment_asset.dart';
import '../domain/investment_holding.dart';
import 'investment_widgets.dart';
import '../../../app/theme/app_theme_tokens.dart';

/// One 交易记录 row: type, date, quantity × price and the resulting amount.
class TransactionItem extends StatelessWidget {
  const TransactionItem({
    required this.transaction,
    this.unit = '份',
    super.key,
  });

  final InvestmentTransaction transaction;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final type = transaction.type;
    // BUY is money leaving the pocket; everything else is money arriving.
    final amountColor = type == InvestmentTransactionType.buy
        ? context.appPrimaryText
        : AppColors.expense;
    final isCashOnly =
        type == InvestmentTransactionType.dividend ||
        type == InvestmentTransactionType.interest;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appDivider.withValues(alpha: .7)),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _tint(type),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_icon(type), size: 17, color: _color(type)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.appPrimaryText,
                        ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        DateFormat(
                          'yyyy-MM-dd',
                        ).format(transaction.transactionDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appSecondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isCashOnly
                      ? '现金分红'
                      : transaction.amountLabel(unit: unit),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appSecondaryText,
                  ),
                ),
                if (transaction.note != null &&
                    transaction.note!.trim().isNotEmpty)
                  Text(
                    transaction.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.appSecondaryText,
                    ),
                  ),
              ],
            ),
          ),
            const SizedBox(width: 8),
            // Bounded so a very large trade amount scales down rather than
            // overflowing the row.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * .4),
              child: InvestmentAmountText(
                type == InvestmentTransactionType.buy
                    ? -transaction.amount
                    : transaction.amount,
                signed: true,
                size: 14,
                weight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(InvestmentTransactionType type) => switch (type) {
    InvestmentTransactionType.buy => Icons.south_west,
    InvestmentTransactionType.sell => Icons.north_east,
    InvestmentTransactionType.dividend => Icons.redeem,
    InvestmentTransactionType.interest => Icons.savings_outlined,
  };

  static Color _color(InvestmentTransactionType type) => switch (type) {
    InvestmentTransactionType.buy => const Color(0xFFE96D6D),
    InvestmentTransactionType.sell => const Color(0xFF6F9638),
    InvestmentTransactionType.dividend => const Color(0xFFCE9A45),
    InvestmentTransactionType.interest => const Color(0xFF7C8BD9),
  };

  static Color _tint(InvestmentTransactionType type) => switch (type) {
    InvestmentTransactionType.buy => const Color(0xFFFBEDEB),
    InvestmentTransactionType.sell => const Color(0xFFEEF4E5),
    InvestmentTransactionType.dividend => const Color(0xFFF8F0DE),
    InvestmentTransactionType.interest => const Color(0xFFEDEFF9),
  };
}
