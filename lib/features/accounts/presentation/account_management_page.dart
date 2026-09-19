import '../../../core/widgets/app_action_sheet.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/widgets/app_card.dart';
import '../data/account_repository.dart';
import 'account_forms.dart';
import '../../../app/theme/app_theme_tokens.dart';

class AccountManagementPage extends ConsumerWidget {
  const AccountManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.value ?? const <Account>[];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _PageHeader(
            title: '账户与资产',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/profile'),
            onAdd: () => _editAccount(context, ref, accounts: accounts),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('共 ${accounts.length} 个可用账户 · 长按拖动可排序'),
                TextButton(
                  onPressed: () => context.push('/profile/assets'),
                  child: const Text('查看资产、负债与资金形式'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (accountsAsync.isLoading && accounts.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (accounts.isEmpty)
            const Center(child: Text('还没有账户'))
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: accounts.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorderAccounts(context, ref, accounts, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final account = accounts[index];
                return Padding(
                  key: ValueKey(account.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    borderRadius: 18,
                    child: Row(
                      children: [
                        Icon(
                          Icons.drag_handle,
                          color: context.appSecondaryText,
                        ),
                        const SizedBox(width: 4),
                        CircleAvatar(
                          backgroundColor: Color(account.color)
                              .withValues(alpha: .14),
                          foregroundColor: Color(account.color),
                          child: Icon(_accountIcon(account.type)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.displayName,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _accountTypeLabel(account.type),
                                style: TextStyle(
                                  color: context.appSecondaryText,
                                  fontSize: 12,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${account.currency} ${MoneyFormatter.decimal(account.balance)}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppActionMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'edit') {
                              _editAccount(
                                context,
                                ref,
                                accounts: accounts,
                                account: account,
                              );
                            } else if (action == 'calibrate') {
                              showBalanceCalibration(context, account);
                            } else {
                              _archiveAccount(context, ref, account);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('编辑')),
                            PopupMenuItem(
                              value: 'calibrate',
                              child: Text('校准余额'),
                            ),
                            PopupMenuItem(value: 'archive', child: Text('归档')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _editAccount(
    BuildContext context,
    WidgetRef ref, {
    required List<Account> accounts,
    Account? account,
  }) =>
      showAccountEditor(context, account: account, sortOrder: accounts.length);

  Future<void> _archiveAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档账户'),
        content: Text(
          '归档“${account.displayName}”后不再用于新记账，历史流水和余额仍保留并计入资产总览。可从资产总览恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(accountRepositoryProvider).archive(account.id);
      } on Object catch (error) {
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('归档失败：$error')));
      }
    }
  }

  Future<void> _reorderAccounts(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = [...accounts];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    try {
      await ref
          .read(accountRepositoryProvider)
          .reorder(reordered.map((account) => account.id).toList());
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('账户排序保存失败，请稍后重试')));
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.onBack,
    required this.onAdd,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('新增'),
        ),
      ],
    );
  }
}

String _accountTypeLabel(AccountType type) => switch (type) {
  AccountType.cash => '现金',
  AccountType.wechat => '微信',
  AccountType.alipay => '支付宝',
  AccountType.debitCard => '储蓄卡',
  AccountType.creditCard => '信用卡',
  AccountType.other => '其他',
  AccountType.liability => '负债',
};

IconData _accountIcon(AccountType type) => switch (type) {
  AccountType.cash => Icons.payments_outlined,
  AccountType.wechat => Icons.chat_bubble_outline,
  AccountType.alipay => Icons.account_balance_wallet_outlined,
  AccountType.debitCard => Icons.account_balance_outlined,
  AccountType.creditCard => Icons.credit_card,
  AccountType.other => Icons.wallet_outlined,
  AccountType.liability => Icons.request_quote_outlined,
};
