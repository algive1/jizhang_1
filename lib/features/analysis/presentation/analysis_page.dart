import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/widgets/app_card.dart';

import 'package:go_router/go_router.dart';

import '../../transactions/data/transactions_repository.dart';
import 'cashflow_cards.dart';
import '../application/analysis_report_export_service.dart';
import '../data/analysis_repository.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key, this.month});
  final DateTime? month;

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  final _reportKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.month == null
        ? ref.watch(analysisSnapshotProvider)
        : ref
              .watch(analysisRepositoryProvider)
              .analyze(
                period: ref.watch(analysisPeriodProvider),
                month: widget.month,
                currency: ref.watch(analysisCurrencyProvider),
              );
    final transactions = ref.watch(analysisTransactionsProvider);
    final scope = ref.watch(analysisScopeProvider);
    final currencies = {
      'CNY',
      snapshot.currency,
      ...?transactions.value?.map((t) => t.currency.toUpperCase()),
    }.toList()
      ..sort();
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _AnalysisHeader(
                  sharing: _sharing,
                  onAnnualReport: () => context.push('/analysis/annual-report'),
                  onShareImage: () => _share(context, 'image', snapshot, scope),
                  onSharePdf: () => _share(context, 'pdf', snapshot, scope),
                ),
                const SizedBox(height: 16),
                Text(
                  '统计范围',
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                _AnalysisScopeSelector(selected: scope),
                const SizedBox(height: 14),
                Text(
                  '统计周期',
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                if (widget.month == null)
                  _PeriodSelector(selected: snapshot.period)
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text(
                        '${widget.month!.year}年${widget.month!.month}月',
                      ),
                      onDeleted: () => context.go('/analysis'),
                    ),
                  ),
                if (currencies.length > 1) ...[
                  const SizedBox(height: 8),
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
                ],
                const SizedBox(height: 16),
                if (transactions.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (transactions.hasError)
                  AppCard(
                    child: Column(
                      children: [
                        const Text('收支读取失败，请重试'),
                        TextButton(
                          onPressed: () {
                            if (scope == AnalysisScope.allBooks) {
                              ref.invalidate(allTransactionsProvider);
                            } else {
                              ref.invalidate(transactionsProvider);
                            }
                          },
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  RepaintBoundary(
                    key: _reportKey,
                    child: _ExportReportCard(
                      snapshot: snapshot,
                      scopeLabel: scope.label,
                    ),
                  ),
                  const SizedBox(height: 16),
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

  Future<void> _share(
    BuildContext context,
    String format,
    AnalysisSnapshot snapshot,
    AnalysisScope scope,
  ) async {
    if (_sharing || _reportKey.currentContext == null) return;
    setState(() => _sharing = true);
    try {
      final service = ref.read(analysisReportExportServiceProvider);
      final start = snapshot.range.start;
      final end = snapshot.range.endExclusive.subtract(const Duration(days: 1));
      final name =
          '好好记账-${start.year}${start.month.toString().padLeft(2, '0')}'
          '${start.day.toString().padLeft(2, '0')}-'
          '${end.year}${end.month.toString().padLeft(2, '0')}'
          '${end.day.toString().padLeft(2, '0')}';
      if (format == 'pdf') {
        await service.sharePdf(
          context,
          _reportKey,
          fileName: name,
          text: '${scope.label} · ${snapshot.currency} 收支报告',
        );
      } else {
        await service.shareImage(
          context,
          _reportKey,
          fileName: name,
          text: '${scope.label} · ${snapshot.currency} 收支报告',
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('报表分享失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

class _AnalysisHeader extends StatelessWidget {
  const _AnalysisHeader({
    required this.sharing,
    required this.onAnnualReport,
    required this.onShareImage,
    required this.onSharePdf,
  });

  final bool sharing;
  final VoidCallback onAnnualReport;
  final VoidCallback onShareImage;
  final VoidCallback onSharePdf;

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
        IconButton(
          onPressed: onAnnualReport,
          tooltip: '年度报告',
          icon: const Icon(Icons.health_and_safety_outlined),
        ),
        PopupMenuButton<String>(
          enabled: !sharing,
          tooltip: '分享报表',
          icon: sharing
              ? const SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_outlined),
          onSelected: (value) =>
              value == 'pdf' ? onSharePdf() : onShareImage(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'image', child: Text('分享图片')),
            PopupMenuItem(value: 'pdf', child: Text('分享 PDF')),
          ],
        ),
      ],
    );
  }
}

class _AnalysisScopeSelector extends ConsumerWidget {
  const _AnalysisScopeSelector({required this.selected});

  final AnalysisScope selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      children: [
        for (final scope in AnalysisScope.values)
          ChoiceChip(
            label: Text(scope.label),
            selected: scope == selected,
            showCheckmark: false,
            selectedColor: context.appPrimarySoft,
            onSelected: (_) =>
                ref.read(analysisScopeProvider.notifier).select(scope),
          ),
      ],
    );
  }
}

class _ExportReportCard extends StatelessWidget {
  const _ExportReportCard({
    required this.snapshot,
    required this.scopeLabel,
  });

  final AnalysisSnapshot snapshot;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    final end = snapshot.range.endExclusive.subtract(const Duration(days: 1));
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: AppCard(
        color: context.appPrimarySoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_graph_outlined,
                  color: context.appPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '可分享报表摘要',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '$scopeLabel · ${snapshot.currency} · '
              '${snapshot.range.start.year}/${snapshot.range.start.month}/${snapshot.range.start.day}'
              '—${end.year}/${end.month}/${end.day}',
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 22,
              runSpacing: 12,
              children: [
                _ReportMetric(
                  label: '收入',
                  value: '¥${MoneyFormatter.decimal(snapshot.totalIncome)}',
                ),
                _ReportMetric(
                  label: '支出',
                  value: '¥${MoneyFormatter.decimal(snapshot.totalExpense)}',
                ),
                _ReportMetric(
                  label: '净现金流',
                  value:
                      '${snapshot.netCashflow < 0 ? '-' : '+'}¥${MoneyFormatter.decimal(snapshot.netCashflow.abs())}',
                ),
                _ReportMetric(
                  label: '收支笔数',
                  value: '${snapshot.incomeCount + snapshot.expenseCount} 笔',
                ),
              ],
            ),
            if (snapshot.expenseCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                '主要支出',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              for (final item in snapshot.expenseCategories.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.name)),
                      Text(
                        '¥${MoneyFormatter.decimal(item.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
            if (snapshot.insights.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                '值得关注',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (final insight in snapshot.insights.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${insight.description}',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 128,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.appSecondaryText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
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
                selectedColor: context.appPrimarySoft,
                side: BorderSide(
                  color: period == selected
                      ? context.appPrimary
                      : context.appDivider,
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
          Text(
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
              color: change > 0 ? AppColors.warning : context.appSecondaryText,
            ),
          ),
          if (snapshot.excludedLargeExpense > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appSurfaceSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '另有 ${snapshot.currency} ${MoneyFormatter.decimal(snapshot.excludedLargeExpense)} '
                '重大一次性/资产支出，未计入日常趋势。',
                style: TextStyle(color: context.appSecondaryText),
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
        Text(
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
                  : context.appDivider,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: context.appPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        insight.description,
                        style: TextStyle(
                          color: context.appSecondaryText,
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
          Text(
            '7×24 消费热力图',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            '颜色越深，日常消费金额越高',
            style: TextStyle(color: context.appSecondaryText),
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
                        style: TextStyle(
                          color: context.appSecondaryText,
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
                                        context.appSurfaceSoft,
                                        context.appPrimary,
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
          Text(
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
                    color: context.appSurfaceSoft,
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
          Text(
            '分类趋势',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (trends.isEmpty)
            Text(
              '当前周期暂无支出',
              style: TextStyle(color: context.appSecondaryText),
            )
          else
            for (final trend in trends.take(6)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 10, color: context.appPrimary),
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
                                style: TextStyle(
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
                          style: TextStyle(
                            color: context.appSecondaryText,
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
          Text(
            '个人行为基线',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            '只依据你的本地流水计算',
            style: TextStyle(color: context.appSecondaryText),
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
                    style: TextStyle(
                      color: context.appSecondaryText,
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
