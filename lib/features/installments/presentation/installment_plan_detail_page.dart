import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/installment_plan.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/transaction_actions.dart';
import '../data/installment_plan_repository.dart';
import '../../../app/theme/app_theme_tokens.dart';

class InstallmentPlanDetailPage extends ConsumerWidget {
  const InstallmentPlanDetailPage({required this.planId, super.key});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(installmentPlanProvider(planId));
    final plan = state.value;
    if (plan == null) {
      return SafeArea(
        child: Center(
          child: state.isLoading
              ? const CircularProgressIndicator()
              : Text(state.hasError ? '读取分期失败：${state.error}' : '分期计划不存在'),
        ),
      );
    }
    final transactions =
        ref.watch(transactionsProvider).value ?? const <TransactionRecord>[];
    final original = transactions
        .where((item) => item.id == plan.originalTransactionId)
        .firstOrNull;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/profile/installments'),
                icon: Icon(Icons.arrow_back),
                tooltip: '返回分期列表',
              ),
              Expanded(
                child: Text(
                  '分期详情',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          AppCard(
            color: context.appPrimarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.appPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _MetricRow(label: '总金额', amount: plan.totalAmount),
                _MetricRow(label: '每期还款', amount: plan.monthlyPayment),
                _MetricRow(label: '剩余本金', amount: plan.remainingPrincipal),
                const SizedBox(height: 8),
                Text(
                  '第 ${plan.currentPeriod} / ${plan.totalPeriods} 期 · 每月 ${plan.dueDay} 日',
                  style: TextStyle(color: context.appSecondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (original != null)
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(original.displayTitle),
                subtitle: Text('原始消费 · ${original.amount.toStringAsFixed(2)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openTransactionDetail(context, original),
                onLongPress: () =>
                    showTransactionActions(context, ref, original),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: plan.status == InstallmentPlanStatus.active
                ? () => _recordRepayment(context, ref, plan)
                : null,
            icon: Icon(Icons.payments_outlined),
            label: Text(
              plan.status == InstallmentPlanStatus.active ? '登记本期还款' : '分期已完成',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '登记后会生成一笔“还款”流水：还款账户减少、信用卡账户增加，消费统计保持不变。',
            style: TextStyle(fontSize: 12, color: context.appSecondaryText),
          ),
        ],
      ),
    );
  }

  Future<void> _recordRepayment(
    BuildContext context,
    WidgetRef ref,
    InstallmentPlan plan,
  ) async {
    try {
      await ref
          .read(installmentPlanRepositoryProvider)
          .recordRepayment(plan.id);
      ref.invalidate(installmentPlanProvider(plan.id));
      ref.invalidate(installmentPlansProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('本期还款已登记')));
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('登记失败：$error')));
    }
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: context.appSecondaryText),
          ),
        ),
        MoneyText(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
