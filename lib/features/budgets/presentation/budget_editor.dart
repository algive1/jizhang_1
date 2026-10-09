import 'dart:async';

import '../../../core/widgets/app_form.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/budget.dart';
import '../../../core/models/category.dart';

import '../../categories/data/category_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../insights/data/insight_preferences_repository.dart';
import '../../insights/domain/budget_recommendation_service.dart';
import '../../insights/domain/insight_models.dart';
import '../application/budget_alert_notification_service.dart';
import '../data/budget_repository.dart';
import '../data/budget_preferences_repository.dart';
import '../../books/data/book_repository.dart';

import '../../../core/models/transaction_record.dart';

Future<void> showBudgetEditor(
  BuildContext context,
  WidgetRef ref, {
  required DateTime month,
  String? categoryId,
  bool categoryBudget = false,
}) async {
  final bookId = ref.read(activeBookIdProvider);
  final repository = ref.read(budgetRepositoryProvider);
  final transactionsRepository = ref.read(transactionRepositoryProvider);
  try {
    final budgets = await repository.getMonth(budgetMonthKey(month));
    final existing = categoryBudget && categoryId == null
        ? null
        : budgets.where((b) => b.categoryId == categoryId).firstOrNull;
    final allCategories = await ref.read(allCategoriesProvider.future);
    final categories = allCategories
        .where(
          (c) =>
              !c.isArchived &&
              c.type == CategoryType.expense &&
              c.parentId == null,
        )
        .toList();
    if (!context.mounted) return;
    if (ref.read(activeBookIdProvider) != bookId) return;
    final isCategory = categoryBudget || categoryId != null;
    if (isCategory && existing == null && categories.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先添加支出分类')));
      return;
    }
    final smart = (await ref.read(budgetPreferencesProvider.future))
        .smartAdvice;
    final transactions = smart
        ? await transactionsRepository.getRange(
            start: DateTime(month.year, month.month - 3),
            endExclusive: DateTime(month.year, month.month),
          )
        : <TransactionRecord>[];
    final preferences =
        ref.read(insightPreferencesProvider).value ??
        const InsightPreferences();
    const service = BudgetRecommendationService();
    final totalRecommendation = smart && !isCategory
        ? service.recommendTotal(
            transactions: transactions,
            preferences: preferences,
          )
        : null;
    final categoryRecommendations = <String, BudgetRecommendation>{};
    if (smart && isCategory) {
      for (final category in categories) {
        final value = service.recommendCategory(
          transactions: transactions,
          categories: allCategories,
          categoryId: category.id,
          preferences: preferences,
        );
        if (value != null) categoryRecommendations[category.id] = value;
      }
    }
    if (!context.mounted || ref.read(activeBookIdProvider) != bookId) return;
    final result = await showDialog<(double, String?)>(
      context: context,
      builder: (_) => _BudgetDialog(
        existing: existing,
        selectableCategories: isCategory ? categories : [],
        categoryName: allCategories
            .where((c) => c.id == categoryId)
            .firstOrNull
            ?.name,
        initialCategoryId: categoryId,
        totalRecommendation: totalRecommendation,
        categoryRecommendations: categoryRecommendations,
      ),
    );
    if (result == null || !context.mounted) return;
    if (ref.read(activeBookIdProvider) != bookId) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('账本已切换，请重新编辑预算')));
      return;
    }
    await repository.setBudget(
      monthKey: budgetMonthKey(month),
      amount: result.$1,
      categoryId: isCategory ? result.$2 : null,
    );
    if (ref.read(budgetPreferencesProvider).value?.overspend ?? true) {
      unawaited(
        ref.read(budgetAlertNotificationServiceProvider).requestPermission(),
      );
    }
  } catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('预算保存失败：$error')));
  }
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({
    this.existing,
    required this.selectableCategories,
    this.categoryName,
    this.initialCategoryId,
    this.totalRecommendation,
    this.categoryRecommendations = const {},
  });

  final Budget? existing;
  final List<Category> selectableCategories;
  final String? categoryName;
  final String? initialCategoryId;
  final BudgetRecommendation? totalRecommendation;
  final Map<String, BudgetRecommendation> categoryRecommendations;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.existing?.amount.toStringAsFixed(2),
  );
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    final categoryId = widget.existing?.categoryId ?? widget.initialCategoryId;
    _categoryId = categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing?.categoryId != null ||
              widget.selectableCategories.isNotEmpty
          ? '分类预算'
          : '月度总预算',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.selectableCategories.isNotEmpty ||
            widget.existing?.categoryId != null) ...[
          if (widget.existing == null ||
              widget.selectableCategories.any(
                (category) => category.id == _categoryId,
              ))
            AppSelect<String>(
              initialValue: _categoryId,
              decoration: appFieldDecoration('分类'),
              items: widget.selectableCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: widget.existing == null
                  ? (value) => setState(() => _categoryId = value)
                  : null,
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.categoryName ?? '已归档分类'),
            ),
          const SizedBox(height: 12),
        ],
        if ((widget.totalRecommendation ??
                widget.categoryRecommendations[_categoryId]) !=
            null) ...[
          _BudgetRecommendationHint(
            recommendation:
                widget.totalRecommendation ??
                widget.categoryRecommendations[_categoryId]!,
            onUse: (value) {
              _amountController.text = value.toStringAsFixed(0);
              _amountController.selection = TextSelection.collapsed(
                offset: _amountController.text.length,
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '预算金额',
            prefixText: '¥ ',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final amount = MoneyFormatter.parseInput(_amountController.text);
          if (amount == null || !amount.isFinite || amount <= 0) return;
          if (widget.selectableCategories.isNotEmpty && _categoryId == null) {
            return;
          }
          Navigator.pop(context, (amount, _categoryId));
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _BudgetRecommendationHint extends StatelessWidget {
  const _BudgetRecommendationHint({
    required this.recommendation,
    required this.onUse,
  });

  final BudgetRecommendation recommendation;
  final ValueChanged<double> onUse;

  @override
  Widget build(BuildContext context) {
    Widget choice(String label, double value) => ActionChip(
      label: Text('$label ¥${value.toStringAsFixed(0)}'),
      onPressed: () => onUse(value),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appPrimarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '建议预算 ¥${recommendation.recommended.toStringAsFixed(0)}',
            style: TextStyle(
              color: context.appPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recommendation.reason,
            style: TextStyle(
              color: context.appSecondaryText,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              choice('保持', recommendation.maintain),
              choice('适度控制', recommendation.moderateControl),
              choice('积极节省', recommendation.activeSaving),
            ],
          ),
        ],
      ),
    );
  }
}
