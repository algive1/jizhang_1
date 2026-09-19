import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/transaction_actions.dart';
import '../data/reimbursement_service.dart';

/// Reimbursement is a view over the canonical transaction table. It never
/// creates a second expense ledger; a payment row links back to its source.
class ReimbursementPage extends ConsumerStatefulWidget {
  const ReimbursementPage({super.key});

  @override
  ConsumerState<ReimbursementPage> createState() => _ReimbursementPageState();
}

class _ReimbursementPageState extends ConsumerState<ReimbursementPage> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final all =
        ref.watch(transactionsProvider).value ?? const <TransactionRecord>[];
    final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final books = ref.watch(booksProvider).value ?? const [];
    final accountNames = {
      for (final account in accounts) account.id: account.displayName,
    };
    final bookNames = {for (final book in books) book.id: book.name};
    final records =
        all
            .where(
              (item) => item.reimbursementStatus != ReimbursementStatus.none,
            )
            .where((item) {
              if (_filter == 1) {
                return item.reimbursementStatus ==
                        ReimbursementStatus.pending ||
                    item.reimbursementStatus == ReimbursementStatus.partial;
              }
              if (_filter == 2) {
                return item.reimbursementStatus ==
                    ReimbursementStatus.reimbursed;
              }
              return true;
            })
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final pending = all
        .where(
          (item) =>
              item.reimbursementStatus == ReimbursementStatus.pending ||
              item.reimbursementStatus == ReimbursementStatus.partial,
        )
        .fold<double>(0, (sum, item) => sum + _reimbursementAmount(item));
    final reimbursed = all
        .where(
          (item) => item.reimbursementStatus == ReimbursementStatus.reimbursed,
        )
        .fold<double>(0, (sum, item) => sum + _reimbursementAmount(item));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/transactions'),
                icon: Icon(Icons.arrow_back),
                tooltip: '返回流水',
              ),
              Expanded(
                child: Text(
                  '报销管理',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          AppCard(
            color: context.appPrimarySoft,
            child: Row(
              children: [
                Expanded(
                  child: _Summary(label: '待报销', amount: pending),
                ),
                Container(width: 1, height: 42, color: context.appDivider),
                Expanded(
                  child: _Summary(label: '已报销', amount: reimbursed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('全部')),
              ButtonSegment(value: 1, label: Text('待报销')),
              ButtonSegment(value: 2, label: Text('已报销')),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    '还没有需要报销的流水',
                    style: TextStyle(color: context.appSecondaryText),
                  ),
                ),
              ),
            )
          else
            for (final record in records) ...[
              _ReimbursementCard(
                transaction: record,
                accountName: accountNames[record.accountId] ?? '未知账户',
                bookName: bookNames[record.bookId] ?? '当前账本',
                onTap: () => openTransactionDetail(context, record),
                onReimburse:
                    record.reimbursementStatus == ReimbursementStatus.reimbursed
                    ? null
                    : () => _markReimbursed(record),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  double _reimbursementAmount(TransactionRecord item) =>
      item.reimbursementStatus == ReimbursementStatus.partial
      ? (item.amount - (item.reimbursementAmount ?? 0))
            .clamp(0, item.amount)
            .toDouble()
      : item.reimbursementAmount ?? item.amount;

  Future<void> _markReimbursed(TransactionRecord original) async {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    if (accounts.isEmpty) {
      _message('请先添加用于收款的账户');
      return;
    }
    final account = await showModalBottomSheet<Account>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('选择报销到账账户')),
            for (final item in accounts)
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(item.displayName),
                subtitle: Text(item.type.label),
                onTap: () => Navigator.pop(sheetContext, item),
              ),
          ],
        ),
      ),
    );
    if (account == null || !mounted) return;
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    final category = categories
        .where((item) => item.type == CategoryType.income)
        .firstOrNull;
    if (category == null) {
      _message('没有可用的收入分类');
      return;
    }
    final now = DateTime.now();
    try {
      await ref
          .read(reimbursementServiceProvider)
          .markReimbursed(
            original: original,
            account: account,
            category: category,
            occurredAt: now,
          );
      if (mounted) _message('报销回款已记账并关联原流水');
    } on Object catch (error) {
      if (mounted) _message('报销处理失败：$error');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.appSecondaryText)),
        const SizedBox(height: 4),
        MoneyText(
          amount,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ReimbursementCard extends StatelessWidget {
  const _ReimbursementCard({
    required this.transaction,
    required this.accountName,
    required this.bookName,
    required this.onTap,
    required this.onReimburse,
  });

  final TransactionRecord transaction;
  final String accountName;
  final String bookName;
  final VoidCallback onTap;
  final VoidCallback? onReimburse;

  @override
  Widget build(BuildContext context) {
    final status = switch (transaction.reimbursementStatus) {
      ReimbursementStatus.pending => '待报销',
      ReimbursementStatus.partial => '部分报销',
      ReimbursementStatus.reimbursed => '已报销',
      ReimbursementStatus.none => '',
    };
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    transaction.displayTitle,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                MoneyText(
                  -transaction.amount,
                  showSign: true,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${transaction.occurredAt.month}月${transaction.occurredAt.day}日 · ${transaction.displayCategoryLabel}',
              style: TextStyle(
                fontSize: 12,
                color: context.appSecondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '账本：$bookName · 账户：$accountName',
              style: TextStyle(
                fontSize: 12,
                color: context.appSecondaryText,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.appPrimarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appPrimary,
                    ),
                  ),
                ),
                const Spacer(),
                if (onReimburse != null)
                  TextButton(onPressed: onReimburse, child: const Text('登记回款')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
