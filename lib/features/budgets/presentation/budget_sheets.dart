import 'package:flutter/material.dart';


import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../application/budget_weekly_review_service.dart';
import '../data/budget_preferences_repository.dart';
import '../domain/budget_period.dart';
import 'budget_visuals.dart';

Future<DateTime?> showBudgetMonthPicker(
  BuildContext context,
  DateTime initial, {
  bool yearOnly = false,
}) {
  var year = initial.year;
  return showDialog<DateTime>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, setYear) => AlertDialog(
        title: Text(yearOnly ? '选择年份' : '选择月份'),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '上一年',
                    onPressed: year <= 1900
                        ? null
                        : () => setYear(() => year--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '$year 年',
                      textAlign: TextAlign.center,
                      style: budgetText(context, 18, weight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: '下一年',
                    onPressed: year >= DateTime.now().year + 10
                        ? null
                        : () => setYear(() => year++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              if (!yearOnly)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var month = 1; month <= 12; month++)
                      SizedBox(
                        width: 70,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pop(dialog, DateTime(year, month)),
                          child: Text('$month 月'),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('取消'),
          ),
          if (yearOnly)
            FilledButton(
              onPressed: () => Navigator.pop(dialog, DateTime(year)),
              child: const Text('确认'),
            ),
        ],
      ),
    ),
  );
}

Future<void> showBudgetSettings(
  BuildContext page, {
  required void Function(BudgetPreference, bool) onChanged,
}) => showModalBottomSheet<void>(
  context: page,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: Consumer(
      builder: (context, ref, _) {
        final preferences = ref.watch(budgetPreferencesProvider);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '提醒与策略',
                style: budgetText(context, 18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (preferences.hasValue && !preferences.isLoading) ...[
                for (final preference in BudgetPreference.values)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.value!.enabled(preference),
                    activeThumbColor: budgetGreen,
                    onChanged: (value) => onChanged(preference, value),
                    title: Text(switch (preference) {
                      BudgetPreference.overspend => '超支提醒',
                      BudgetPreference.weeklyReview => '每周复盘',
                      BudgetPreference.smartAdvice => '智能建议',
                    }),
                    subtitle: Text(switch (preference) {
                      BudgetPreference.overspend => '使用达到 80% 或超过预算时发送通知',
                      BudgetPreference.weeklyReview => '汇总上一完整周的收支，保存最近 12 周报告',
                      BudgetPreference.smartAdvice => '根据当前账本的消费结构提供预算建议',
                    }),
                  ),
              ] else if (preferences.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(budgetPreferencesProvider),
                  child: const Text('设置读取失败，点击重试'),
                )
              else
                const Center(child: CircularProgressIndicator()),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  showBudgetWeeklyReviews(page);
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('查看每周复盘'),
              ),
              const Divider(),
              Text(
                '预算计算',
                style: budgetText(context, 14, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '全年预算汇总各月已设置的额度；自定义范围按覆盖天数折算各月额度。'
                '未设置预算的月份不会自动套用其他月份的额度。\n\n'
                '目标预留计入预算使用率并从剩余预算中扣除。日均为期间预算除以期间天数。'
                '系统通知权限关闭时，每周报告仍会保存，可在此查看。',
                style: budgetText(context, 12, color: budgetMuted),
              ),
            ],
          ),
        );
      },
    ),
  ),
);

Future<void> showBudgetWeeklyReviews(
  BuildContext page,
) => showModalBottomSheet<void>(
  context: page,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(sheet).height * .7,
      child: Consumer(
        builder: (context, ref, _) => Column(
          children: [
            Text(
              '每周复盘',
              style: budgetText(context, 18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ref
                  .watch(budgetWeeklyReviewsProvider)
                  .when(
                    data: (reports) => reports.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '暂时没有周报告。开启每周复盘后，有收支记录的上一完整周会自动生成汇总。',
                                textAlign: TextAlign.center,
                                style: budgetText(
                                  context,
                                  13,
                                  color: budgetMuted,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: reports.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final report = reports[i];
                              return BudgetSurface(
                                frosted: false,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${report.start.year}年 ${report.title}',
                                      style: budgetText(
                                        context,
                                        14,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '支出 ¥${MoneyFormatter.decimal(report.spent)}  ·  收入 ¥${MoneyFormatter.decimal(report.income)}',
                                      style: budgetText(context, 13),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '共 ${report.count} 笔消费 · ${report.topCategory} ¥${MoneyFormatter.decimal(report.topAmount)}',
                                      style: budgetText(
                                        context,
                                        12,
                                        color: budgetMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: TextButton(
                        onPressed: () =>
                            ref.invalidate(budgetWeeklyReviewsProvider),
                        child: const Text('报告读取失败，点击重试'),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> showBudgetAdviceDetails(
  BuildContext context,
  BudgetPeriodOverview data,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('小冰建议', style: budgetText(context, 18, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            data.period.description,
            style: budgetText(context, 12, color: budgetMuted),
          ),
          const SizedBox(height: 16),
          Text(
            '期间支出 ¥${MoneyFormatter.decimal(data.spent)}',
            style: budgetText(context, 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (data.overview.total case final total?) ...[
            Text(
              '剩余预算 ¥${MoneyFormatter.decimal(total.remaining)}\n目标预留 ¥${MoneyFormatter.decimal(total.goalReservation)}\n'
              '日均可用 ¥${MoneyFormatter.decimal(total.dailyAvailable)}',
              style: budgetText(context, 13),
            ),
            const SizedBox(height: 16),
          ],
          for (final row in data.overview.categories.where((r) => r.used > 0))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.category?.name ?? '已隐藏分类',
                      style: budgetText(context, 13),
                    ),
                  ),
                  Text(
                    '¥${MoneyFormatter.decimal(row.used)} · ${data.spent == 0 ? 0 : (row.used / data.spent * 100).round()}%',
                    style: budgetText(context, 13),
                  ),
                ],
              ),
            ),
          Text(
            data.leadingCategory == null
                ? '继续记录日常收支，积累消费记录后再观察分类变化。'
                : '${data.leadingCategory!.category?.name ?? '主要分类'}是当前已设预算分类中支出最多的一项。'
                      '可从减少非必要消费、检查大额支出和调整分类预算开始。',
            style: budgetText(context, 13, color: budgetMuted),
          ),
        ],
      ),
    ),
  ),
);
