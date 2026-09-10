import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../accounts/data/account_repository.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../../categories/data/category_repository.dart';
import '../../intelligence/data/merchant_rule_repository.dart';
import '../data/transactions_repository.dart';

enum _TransactionAction { edit, category, delete }

void openTransactionDetail(
  BuildContext context,
  TransactionRecord transaction,
) {
  context.push(
    '/transactions/${Uri.encodeComponent(transaction.id)}',
    extra: transaction,
  );
}

Future<void> showTransactionActions(
  BuildContext context,
  WidgetRef ref,
  TransactionRecord transaction, {
  Future<void> Function()? onCorrectCategory,
}) async {
  final action = await showModalBottomSheet<_TransactionAction>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (transaction.type == TransactionType.adjustment)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('余额校准不计入收支。需要修正时请到账户重新校准；删除会撤销这次余额差额。'),
            ),
          if (transaction.type != TransactionType.adjustment)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑流水'),
              onTap: () => Navigator.pop(sheetContext, _TransactionAction.edit),
            ),
          if (onCorrectCategory != null &&
              transaction.type != TransactionType.adjustment)
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('修改分类'),
              onTap: () =>
                  Navigator.pop(sheetContext, _TransactionAction.category),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.warning),
            title: const Text('删除流水'),
            textColor: AppColors.warning,
            onTap: () => Navigator.pop(sheetContext, _TransactionAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;

  switch (action) {
    case _TransactionAction.edit:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => QuickAddSheet(initialTransaction: transaction),
      );
    case _TransactionAction.category:
      await onCorrectCategory?.call();
    case _TransactionAction.delete:
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('删除这笔流水？'),
          content: const Text('删除后会同步撤销账户余额影响，历史记录不会再出现在流水列表。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认删除'),
            ),
          ],
        ),
      );
      if (!context.mounted || confirmed != true) return;
      await _deleteTransaction(context, ref, transaction.id);
  }
}

Future<void> showTransactionCategoryCorrection(
  BuildContext context,
  WidgetRef ref,
  TransactionRecord transaction,
) async {
  final allCategories = ref.read(categoriesProvider).value ?? const [];
  final type = transaction.isIncome
      ? CategoryType.income
      : CategoryType.expense;
  final options = allCategories.where((item) => item.type == type).toList();
  if (options.isEmpty) return;
  var selectedId = transaction.categoryId ?? options.first.id;
  var remember = false;
  final shouldSave = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '修改分类',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: const InputDecoration(labelText: '分类'),
                items: options
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setModalState(() => selectedId = value);
                  }
                },
              ),
              if ((transaction.merchant ?? '').trim().isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: remember,
                  title: const Text('以后都这样分类'),
                  subtitle: Text('记住商户：${transaction.merchant}'),
                  onChanged: (value) =>
                      setModalState(() => remember = value ?? false),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(remember ? '保存并记住规则' : '仅修改本次'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (!context.mounted || shouldSave != true) return;
  await ref
      .read(merchantRuleRepositoryProvider)
      .correctTransaction(
        transactionId: transaction.id,
        categoryId: selectedId,
        rememberForMerchant: remember,
      );
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(remember ? '已修改，并记住该商户' : '已修改本次分类')));
}

Future<void> _deleteTransaction(
  BuildContext context,
  WidgetRef ref,
  String transactionId,
) async {
  try {
    await ref.read(transactionControllerProvider).delete(transactionId);
    // Keep list/search pages correct even when a provider is paused or the
    // database stream has not delivered its invalidation yet.
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('流水已删除，账户余额已同步更新')));
  } on Object catch (error, stackTrace) {
    debugPrint(
      'Failed to delete transaction $transactionId: $error\n$stackTrace',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_deleteFailureMessage(error)),
        action: SnackBarAction(
          label: '重试',
          onPressed: () =>
              unawaited(_deleteTransaction(context, ref, transactionId)),
        ),
      ),
    );
  }
}

String _deleteFailureMessage(Object error) {
  final raw = error.toString().trim();
  final message = raw.replaceFirst(
    RegExp(r'^[A-Za-z]+(?:Error|Exception):\s*'),
    '',
  );
  if (message.isEmpty || message == raw && raw == 'Instance of \'Object\'') {
    return '删除失败，请点击“重试”或稍后再试';
  }
  return '删除失败：$message';
}
