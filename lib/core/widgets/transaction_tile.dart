import 'package:flutter/material.dart';

import '../formatters/transaction_date_formatter.dart';
import '../models/transaction_record.dart';
import 'category_icon.dart';
import 'money_text.dart';
import '../../app/theme/app_theme_tokens.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.transaction,
    super.key,
    this.showDivider = true,
    this.showDate = false,
    this.homeStyle = false,
    this.amountHidden = false,
    this.accountName,
    this.onTap,
    this.onLongPress,
  });

  final TransactionRecord transaction;
  final bool showDivider;
  final bool showDate;
  final bool homeStyle;
  final bool amountHidden;
  final String? accountName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final time = showDate
        ? TransactionDateFormatter.monthDayTime(transaction.occurredAt)
        : TransactionDateFormatter.time(transaction.occurredAt);
    final category = transaction.displayCategoryLabel;
    final merchant = transaction.displayTitle;
    return Semantics(
      button: true,
      label: '$merchant，$category，交易详情',
      hint: onLongPress == null ? '点击查看详情' : '点击查看详情，长按打开操作菜单',
      onTap: onTap,
      onLongPress: onLongPress,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _TransactionRow(
                transaction: transaction,
                time: time,
                accountName: accountName,
                amountHidden: amountHidden,
              ),
            ),
            if (showDivider)
              const Divider(height: 1, indent: 50, color: context.appDivider),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.time,
    this.accountName,
    this.amountHidden = false,
  });

  final TransactionRecord transaction;
  final String time;
  final String? accountName;
  final bool amountHidden;

  @override
  Widget build(BuildContext context) {
    final isTransfer = transaction.type == TransactionType.transfer;
    final category = transaction.displayCategoryLabel;
    final title = transaction.displayTitle;
    final subtitle = [
      if (title != category) category,
      time,
      if (accountName?.isNotEmpty == true) accountName!,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CategoryIcon(
          category: category,
          iconKey: transaction.categoryIcon,
          monochrome: true,
          size: 40,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.appPrimaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MoneyText(
                          transaction.amount,
                          currency: transaction.currency,
                          positive: isTransfer
                              ? null
                              : (transaction.type == TransactionType.adjustment
                                    ? transaction.amount > 0
                                    : transaction.isIncome),
                          showSign: !isTransfer,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.appPrimaryText,
                          ),
                          hidden: amountHidden,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: context.appSecondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
