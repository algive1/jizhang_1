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
import '../../reimbursements/data/reimbursement_service.dart';
import '../data/refund_service.dart';
import '../data/transactions_repository.dart';

enum _TransactionAction {
  edit,
  editRefund,
  editReimbursement,
  category,
  refund,
  voidRefund,
  voidReimbursement,
  delete,
}

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
          if (transaction.type != TransactionType.adjustment &&
              transaction.type != TransactionType.refund &&
              transaction.type != TransactionType.reimbursement)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑流水'),
              onTap: () => Navigator.pop(sheetContext, _TransactionAction.edit),
            ),
          if (transaction.type == TransactionType.refund)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑退款'),
              onTap: () =>
                  Navigator.pop(sheetContext, _TransactionAction.editRefund),
            ),
          if (transaction.type == TransactionType.reimbursement)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑报销回款'),
              onTap: () => Navigator.pop(
                sheetContext,
                _TransactionAction.editReimbursement,
              ),
            ),
          if (onCorrectCategory != null &&
              transaction.type != TransactionType.adjustment)
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('修改分类'),
              onTap: () =>
                  Navigator.pop(sheetContext, _TransactionAction.category),
            ),
          if (transaction.isExpense &&
              transaction.refundStatus != RefundStatus.refunded &&
              transaction.type != TransactionType.adjustment)
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: const Text('登记退款'),
              onTap: () =>
                  Navigator.pop(sheetContext, _TransactionAction.refund),
            ),
          if (transaction.type == TransactionType.refund)
            ListTile(
              leading: const Icon(
                Icons.undo_outlined,
                color: AppColors.warning,
              ),
              title: const Text('撤销退款'),
              textColor: AppColors.warning,
              onTap: () =>
                  Navigator.pop(sheetContext, _TransactionAction.voidRefund),
            )
          else if (transaction.type == TransactionType.reimbursement)
            ListTile(
              leading: const Icon(
                Icons.undo_outlined,
                color: AppColors.warning,
              ),
              title: const Text('撤销报销回款'),
              textColor: AppColors.warning,
              onTap: () => Navigator.pop(
                sheetContext,
                _TransactionAction.voidReimbursement,
              ),
            )
          else
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.warning,
              ),
              title: const Text('删除流水'),
              textColor: AppColors.warning,
              onTap: () =>
                  Navigator.pop(sheetContext, _TransactionAction.delete),
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
    case _TransactionAction.editRefund:
      await _editRefund(context, ref, transaction);
    case _TransactionAction.editReimbursement:
      await _editReimbursement(context, ref, transaction);
    case _TransactionAction.category:
      await onCorrectCategory?.call();
    case _TransactionAction.refund:
      await _registerRefund(context, ref, transaction);
    case _TransactionAction.voidRefund:
      await _voidRefund(context, ref, transaction);
    case _TransactionAction.voidReimbursement:
      await _voidReimbursement(context, ref, transaction);
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

Future<void> _editReimbursement(
  BuildContext context,
  WidgetRef ref,
  TransactionRecord payment,
) async {
  final amount = await showDialog<double>(
    context: context,
    builder: (_) => _AmountInputDialog(
      title: '编辑报销回款',
      fieldLabel: '回款金额',
      actionLabel: '保存',
      initialValue: payment.amount.toStringAsFixed(2),
    ),
  );
  if (amount == null || amount <= 0) return;
  try {
    await ref
        .read(reimbursementServiceProvider)
        .updatePayment(payment: payment, amount: amount);
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('报销回款已更新')));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('报销回款更新失败：$error')));
    }
  }
}

Future<void> _voidReimbursement(
  BuildContext context,
  WidgetRef ref,
  TransactionRecord payment,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('撤销这笔报销回款？'),
      content: const Text('撤销后会恢复原消费的报销状态，并冲回到账账户余额。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确认撤销'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(reimbursementServiceProvider).voidPayment(payment);
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('报销回款已撤销')));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('撤销报销回款失败：$error')));
    }
  }
}

Future<void> _editRefund(
  BuildContext context,
  WidgetRef ref,
  TransactionRecord refund,
) async {
  final amount = await showDialog<double>(
    context: context,
    builder: (_) => _AmountInputDialog(
      title: '编辑退款',
      fieldLabel: '退款金额',
      actionLabel: '保存',
      initialValue: refund.amount.toStringAsFixed(2),
    ),
  );
  if (amount == null || amount <= 0) return;
  try {
    await ref
        .read(refundServiceProvider)
        .updateRefund(refund: refund, amount: amount);
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('退款已更新')));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('退款更新失败：$error')));
    }
  }
}

Future<void> _voidRefund(
  BuildContext context,
  WidgetRef ref,
  TransactionRecord refund,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('撤销这笔退款？'),
      content: const Text('撤销后会恢复原消费的退款状态，并冲回退款账户余额。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确认撤销'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(refundServiceProvider).voidRefund(refund);
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('退款已撤销')));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('撤销退款失败：$error')));
    }
  }
}

Future<void> _registerRefund(
  BuildContext context,
  WidgetRef ref,
  TransactionRecord original,
) async {
  final remaining = original.amount - (original.refundAmount ?? 0);
  final amount = await showDialog<double>(
    context: context,
    builder: (_) => _AmountInputDialog(
      title: '登记退款',
      fieldLabel: '退款金额',
      actionLabel: '登记',
      initialValue: remaining.toStringAsFixed(2),
    ),
  );
  if (amount == null || amount <= 0 || amount > remaining) return;
  final previous = original.refundAmount ?? 0;
  if (previous + amount > original.amount) return;
  final categories = ref.read(categoriesProvider).value ?? const [];
  final category = categories
      .where((item) => item.type == CategoryType.income)
      .firstOrNull;
  if (category == null) return;
  final now = DateTime.now();
  try {
    await ref
        .read(refundServiceProvider)
        .register(
          original: original,
          amount: amount,
          category: category,
          occurredAt: now,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('退款已记账并关联原消费')));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('退款登记失败：$error')));
    }
  }
}

class _AmountInputDialog extends StatefulWidget {
  const _AmountInputDialog({
    required this.title,
    required this.fieldLabel,
    required this.actionLabel,
    required this.initialValue,
  });

  final String title;
  final String fieldLabel;
  final String actionLabel;
  final String initialValue;

  @override
  State<_AmountInputDialog> createState() => _AmountInputDialogState();
}

class _AmountInputDialogState extends State<_AmountInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.fieldLabel,
        prefixText: '¥ ',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, double.tryParse(_controller.text.trim())),
        child: Text(widget.actionLabel),
      ),
    ],
  );
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
