import 'dart:async';

import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_action_sheet.dart';
import '../../../core/widgets/app_form.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/budget.dart';
import '../../../core/models/category.dart';
import '../../../core/widgets/app_card.dart';
import '../../categories/data/category_repository.dart';
import '../application/budget_alert_notification_service.dart';
import '../data/budget_repository.dart';

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final overview = ref.watch(budgetOverviewProvider);
    final total = overview.total;
    final categories =
        (ref.watch(categoriesProvider).value ?? const <Category>[])
            .where(
              (item) =>
                  item.type == CategoryType.expense && item.parentId == null,
            )
            .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/profile'),
                icon: Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '预算管理',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () =>
                    _setBudget(context, ref, existing: total?.budget),
                icon: Icon(Icons.edit_outlined),
                label: Text(total == null ? '设置' : '调整'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (total == null)
            AppCard(
              child: Column(
                children: [
                  Icon(
                    Icons.savings_outlined,
                    color: context.appPrimary,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  Text('设置本月预算后，即可计算今日安心可花'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _setBudget(context, ref),
                    child: const Text('设置月度预算'),
                  ),
                ],
              ),
            )
          else
            _TotalBudgetCard(progress: total),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('分类预算', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (categories.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _setBudget(
                    context,
                    ref,
                    selectableCategories: categories,
                  ),
                  icon: Icon(Icons.add),
                  label: Text('添加'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (overview.categories.isEmpty)
            AppCard(
              child: Text(
                '还没有分类预算，可以先从餐饮、交通等高频分类开始。'
                style: TextStyle(color: context.appSecondaryText),
              ),
            )
          else
            ...overview.categories.map(
              (progress) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryBudgetCard(
                  progress: progress,
                  onEdit: () => _setBudget(
                    context,
                    ref,
                    existing: progress.budget,
                    selectableCategories: categories,
                    categoryName: progress.category?.name,
                  ),
                  onRemove: () async {
                    if (await AppConfirmDialog.show(
                          context,
                          title: '移除预算？',
                          message: '仅移除预算设置，已有流水保留。',
                        ) &&
                        context.mounted) {
                      await ref
                          .read(budgetRepositoryProvider)
                          .removeBudget(progress.budget.id);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setBudget(
    BuildContext context,
    WidgetRef ref, {
    Budget? existing,
    List<Category> selectableCategories = const [],
    String? categoryName,
  }) async {
    final isCategoryBudget =
        existing?.categoryId != null || selectableCategories.isNotEmpty;
    final monthKey = budgetMonthKey(DateTime.now());
    final repository = ref.read(budgetRepositoryProvider);
    final result = await showDialog<(double, String?)>(
      context: context,
      builder: (_) => _BudgetDialog(
        existing: existing,
        selectableCategories: selectableCategories,
        categoryName: categoryName,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    try {
      await repository.setBudget(
        monthKey: monthKey,
        amount: result.$1,
        categoryId: isCategoryBudget ? result.$2 : null,
      );
      unawaited(
        ref.read(budgetAlertNotificationServiceProvider).requestPermission(),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('预算保存失败：$error')));
      }
    }
  }
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({
    this.existing,
    required this.selectableCategories,
    this.categoryName,
  });

  final Budget? existing;
  final List<Category> selectableCategories;
  final String? categoryName;

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
    final categoryId = widget.existing?.categoryId;
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
              decoration: const InputDecoration(labelText: '分类'),
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
          final amount = double.tryParse(_amountController.text);
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

class _TotalBudgetCard extends StatelessWidget {
  const _TotalBudgetCard({required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final remaining = progress.remaining;
    return AppCard(
      color: const Color(0xFFF2F5E4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本月还剩',
                style: TextStyle(color: context.appSecondaryText),
              ),
              const Spacer(),
              _StatusBadge(status: progress.status),
            ],
          ),
          const SizedBox(height: 7),
          FittedBox(
            child: Text(
              '${remaining < 0 ? '-' : ''}¥${MoneyFormatter.whole(remaining.abs())}',
              style: TextStyle(
                color: remaining < 0
                    ? AppColors.warning
                    : context.appPrimary,
                fontSize: 38,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.percentage.clamp(0, 1),
            minHeight: 9,
            borderRadius: BorderRadius.circular(8),
            color: progress.status == BudgetAlertStatus.exceeded
                ? AppColors.warning
                : context.appPrimary,
            backgroundColor: context.appPrimarySoft,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BudgetStat(
                  label: '已支出',
                  value: '¥${MoneyFormatter.whole(progress.used)}',
                ),
              ),
              Expanded(
                child: _BudgetStat(
                  label: '本月预算',
                  value: '¥${MoneyFormatter.whole(progress.budget.amount)}',
                ),
              ),
              Expanded(
                child: _BudgetStat(
                  label: '日均可用',
                  value: '¥${MoneyFormatter.whole(progress.dailyAvailable)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '本月还剩 ${progress.remainingDays} 天 · 目标预留 ¥${MoneyFormatter.decimal(progress.goalReservation)}',
            style: TextStyle(
              color: context.appSecondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  const _CategoryBudgetCard({
    required this.progress,
    required this.onEdit,
    required this.onRemove,
  });

  final BudgetProgress progress;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppContextMenu(
      onOpen: () async {
        final value = await AppActionSheet.show<String>(
          context,
          title: progress.category?.name ?? '预算',
          items: const [
            PopupMenuItem(value: 'edit', child: Text('调整')),
            PopupMenuItem(value: 'remove', child: Text('移除')),
          ],
        );
        if (value != null && context.mounted) {
          value == 'edit' ? onEdit() : onRemove();
        }
      },
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        borderRadius: 18,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: context.appPrimarySoft,
              child: Icon(
                Icons.category_outlined,
                color: context.appPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          progress.category?.name ?? '已隐藏分类',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      _StatusBadge(status: progress.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress.percentage.clamp(0, 1),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                    backgroundColor: context.appPrimarySoft,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '已用 ¥${MoneyFormatter.whole(progress.used)}  ·  '
                    '剩余 ¥${MoneyFormatter.whole(progress.remaining)}',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AppActionMenuButton<String>(
              onSelected: (value) => value == 'edit' ? onEdit() : onRemove(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('调整')),
                PopupMenuItem(value: 'remove', child: Text('移除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  const _BudgetStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.appSecondaryText, fontSize: 11),
        ),
        const SizedBox(height: 2),
        FittedBox(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BudgetAlertStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BudgetAlertStatus.normal => ('正常', context.appPrimary),
      BudgetAlertStatus.nearLimit => ('接近预算', const Color(0xFFD58A2C)),
      BudgetAlertStatus.exceeded => ('已超预算', AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
