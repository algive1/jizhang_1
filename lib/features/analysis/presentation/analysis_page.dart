import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/widgets/app_card.dart';

import 'package:go_router/go_router.dart';

import '../../transactions/data/transactions_repository.dart';
import 'cashflow_cards.dart';
import '../data/analysis_repository.dart';

class AnalysisPage extends ConsumerWidget {
  const AnalysisPage({super.key, this.month});
  final DateTime? month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = month == null
        ? ref.watch(analysisSnapshotProvider)
        : ref
              .watch(analysisRepositoryProvider)
              .analyze(
                period: ref.watch(analysisPeriodProvider),
                month: month,
                currency: ref.watch(analysisCurrencyProvider),
              );
    final transactions = ref.watch(transactionsProvider);
    final currencies = {
      'CNY',
      snapshot.currency,
      ...?transactions.value?.map((t) => t.currency.toUpperCase()),
    }.toList()..sort();
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _AnalysisHeader(),
                const SizedBox(height: 16),
                const Text(
                  '统计周期',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                if (month == null)
                  _PeriodSelector(selected: snapshot.period)
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text('${month!.year}年${month!.month}月'),
                      onDeleted: () => context.go('/analysis'),
                    ),
                  ),
                if (currencies.length > 1)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final currency in currencies)
                        ChoiceChip(
                          label: Text(currency),
                          selected: currency == snapshot.currency,
                          onSelected: (_) => ref
                              .read(analysisCurrencyProvider.notifier)
                              .select(currency),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (transactions.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (transactions.hasError)
                  AppCard(
                    child: Column(
                      children: [
                        const Text('收支读取失败，请重试'),
                        TextButton(
                          onPressed: () => ref.invalidate(transactionsProvider),
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  CashflowSummaryCard(snapshot: snapshot),
                  const SizedBox(height: 16),
                  CashflowTrendCard(snapshot: snapshot),
                  const SizedBox(height: 16),
                  CashflowCategoriesCard(
                    title: '支出分类',
                    items: snapshot.expenseCategories,
                    total: snapshot.totalExpense,
                    currency: snapshot.currency,
                  ),
                  const SizedBox(height: 16),
                  CashflowCategoriesCard(
                    title: '收入来源',
                    items: snapshot.incomeCategories,
                    total: snapshot.totalIncome,
                    currency: snapshot.currency,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '消费习惯',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  _OverviewCard(snapshot: snapshot),
                  const SizedBox(height: 16),
                  _InsightSection(insights: snapshot.insights),
                  const SizedBox(height: 16),
                  _SpendingHeatmap(values: snapshot.heatmap),
                  const SizedBox(height: 16),
                  _TimeSegments(
                    amounts: snapshot.segmentAmounts,
                    currency: snapshot.currency,
                  ),
                  const SizedBox(height: 16),
                  _CategoryTrends(
                    trends: snapshot.categoryTrends,
                    currency: snapshot.currency,
                  ),
                  const SizedBox(height: 16),
                  _BaselineCard(
                    baselines: snapshot.baselines,
                    currency: snapshot.currency,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisHeader extends StatelessWidget {
  const _AnalysisHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
        ),
        Expanded(
          child: Text(
            '收支分析',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.selected});

  final AnalysisPeriod selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final period in AnalysisPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(period.label),
                selected: period == selected,
                onSelected: (_) =>
                    ref.read(analysisPeriodProvider.notifier).select(period),
                selectedColor: AppColors.primarySoft,
                side: BorderSide(
                  color: period == selected
                      ? AppColors.primary
                      : AppColors.divider,
                ),
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.snapshot});

  final AnalysisSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final change = snapshot.regularChangePercent;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '日常消费',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(
            '${snapshot.currency} ${MoneyFormatter.decimal(snapshot.regularExpense)}',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.hasComparableBaseline
                ? '共 ${snapshot.transactionCount} 笔 · ${_rangeLabel(snapshot)}较上一同期${change >= 0 ? '增加' : '减少'} '
                      '${change.abs().toStringAsFixed(1)}%'
                : '共 ${snapshot.transactionCount} 笔 · ${_rangeLabel(snapshot)}上期暂无可比数据',
            style: TextStyle(
              color: change > 0 ? AppColors.warning : AppColors.textSecondary,
            ),
          ),
          if (snapshot.excludedLargeExpense > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '另有 ${snapshot.currency} ${MoneyFormatter.decimal(snapshot.excludedLargeExpense)} '
                '重大一次性/资产支出，未计入日常趋势。',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _rangeLabel(AnalysisSnapshot snapshot) {
    String date(AnalysisDateRange range) =>
        '${range.start.month}.${range.start.day}-${range.endExclusive.subtract(const Duration(days: 1)).month}.${range.endExclusive.subtract(const Duration(days: 1)).day}';
    return '${date(snapshot.range)} 对比 ${date(snapshot.previousRange)}，';
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({required this.insights});

  final List<AnalysisInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const AppCard(
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success),
            SizedBox(width: 12),
            Expanded(child: Text('当前周期没有达到提醒阈值的消费异常。')),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '洞察',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        for (final insight in insights.take(3)) ...[
          AppCard(
            padding: const EdgeInsets.all(16),
            border: Border.all(
              color: insight.severity == AnalysisInsightSeverity.important
                  ? AppColors.warning.withValues(alpha: .45)
                  : AppColors.divider,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        insight.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _SpendingHeatmap extends StatelessWidget {
  const _SpendingHeatmap({required this.values});

  final List<List<double>> values;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final maximum = values.expand((row) => row).fold<double>(0, math.max);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7×24 消费热力图',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          const Text(
            '颜色越深，日常消费金额越高',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(width: 34),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('0时'), Text('8时'), Text('16时'), Text('24时')],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (var day = 0; day < 7; day++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SizedBox(
                height: 15,
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        weekdays[day],
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          for (var hour = 0; hour < 24; hour++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: hour == 23 ? 0 : 2,
                                ),
                                child: SizedBox(
                                  height: 15,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color.lerp(
                                        AppColors.surfaceSoft,
                                        AppColors.primary,
                                        maximum == 0
                                            ? 0
                                            : (values[day][hour] / maximum)
                                                  .clamp(.06, 1),
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeSegments extends StatelessWidget {
  const _TimeSegments({required this.amounts, required this.currency});

  final String currency;

  final Map<TimeSegment, double> amounts;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '时段分布',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final segment in TimeSegment.values)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${segment.label} $currency ${MoneyFormatter.decimal(amounts[segment] ?? 0)}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTrends extends StatelessWidget {
  const _CategoryTrends({required this.trends, required this.currency});

  final String currency;

  final List<CategoryTrend> trends;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分类趋势',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (trends.isEmpty)
            const Text(
              '当前周期暂无支出',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final trend in trends.take(6)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 10, color: AppColors.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                trend.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '$currency ${MoneyFormatter.decimal(trend.currentAmount)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${trend.currentCount} 笔 · 均价 $currency ${MoneyFormatter.decimal(trend.currentAverage)} · '
                          '${trend.attribution.label}驱动',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          trend.previousAmount == 0
                              ? '上期暂无可比数据 · 本期新增'
                              : '同期 ${trend.changePercent >= 0 ? '+' : ''}${trend.changePercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color:
                                trend.previousAmount == 0 ||
                                    trend.changePercent > 0
                                ? AppColors.warning
                                : AppColors.success,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
            ],
        ],
      ),
    );
  }
}

class _BaselineCard extends StatelessWidget {
  const _BaselineCard({required this.baselines, required this.currency});

  final String currency;

  final List<BehaviorBaseline> baselines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '个人行为基线',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          const Text(
            '只依据你的本地流水计算',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final baseline in baselines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('${baseline.windowDays}天'),
                  Text(
                    '日均 $currency ${MoneyFormatter.decimal(baseline.dailyRegularSpending)}',
                  ),
                  Text(
                    '深夜 ${baseline.lateNightDailyCount.toStringAsFixed(2)} 次/天',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
