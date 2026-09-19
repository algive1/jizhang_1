import '../../../core/widgets/app_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/account.dart';
import '../../../core/models/installment_plan.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/utils/entity_id.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/transaction_actions.dart';
import '../data/installment_plan_repository.dart';
import '../../../app/theme/app_theme_tokens.dart';

class InstallmentPlansPage extends ConsumerWidget {
  const InstallmentPlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans =
        ref.watch(installmentPlansProvider).value ?? const <InstallmentPlan>[];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回首页',
              ),
              Expanded(
                child: Text(
                  '信用卡分期',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                onPressed: plans.isEmpty
                    ? null
                    : () => _processDueRepayments(context, ref),
                icon: Icon(Icons.play_circle_outline),
                tooltip: '执行到期还款',
              ),
              IconButton(
                onPressed: () => _openCreate(context, ref),
                icon: Icon(Icons.add_circle_outline),
                tooltip: '新增分期计划',
              ),
            ],
          ),
          AppCard(
            color: context.appPrimarySoft,
            child: Text(
              '原始消费只记账一次；每期还款只改变现金与负债，不会重复计入消费。',
              style: TextStyle(color: context.appPrimary),
            ),
          ),
          const SizedBox(height: 14),
          if (plans.isEmpty)
            AppCard(
              child: Text(
                '还没有分期计划',
                style: TextStyle(color: context.appSecondaryText),
              ),
            )
          else
            for (final plan in plans) ...[
              _PlanCard(
                plan: plan,
                onOpen: () => context.push('/profile/installments/${plan.id}'),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _processDueRepayments(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final count = await ref
          .read(installmentPlanRepositoryProvider)
          .processDueRepayments();
      ref.invalidate(installmentPlansProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(count == 0 ? '当前没有到期还款' : '已登记 $count 期到期还款')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('执行失败：$error')));
    }
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final transactions =
        ref.read(transactionsProvider).value ?? const <TransactionRecord>[];
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final expenses = transactions.where((item) => item.isExpense).toList();
    if (expenses.isEmpty || accounts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先记录一笔消费并添加账户')));
      return;
    }
    final created = await showDialog<InstallmentPlan>(
      context: context,
      builder: (_) => _InstallmentDialog(
        bookId: ref.read(activeBookIdProvider),
        expenses: expenses,
        accounts: accounts,
      ),
    );
    if (created == null || !context.mounted) return;
    try {
      await ref.read(installmentPlanRepositoryProvider).create(created);
      ref.invalidate(installmentPlansProvider);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan, required this.onOpen});
  final InstallmentPlan plan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final original =
        (ref.watch(transactionsProvider).value ?? const <TransactionRecord>[])
            .where((item) => item.id == plan.originalTransactionId)
            .firstOrNull;
    return GestureDetector(
      onTap: onOpen,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.credit_score_outlined,
                  color: context.appPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.name,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                MoneyText(
                  plan.monthlyPayment,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '第 ${plan.currentPeriod} / ${plan.totalPeriods} 期 · 每月 ${plan.dueDay} 日还款',
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '剩余本金',
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: 12,
              ),
            ),
            MoneyText(
              plan.remainingPrincipal,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.appPrimary,
              ),
            ),
            if (original != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => openTransactionDetail(context, original),
                  child: const Text('查看原始消费'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InstallmentDialog extends StatefulWidget {
  const _InstallmentDialog({
    required this.bookId,
    required this.expenses,
    required this.accounts,
  });
  final String bookId;
  final List<TransactionRecord> expenses;
  final List<Account> accounts;
  @override
  State<_InstallmentDialog> createState() => _InstallmentDialogState();
}

class _InstallmentDialogState extends State<_InstallmentDialog> {
  late TransactionRecord _original = widget.expenses.first;
  final _periods = TextEditingController(text: '12');
  final _fee = TextEditingController(text: '0');
  final _dueDay = TextEditingController(text: '15');
  late String? _creditAccountId = _original.accountId;
  late String? _repaymentAccountId = widget.accounts
      .where((account) => account.id != _original.accountId)
      .map((account) => account.id)
      .firstOrNull;

  @override
  void dispose() {
    _periods.dispose();
    _fee.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新增分期计划'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSelect<String>(
            initialValue: _original.id,
            decoration: const InputDecoration(labelText: '原始消费'),
            items: widget.expenses
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      '${item.displayTitle} · ¥${item.amount.toStringAsFixed(2)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _original = widget.expenses.firstWhere(
                (item) => item.id == value,
              );
              _creditAccountId = _original.accountId;
              if (_repaymentAccountId == _creditAccountId) {
                _repaymentAccountId = widget.accounts
                    .where((account) => account.id != _creditAccountId)
                    .map((account) => account.id)
                    .firstOrNull;
              }
            }),
          ),
          AppSelect<String>(
            initialValue: _creditAccountId,
            decoration: const InputDecoration(labelText: '信用卡账户'),
            items: widget.accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account.id,
                    child: Text(account.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _creditAccountId = value),
          ),
          AppSelect<String>(
            initialValue: _repaymentAccountId,
            decoration: const InputDecoration(labelText: '还款账户'),
            items: widget.accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account.id,
                    child: Text(account.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _repaymentAccountId = value),
          ),
          TextField(
            controller: _periods,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '总期数'),
          ),
          TextField(
            controller: _fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '每期手续费'),
          ),
          TextField(
            controller: _dueDay,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '还款日（1-31）'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );

  void _submit() {
    final periods = int.tryParse(_periods.text.trim());
    final fee = double.tryParse(_fee.text.trim());
    final dueDay = int.tryParse(_dueDay.text.trim());
    if (periods == null ||
        periods < 1 ||
        fee == null ||
        fee < 0 ||
        dueDay == null ||
        _creditAccountId == null ||
        _repaymentAccountId == null ||
        _creditAccountId == _repaymentAccountId)
      return;
    final now = DateTime.now();
    final principal = _original.amount / periods;
    Navigator.pop(
      context,
      InstallmentPlan(
        id: 'installment-${newEntityId()}',
        bookId: widget.bookId,
        name: '${_original.displayTitle} 分期',
        originalTransactionId: _original.id,
        totalAmount: _original.amount,
        totalPeriods: periods,
        currentPeriod: 0,
        principalPerPeriod: principal,
        feePerPeriod: fee,
        startDate: now,
        dueDay: dueDay,
        creditAccountId: _creditAccountId!,
        repaymentAccountId: _repaymentAccountId!,
        remainingPrincipal: _original.amount,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
