import '../../../../core/widgets/app_form.dart';
import 'time_selector.dart';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/account.dart';
import '../../../../core/models/category.dart';
import '../../../../core/models/transaction_record.dart';
import '../../../../core/models/voice_bookkeeping.dart';
import '../../../../app/theme/app_theme_tokens.dart';

class AIConfirmCard extends StatelessWidget {
  const AIConfirmCard({
    super.key,
    required this.index,
    required this.transaction,
    required this.accounts,
    required this.categories,
    required this.onChanged,
  });

  final int index;
  final ParsedVoiceTransaction transaction;
  final List<Account> accounts;
  final List<Category> categories;
  final void Function(ParsedVoiceTransaction value, bool categoryCorrected)
  onChanged;

  @override
  Widget build(BuildContext context) {
    final categoryType = transaction.type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    final categoryOptions = categories
        .where((item) => item.type == categoryType)
        .toList();
    final categoryValue =
        categoryOptions.any((item) => item.id == transaction.categoryId)
        ? transaction.categoryId
        : null;
    final suffixMatch = transaction.identifierSuffix == null
        ? const <Account>[]
        : accounts
              .where(
                (item) => item.identifierSuffix == transaction.identifierSuffix,
              )
              .toList();
    final nameMatch = transaction.accountName == null
        ? const <Account>[]
        : accounts
              .where(
                (item) =>
                    item.displayName == transaction.accountName ||
                    item.name == transaction.accountName,
              )
              .toList();
    final accountValue =
        transaction.identifierSuffix != null && suffixMatch.length == 1
        ? suffixMatch.single.id
        : accounts.any((item) => item.id == transaction.accountId)
        ? transaction.accountId
        : suffixMatch.length == 1
        ? suffixMatch.single.id
        : nameMatch.length == 1
        ? nameMatch.single.id
        : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border.all(
          color: transaction.needsReview
              ? AppColors.warning
              : context.appDivider,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '第 ${index + 1} 笔 · ${transaction.type == TransactionType.income ? '收入' : '支出'}',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${(transaction.confidence * 100).round()}% 置信度',
                style: TextStyle(
                  color: context.appSecondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: transaction.amount.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        '金额 ${accounts.where((a) => a.id == accountValue).firstOrNull?.currency ?? 'CNY'}',
                  ),
                  onChanged: (value) {
                    final amount = double.tryParse(value);
                    if (amount != null) {
                      onChanged(transaction.copyWith(amount: amount), false);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppSelect<String>(
                  initialValue: accountValue,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '账户'),
                  items: accounts
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            item.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    final account = accounts
                        .where((item) => item.id == value)
                        .firstOrNull;
                    if (account != null) {
                      onChanged(
                        transaction.copyWith(
                          accountId: account.id,
                          accountName: account.displayName,
                        ),
                        false,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppSelect<String>(
            initialValue: categoryValue,
            decoration: const InputDecoration(labelText: '分类'),
            items: categoryOptions
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) {
              final category = categoryOptions
                  .where((item) => item.id == value)
                  .firstOrNull;
              if (category != null) {
                onChanged(
                  transaction.copyWith(
                    categoryId: category.id,
                    categoryName: category.name,
                  ),
                  category.id != transaction.categoryId,
                );
              }
            },
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '时间：${transaction.occurredAt.year}-${transaction.occurredAt.month}-${transaction.occurredAt.day} ${TimeOfDay.fromDateTime(transaction.occurredAt).format(context)}',
              ),
              subtitle: transaction.subcategoryName == null
                  ? null
                  : Text('二级分类：${transaction.subcategoryName}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final value = await TimeSelector.show(
                  context,
                  transaction.occurredAt,
                );
                if (value != null) {
                  onChanged(transaction.copyWith(occurredAt: value), false);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: transaction.merchant,
            decoration: const InputDecoration(labelText: '商户/用途'),
            onChanged: (value) =>
                onChanged(transaction.copyWith(merchant: value.trim()), false),
          ),
        ],
      ),
    );
  }
}
