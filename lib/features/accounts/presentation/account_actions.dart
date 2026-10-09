import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/account.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_action_sheet.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../../books/data/book_repository.dart';
import '../data/account_management_repository.dart';
import '../data/account_repository.dart';
import 'account_forms.dart';

class AccountActionsMenu extends ConsumerWidget {
  const AccountActionsMenu({required this.account, super.key});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AppActionMenuButton<String>(
        key: ValueKey('account-actions-${account.id}'),
        tooltip: '${account.displayName}的更多操作',
        onSelected: (action) =>
            performAccountAction(context, ref, account, action),
        itemBuilder: (_) => [
          if (account.isArchived)
            const PopupMenuItem(value: 'restore', child: Text('恢复账户'))
          else ...[
            const PopupMenuItem(value: 'edit', child: Text('编辑账户')),
            PopupMenuItem(
              value: 'calibrate',
              child: Text(account.type.isDebt ? '校准欠款' : '校准余额'),
            ),
            if (account.type.isDebt && account.balance < 0)
              const PopupMenuItem(value: 'repay', child: Text('还款')),
            const PopupMenuItem(value: 'archive', child: Text('归档账户')),
          ],
        ],
      );
}

String accountTransactionBookId(WidgetRef ref, Account account) {
  final active = ref.read(activeBookProvider);
  return active?.assetBookId == account.bookId ? active!.id : account.bookId;
}

Future<void> performAccountAction(
  BuildContext context,
  WidgetRef ref,
  Account account,
  String action,
) async {
  try {
    final database = ref.read(databaseProvider);
    final repository = DriftAccountRepository(database, bookId: account.bookId);
    switch (action) {
      case 'edit':
        final managed = await DriftAccountManagementRepository(
          database,
          repository,
          bookId: account.bookId,
        ).getById(account.id);
        if (context.mounted) {
          await showAccountEditor(context, account: account, managed: managed);
        }
      case 'calibrate':
        await showBalanceCalibration(context, account);
      case 'repay':
        final books = await ref.read(booksProvider.future);
        final active = ref.read(activeBookProvider);
        final bookId = active?.assetBookId == account.bookId
            ? active!.id
            : books.where((book) => book.id == account.bookId).firstOrNull?.id;
        if (bookId == null) throw StateError('账户所属账本不可用');
        if (context.mounted) {
          await showQuickAddSheet(
            context,
            initialType: TransactionType.repayment,
            initialBookId: bookId,
            initialDestinationAccountId: account.id,
          );
        }
      case 'archive':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('归档账户？'),
            content: const Text('历史流水和余额仍保留，继续计入资产。以后可恢复使用。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('归档'),
              ),
            ],
          ),
        );
        if (confirmed == true) await repository.archive(account.id);
      case 'restore':
        await repository.restore(account.id);
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }
}
