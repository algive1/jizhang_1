import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/widgets/monotone_smooth_path.dart';

const homeTrendExpenseColor = Color(0xFFFF7600);
const homeTrendIncomeColor = Color(0xFF63A72F);
const homeTrendAssetColor = Color(0xFFFF2525);
const homeTrendSelectionColor = Color(0xFF9BC879);

class HomeTrendChart extends StatelessWidget {
  const HomeTrendChart({
    required this.points,
    required this.selected,
    required this.onSelected,
    this.year = false,
    this.currency = 'CNY',
    this.height = 112,
    super.key,
  });

  final List<CashflowPoint> points;
  final int selected;
  final ValueChanged<int>? onSelected;
  final bool year;
  final String currency;
  final double height;

  static const double _plotLeft = 28;
  static const double _plotRight = 4;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return SizedBox(height: height);
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedIndex = selected.clamp(0, points.length - 1).toInt();
        final chartWidth = math.max(
          1.0,
          constraints.maxWidth - _plotLeft - _plotRight,
        );

        double xFor(int index) =>
            _plotLeft +
            chartWidth *
                (points.length == 1 ? .5 : index / (points.length - 1));

        void select(double dx) {
          if (onSelected == null) return;
          final ratio = ((dx - _plotLeft) / chartWidth).clamp(0.0, 1.0);
          onSelected!((ratio * (points.length - 1)).round());
        }

        const tooltipWidth = 92.0;
        final tooltipLeft = (xFor(selectedIndex) - tooltipWidth / 2)
            .clamp(0.0, math.max(0.0, constraints.maxWidth - tooltipWidth))
            .toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onSelected == null
              ? null
              : (event) => select(event.localPosition.dx),
          onHorizontalDragStart: onSelected == null
              ? null
              : (event) => select(event.localPosition.dx),
          onHorizontalDragUpdate: onSelected == null
              ? null
              : (event) => select(event.localPosition.dx),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HomeTrendPainter(
                      points: points,
                      selected: selectedIndex,
                      year: year,
                      axisTextColor: context.appSecondaryText,
                      gridColor: context.appDivider,
                      surfaceColor: context.appSurface,
                    ),
                  ),
                ),
                Positioned(
                  left: tooltipLeft,
                  top: -44,
                  width: tooltipWidth,
                  child: IgnorePointer(
                    child: _TrendTooltip(
                      point: points[selectedIndex],
                      currency: currency,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrendTooltip extends StatelessWidget {
  const _TrendTooltip({required this.point, required this.currency});

  final CashflowPoint point;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final date = point.date;
    final title =
        '${date.month}/${date.day}（${_weekdayLabel(date.weekday)}）';
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
      decoration: BoxDecoration(
        color: context.appSurfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appDivider.withValues(alpha: .65)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 13,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: context.appSecondaryText,
              fontSize: 9.5,
              height: 1.05,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _TooltipRow(
            color: homeTrendExpenseColor,
            label: '支出',
            amount: '¥${MoneyFormatter.whole(point.expense)}',
          ),
          const SizedBox(height: 4),
          _TooltipRow(
            color: homeTrendIncomeColor,
            label: '收入',
            amount: '¥${MoneyFormatter.whole(point.income)}',
          ),
          const SizedBox(height: 4),
          _TooltipRow(
            color: homeTrendAssetColor,
            label: '资产',
            amount: point.totalAssets == null
                ? '--'
                : '${_currencySymbol(currency)}${MoneyFormatter.whole(point.totalAssets!)}',
          ),
        ],
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  const _TooltipRow({
    required this.color,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Spacer(),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  );
}

class _HomeTrendPainter extends CustomPainter {
  const _HomeTrendPainter({
    required this.points,
    required this.selected,
    required this.year,
    required this.axisTextColor,
    required this.gridColor,
    required this.surfaceColor,
  });

  final List<CashflowPoint> points;
  final int selected;
  final bool year;
  final Color axisTextColor;
  final Color gridColor;
  final Color surfaceColor;

  static const double _left = HomeTrendChart._plotLeft;
  static const double _right = HomeTrendChart._plotRight;
  static const double _top = 10;
  static const double _bottomInset = 21;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;
    final plotBottom = math.max(_top + 1, size.height - _bottomInset);
    final plotHeight = math.max(1.0, plotBottom - _top);
    final plotWidth = math.max(1.0, size.width - _left - _right);
    final selectedIndex = selected.clamp(0, points.length - 1).toInt();

    double xFor(int index) =>
        _left +
        plotWidth * (points.length == 1 ? .5 : index / (points.length - 1));

    final labelIndices = _labelIndices(points.length, 7);

    _drawGrid(
      canvas,
      size,
      plotBottom,
      plotHeight,
      xFor,
      labelIndices,
    );

    final expenseValues = points.map<double?>((p) => p.expense).toList();
    final incomeValues = points.map<double?>((p) => p.income).toList();
    final assetValues = points.map<double?>((p) => p.totalAssets).toList();

    final assetPositions = _seriesPositions(
      assetValues,
      xFor,
      plotHeight,
      .08,
      .35,
    );
    final incomePositions = _seriesPositions(
      incomeValues,
      xFor,
      plotHeight,
      .40,
      .69,
    );
    final expensePositions = _seriesPositions(
      expenseValues,
      xFor,
      plotHeight,
      .69,
      .92,
    );

    _drawSeries(
      canvas,
      size,
      assetValues,
      assetPositions,
      homeTrendAssetColor,
      plotBottom,
    );
    _drawSeries(
      canvas,
      size,
      incomeValues,
      incomePositions,
      homeTrendIncomeColor,
      plotBottom,
    );
    _drawSeries(
      canvas,
      size,
      expenseValues,
      expensePositions,
      homeTrendExpenseColor,
      plotBottom,
    );

    final selectedX = xFor(selectedIndex);
    _drawDashedLine(
      canvas,
      Offset(selectedX, 0),
      Offset(selectedX, plotBottom),
      Paint()
        ..color = homeTrendSelectionColor.withValues(alpha: .82)
        ..strokeWidth = 1,
      dash: 4,
      gap: 4,
    );

    _drawSelection(
      canvas,
      assetPositions[selectedIndex],
      homeTrendAssetColor,
    );
    _drawSelection(
      canvas,
      incomePositions[selectedIndex],
      homeTrendIncomeColor,
    );
    _drawSelection(
      canvas,
      expensePositions[selectedIndex],
      homeTrendExpenseColor,
    );

    canvas.drawCircle(
      Offset(selectedX, plotBottom),
      3,
      Paint()..color = homeTrendIncomeColor,
    );
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    double plotBottom,
    double plotHeight,
    double Function(int index) xFor,
    List<int> labelIndices,
  ) {
    final maxFlow = points.fold<double>(
      0,
      (value, point) => math.max(value, math.max(point.income, point.expense)),
    );
    final ceiling = _niceCeiling(math.max(800, maxFlow * 1.15));
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .82)
      ..strokeWidth = .8;

    for (var row = 0; row < 5; row++) {
      final y = _top + row * plotHeight / 4;
      _drawDashedLine(
        canvas,
        Offset(_left, y),
        Offset(size.width - _right, y),
        gridPaint,
        dash: 4,
        gap: 4,
      );
      final amount = ceiling * (1 - row / 4);
      _label(
        canvas,
        '¥${MoneyFormatter.whole(amount)}',
        Offset(0, y - 5.5),
        maxWidth: _left - 3,
        align: TextAlign.right,
      );
    }

    for (final index in labelIndices) {
      final x = xFor(index);
      _drawDashedLine(
        canvas,
        Offset(x, _top),
        Offset(x, plotBottom),
        gridPaint,
        dash: 4,
        gap: 4,
      );
      final date = points[index].date;
      final text = year ? '${date.month}月' : '${date.month}/${date.day}';
      _label(
        canvas,
        text,
        Offset(
          (x - 14).clamp(_left - 5, size.width - 31).toDouble(),
          plotBottom + 8,
        ),
        maxWidth: 32,
        align: TextAlign.center,
      );
    }

    final axis = Paint()
      ..color = axisTextColor.withValues(alpha: .34)
      ..strokeWidth = .8;
    canvas.drawLine(Offset(_left, _top), Offset(_left, plotBottom), axis);
    canvas.drawLine(
      Offset(_left, plotBottom),
      Offset(size.width - _right, plotBottom),
      axis,
    );
  }

  List<Offset?> _seriesPositions(
    List<double?> values,
    double Function(int index) xFor,
    double plotHeight,
    double bandTop,
    double bandBottom,
  ) {
    final known = values.whereType<double>().toList(growable: false);
    if (known.isEmpty) return List<Offset?>.filled(values.length, null);
    final minimum = known.reduce(math.min);
    final maximum = known.reduce(math.max);
    final span = maximum - minimum;
    return List<Offset?>.generate(values.length, (index) {
      final value = values[index];
      if (value == null) return null;
      final normalized = span == 0 ? .5 : (value - minimum) / span;
      final bandY = bandBottom - normalized * (bandBottom - bandTop);
      return Offset(xFor(index), _top + plotHeight * bandY);
    });
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double?> values,
    List<Offset?> positions,
    Color color,
    double plotBottom,
  ) {
    var start = -1;
    var segmentValues = <double>[];

    void paintSegment() {
      if (segmentValues.isEmpty || start < 0) return;
      if (segmentValues.length == 1) {
        final point = positions[start]!;
        _drawPoint(canvas, point, color);
        segmentValues = [];
        start = -1;
        return;
      }
      final line = buildMonotoneSmoothLinePath(
        values: segmentValues,
        position: (_, localIndex) => positions[start + localIndex]!,
      );
      final first = line.coordinates.first;
      final last = line.coordinates.last;
      final fill = Path.from(line.path)
        ..lineTo(last.dx, plotBottom)
        ..lineTo(first.dx, plotBottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: .10),
              color.withValues(alpha: .012),
            ],
          ).createShader(Rect.fromLTWH(0, _top, size.width, plotBottom - _top)),
      );
      canvas.drawPath(
        line.path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (points.length <= 36) {
        for (final point in line.coordinates) {
          _drawPoint(canvas, point, color);
        }
      }
      segmentValues = [];
      start = -1;
    }

    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null || positions[index] == null) {
        paintSegment();
      } else {
        if (start < 0) start = index;
        segmentValues.add(value);
      }
    }
    paintSegment();
  }

  void _drawPoint(Canvas canvas, Offset point, Color color) {
    canvas.drawCircle(point, 2.1, Paint()..color = color);
    canvas.drawCircle(
      point,
      2.1,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = .75,
    );
  }

  void _drawSelection(Canvas canvas, Offset? point, Color color) {
    if (point == null) return;
    canvas.drawCircle(
      point,
      7,
      Paint()..color = color.withValues(alpha: .18),
    );
    canvas.drawCircle(point, 5.2, Paint()..color = color);
    canvas.drawCircle(
      point,
      5.2,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final distance = (end - start).distance;
    if (distance <= 0) return;
    final direction = (end - start) / distance;
    var cursor = 0.0;
    while (cursor < distance) {
      final segmentEnd = math.min(cursor + dash, distance);
      canvas.drawLine(
        start + direction * cursor,
        start + direction * segmentEnd,
        paint,
      );
      cursor += dash + gap;
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset, {
    required double maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: axisTextColor,
          fontSize: 8.5,
          height: 1,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _HomeTrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selected != selected ||
      oldDelegate.year != year ||
      oldDelegate.axisTextColor != axisTextColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.surfaceColor != surfaceColor;
}

List<int> _labelIndices(int count, int requested) {
  if (count <= 0) return const [];
  if (count <= requested) return [for (var i = 0; i < count; i++) i];
  final indices = <int>{};
  for (var slot = 0; slot < requested; slot++) {
    indices.add((slot * (count - 1) / (requested - 1)).round());
  }
  return indices.toList()..sort();
}

double _niceCeiling(double value) {
  if (value <= 0) return 800;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  final scaled = value / magnitude;
  final factor = scaled <= 1
      ? 1
      : scaled <= 2
      ? 2
      : scaled <= 4
      ? 4
      : scaled <= 5
      ? 5
      : scaled <= 8
      ? 8
      : 10;
  return factor * magnitude;
}

String _weekdayLabel(int weekday) => switch (weekday) {
  DateTime.monday => '周一',
  DateTime.tuesday => '周二',
  DateTime.wednesday => '周三',
  DateTime.thursday => '周四',
  DateTime.friday => '周五',
  DateTime.saturday => '周六',
  DateTime.sunday => '周日',
  _ => '',
};

String _currencySymbol(String currency) => switch (currency.toUpperCase()) {
  'CNY' => '¥',
  'USD' => r'$',
  'EUR' => '€',
  'GBP' => '£',
  'JPY' => '¥',
  _ => '$currency ',
};
