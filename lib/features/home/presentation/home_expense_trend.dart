import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/widgets/cashflow_trend_chart.dart';
import '../../../core/widgets/sliding_segmented_control.dart';
import '../../analysis/data/analysis_repository.dart';
import 'home_cards.dart';
import '../../../app/theme/app_theme_tokens.dart';

class HomeExpenseTrend extends ConsumerStatefulWidget {
  const HomeExpenseTrend({super.key, this.amountHidden = false});
  final bool amountHidden;
  @override
  ConsumerState<HomeExpenseTrend> createState() => _HomeExpenseTrendState();
}

class _HomeExpenseTrendState extends ConsumerState<HomeExpenseTrend> {
  AnalysisPeriod _period = AnalysisPeriod.currentMonth;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref
        .watch(analysisRepositoryProvider)
        .analyze(period: _period);
    final points = _period == AnalysisPeriod.currentYear
        ? _monthlyPoints(snapshot.cashflowTrend)
        : snapshot.cashflowTrend;
    final selected = (_selected ?? points.length - 1)
        .clamp(0, math.max(0, points.length - 1))
        .toInt();
    final point = points.isEmpty ? null : points[selected];
    final year = _period == AnalysisPeriod.currentYear;
    String dateLabel(CashflowPoint p) => year
        ? '${p.date.year}年${p.date.month}月'
        : '${p.date.month}月${p.date.day}日';
    final average = snapshot.range.dayCount <= 0
        ? 0.0
        : snapshot.totalExpense / snapshot.range.dayCount;
    return HomeSurface(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            width: 70,
            height: 70,
            child: IgnorePointer(
              child: Opacity(
                opacity: .38,
                child: Image.asset(AppAssets.homeLeaves, fit: BoxFit.contain),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '支出趋势',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.appPrimaryText,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 132,
                    child: SlidingSegmentedControl<AnalysisPeriod>(
                      compact: true,
                      colors: const [context.appPrimary, context.appPrimary],
                      backgroundColor: context.appSurfaceSoft,
                      inactiveTextColor: context.appSecondaryText,
                      keyPrefix: 'home-trend',
                      items: const [
                        (AnalysisPeriod.last7Days, '周'),
                        (AnalysisPeriod.currentMonth, '月'),
                        (AnalysisPeriod.currentYear, '年'),
                      ],
                      selected: _period,
                      onChanged: (period) => setState(() {
                        _period = period;
                        _selected = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.amountHidden
                          ? '金额已隐藏'
                          : '本期累计支出 ¥${MoneyFormatter.whole(snapshot.totalExpense)}  · 日均 ¥${MoneyFormatter.whole(average)}',
                      key: const ValueKey('home-trend-value'),
                      style: TextStyle(
                        color: context.appPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              if (widget.amountHidden)
                const SizedBox(
                  height: 88,
                  child: Center(
                    child: Text(
                      '趋势金额已隐藏',
                      style: TextStyle(
                        color: context.appSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              else if (points.isNotEmpty)
                Semantics(
                  label: '支出趋势，${year ? "按月" : "按日"}查看',
                  value:
                      '${dateLabel(point!)}，${MoneyFormatter.decimal(point.expense)}元',
                  increasedValue: selected < points.length - 1
                      ? dateLabel(points[selected + 1])
                      : null,
                  decreasedValue: selected > 0
                      ? dateLabel(points[selected - 1])
                      : null,
                  onIncrease: selected < points.length - 1
                      ? () => setState(() => _selected = selected + 1)
                      : null,
                  onDecrease: selected > 0
                      ? () => setState(() => _selected = selected - 1)
                      : null,
                  child: CashflowTrendChart(
                    key: const ValueKey('home-trend-chart'),
                    points: points,
                    selected: selected,
                    year: year,
                    height: 88,
                    onSelected: (index) => setState(() => _selected = index),
                  ),
                ),
              if (snapshot.expenseCount == 0)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '这段时间还没有支出，记下一笔就能看到变化',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<CashflowPoint> _monthlyPoints(List<CashflowPoint> daily) {
    final amounts = <DateTime, int>{};
    for (final p in daily) {
      final month = DateTime(p.date.year, p.date.month);
      amounts.update(
        month,
        (cents) => cents + (p.expense * 100).round(),
        ifAbsent: () => (p.expense * 100).round(),
      );
    }
    return amounts.entries
        .map((entry) => CashflowPoint(entry.key, 0, entry.value / 100))
        .toList();
  }
}
