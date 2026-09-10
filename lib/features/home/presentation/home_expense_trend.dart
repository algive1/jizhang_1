import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/widgets/sliding_segmented_control.dart';
import '../../analysis/data/analysis_repository.dart';
import 'home_cards.dart';

class HomeExpenseTrend extends ConsumerStatefulWidget {
  const HomeExpenseTrend({super.key});
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _BudgetChip(
                    label: '本月预算',
                    onTap: () => context.push('/profile/budgets'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '本期累计支出 ¥${MoneyFormatter.whole(snapshot.totalExpense)}  · 日均 ¥${MoneyFormatter.whole(average)}',
                      key: const ValueKey('home-trend-value'),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 132,
                    child: SlidingSegmentedControl<AnalysisPeriod>(
                      compact: true,
                      colors: const [AppColors.primary, AppColors.primaryDark],
                      backgroundColor: AppColors.surfaceSoft,
                      inactiveTextColor: AppColors.textSecondary,
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
              const SizedBox(height: 8),
              if (points.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) {
                    void select(double dx) {
                      final ratio =
                          ((dx - 38) / math.max(1, constraints.maxWidth - 48))
                              .clamp(0, 1);
                      setState(
                        () => _selected = (ratio * (points.length - 1)).round(),
                      );
                    }

                    return Semantics(
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
                      child: GestureDetector(
                        key: const ValueKey('home-trend-chart'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (event) => select(event.localPosition.dx),
                        onHorizontalDragStart: (event) =>
                            select(event.localPosition.dx),
                        onHorizontalDragUpdate: (event) =>
                            select(event.localPosition.dx),
                        child: SizedBox(
                          height: 132,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _ExpensePainter(
                              points: points,
                              selected: selected,
                              year: year,
                              fontFamily: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.fontFamily,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (snapshot.expenseCount == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '这段时间还没有支出，记下一笔就能看到变化',
                    style: TextStyle(
                      color: AppColors.textSecondary,
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

class _BudgetChip extends StatelessWidget {
  const _BudgetChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primaryDark, fontSize: 10),
      ),
    ),
  );
}

class _ExpensePainter extends CustomPainter {
  const _ExpensePainter({
    required this.points,
    required this.selected,
    required this.year,
    this.fontFamily,
  });
  final List<CashflowPoint> points;
  final int selected;
  final bool year;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const top = 10.0;
    final width = math.max(1.0, size.width - left - 10);
    final bottom = size.height - 25;
    final height = bottom - top;
    final maxAmount = points.fold<double>(
      0,
      (v, p) => math.max(v, math.max(0, p.expense)),
    );
    final ceiling = math.max(2.0, maxAmount * 1.2);
    Offset position(int i) => Offset(
      left + width * (points.length == 1 ? .5 : i / (points.length - 1)),
      bottom - math.max(0, points[i].expense) / ceiling * height,
    );
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = .8;
    for (var i = 0; i < 4; i++) {
      final y = top + i * height / 3;
      for (var x = left; x < size.width - 10; x += 7) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, size.width - 10), y),
          grid,
        );
      }
      final amount = ceiling * (1 - i / 3);
      final label = amount >= 10000
          ? '${(amount / 10000).toStringAsFixed(1)}万'
          : MoneyFormatter.whole(amount);
      _label(canvas, label, Offset(0, y - 6), maxWidth: 35);
    }
    final line = Path()..moveTo(position(0).dx, position(0).dy);
    for (var i = 1; i < points.length; i++) {
      final previous = position(i - 1);
      final current = position(i);
      final dx = (current.dx - previous.dx) / 3;
      line.cubicTo(
        previous.dx + dx,
        previous.dy,
        current.dx - dx,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final area = Path.from(line)
      ..lineTo(position(points.length - 1).dx, bottom)
      ..lineTo(position(0).dx, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: .24),
            AppColors.primary.withValues(alpha: .02),
          ],
        ).createShader(Rect.fromLTWH(left, top, width, height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (points.length < 33) {
      for (var i = 0; i < points.length; i++) {
        canvas.drawCircle(position(i), 2, Paint()..color = AppColors.primary);
      }
    }
    final current = position(selected);
    canvas.drawLine(
      Offset(current.dx, top),
      Offset(current.dx, bottom),
      Paint()
        ..color = const Color(0x77498DF0)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      current,
      7,
      Paint()..color = AppColors.primary.withValues(alpha: .16),
    );
    canvas.drawCircle(current, 4, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      current,
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final bubbleText = TextPainter(
      text: TextSpan(
        text: MoneyFormatter.whole(points[selected].expense),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
        ).copyWith(fontFamily: fontFamily),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 58);
    final bubbleWidth = bubbleText.width + 12;
    final bubbleLeft = (current.dx - bubbleWidth / 2)
        .clamp(38.0, size.width - bubbleWidth)
        .toDouble();
    final bubbleTop = math.max(0.0, current.dy - 25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, 18),
        const Radius.circular(8),
      ),
      Paint()..color = AppColors.primaryDark,
    );
    bubbleText.paint(canvas, Offset(bubbleLeft + 6, bubbleTop + 4));
    final labels = <int>{
      0,
      ((points.length - 1) / 3).round(),
      (2 * (points.length - 1) / 3).round(),
      points.length - 1,
    };
    for (final i in labels) {
      final date = points[i].date;
      _label(
        canvas,
        year ? '${date.month}月' : '${date.month}/${date.day}',
        Offset(
          (position(i).dx - 13).clamp(left - 8, size.width - 33),
          bottom + 10,
        ),
        maxWidth: 40,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset, {
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 9,
        ).copyWith(fontFamily: fontFamily),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ExpensePainter old) =>
      old.points != points || old.selected != selected || old.year != year;
}
