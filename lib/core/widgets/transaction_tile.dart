import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../formatters/transaction_date_formatter.dart';
import '../models/transaction_record.dart';
import 'category_icon.dart';
import 'money_text.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.transaction,
    super.key,
    this.showDivider = true,
    this.showDate = false,
    this.homeStyle = false,
    this.accountName,
    this.onTap,
    this.onLongPress,
  });

  final TransactionRecord transaction;
  final bool showDivider;
  final bool showDate;
  final bool homeStyle;
  final String? accountName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final time = showDate
        ? TransactionDateFormatter.monthDayTime(transaction.occurredAt)
        : TransactionDateFormatter.time(transaction.occurredAt);
    final isTransfer = transaction.type == TransactionType.transfer;
    final isIncome = transaction.type == TransactionType.adjustment
        ? transaction.amount > 0
        : transaction.isIncome;
    final category = transaction.type == TransactionType.adjustment
        ? '余额校准'
        : isTransfer
        ? '转账'
        : (transaction.categoryName ?? '未分类');
    final merchant = transaction.merchant ?? transaction.note ?? '未命名交易';
    return Semantics(
      button: true,
      label: '$merchant，$category，交易操作',
      hint: onLongPress == null ? '点击打开操作菜单' : '点击或长按打开操作菜单',
      onTap: onTap,
      onLongPress: onLongPress,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (homeStyle && constraints.maxWidth >= 300) {
                    return _HomeReferenceTransactionRow(
                      transaction: transaction,
                      accountName: accountName,
                      showDate: showDate,
                    );
                  }
                  if (constraints.maxWidth < 300) {
                    return _CompactTransactionRow(
                      transaction: transaction,
                      time: time,
                      vivid: homeStyle,
                      accountName: accountName,
                    );
                  }
                  return Row(
                    children: [
                      CategoryIcon(
                        category: category,
                        iconKey: transaction.categoryIcon,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: Text(
                          category,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      SizedBox(
                        width: showDate ? 86 : 48,
                        child: Text(
                          time,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      MoneyText(
                        transaction.amount,
                        currency: transaction.currency,
                        positive: isTransfer ? null : isIncome,
                        showSign: !isTransfer,
                        style: Theme.of(context).textTheme.titleMedium!,
                      ),
                    ],
                  );
                },
              ),
            ),
            if (showDivider)
              const Divider(indent: 60, color: AppColors.divider),
          ],
        ),
      ),
    );
  }
}

class _CompactTransactionRow extends StatelessWidget {
  const _CompactTransactionRow({
    required this.transaction,
    required this.time,
    this.vivid = false,
    this.accountName,
  });

  final TransactionRecord transaction;
  final String time;
  final bool vivid;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final isTransfer = transaction.type == TransactionType.transfer;
    final category = transaction.type == TransactionType.adjustment
        ? '余额校准'
        : isTransfer
        ? '转账'
        : (transaction.categoryName ?? '未分类');
    final merchant = transaction.merchant ?? transaction.note ?? '未命名交易';
    return Row(
      children: [
        CategoryIcon(
          category: category,
          iconKey: transaction.categoryIcon,
          vivid: vivid,
          size: vivid ? 38 : 46,
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merchant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 3),
              Text(
                '$category  ·  $time${accountName == null ? '' : '  ·  $accountName'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 4,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: MoneyText(
              transaction.amount,
              currency: transaction.currency,
              positive: isTransfer
                  ? null
                  : (transaction.type == TransactionType.adjustment
                        ? transaction.amount > 0
                        : transaction.isIncome),
              showSign: !isTransfer,
              style: Theme.of(context).textTheme.titleMedium!,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeReferenceTransactionRow extends StatelessWidget {
  const _HomeReferenceTransactionRow({
    required this.transaction,
    this.accountName,
    this.showDate = true,
  });
  final TransactionRecord transaction;
  final String? accountName;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final isTransfer = transaction.type == TransactionType.transfer;
    final isIncome = transaction.type == TransactionType.adjustment
        ? transaction.amount > 0
        : transaction.isIncome;
    final category = transaction.type == TransactionType.adjustment
        ? '余额校准'
        : isTransfer
        ? '转账'
        : (transaction.categoryName ?? '未分类');
    final now = DateTime.now();
    final occurredAt = transaction.occurredAt.toLocal();
    final date = DateUtils.dateOnly(occurredAt);
    final today = DateTime(now.year, now.month, now.day);
    final dayLabel = date == today
        ? '今天'
        : date == today.subtract(const Duration(days: 1))
        ? '昨天'
        : '${occurredAt.month}月${occurredAt.day}日';
    final merchant = transaction.merchant ?? transaction.note ?? '未命名交易';
    final clock =
        '${occurredAt.hour.toString().padLeft(2, '0')}:${occurredAt.minute.toString().padLeft(2, '0')}';
    final time = showDate ? '$dayLabel $clock' : clock;
    return Row(
      children: [
        CategoryIcon(
          category: category,
          iconKey: transaction.categoryIcon,
          vivid: true,
          size: 30,
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Text(
            merchant,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 3,
          child: Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            accountName ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: MoneyText(
              transaction.amount,
              currency: transaction.currency,
              positive: isTransfer ? null : isIncome,
              showSign: !isTransfer,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
