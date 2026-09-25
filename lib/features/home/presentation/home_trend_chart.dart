import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/widgets/monotone_smooth_path.dart';

const homeTrendExpenseColor = Color(0xFFFF7600);
const homeTrendIncomeColor = Color(0xFF63A72F);
const homeTrendAssetColor = Color(0xFFE66C6C);
const homeTrendSelectionColor = Color(0xFF9BC879);

class HomeTrendChart extends StatelessWidget {
  const HomeTrendChart({
    required this.points,
    required this.selected,
    required this.onSelected,
    this.year = false,
    this.currency = 'CNY',
    this.height = 104,
    super.key,
  });

  final List<CashflowPoint> points;
  final int selected;
  final ValueChanged<int>? onSelected;
  final bool year;
  final String currency;
  final double height;

  static const double _plotLeft = 31;
  static const double _plotRight = 38;

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
          final next = (ratio * (points.length - 1)).round();
          if (next != selectedIndex) onSelected!(next);
        }

        const tooltipWidth = 84.0;
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
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _HomeTrendPainter(
                        points: points,
                        selected: selectedIndex,
                        year: year,
                        currency: currency,
                        axisTextColor: context.appSecondaryText,
                        gridColor: context.appDivider,
                        surfaceColor: context.appSurface,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: tooltipLeft,
                  top: -40,
                  width: tooltipWidth,
                  child: IgnorePointer(
                    child: _TrendTooltip(
                      point: points[selectedIndex],
                      currency: currency,
                      year: year,
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
  const _TrendTooltip({
    required this.point,
    required this.currency,
    required this.year,
  });

  final CashflowPoint point;
  final String currency;
  final bool year;

  @override
  Widget build(BuildContext context) {
    final date = point.date;
    final title = year
        ? '${date.year}年${date.month}月'
        : '${date.month}/${date.day}（${_weekdayLabel(date.weekday)}）';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
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
              fontSize: 8.5,
              height: 1.05,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          _TooltipRow(
            color: homeTrendExpenseColor,
            label: '支出',
            amount: '¥${MoneyFormatter.whole(point.expense)}',
          ),
          const SizedBox(height: 3),
          _TooltipRow(
            color: homeTrendIncomeColor,
            label: '收入',
            amount: '¥${MoneyFormatter.whole(point.income)}',
          ),
          const SizedBox(height: 3),
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
              fontSize: 8.5,
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
                  fontSize: 8.5,
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
    required this.currency,
    required this.axisTextColor,
    required this.gridColor,
    required this.surfaceColor,
  });

  final List<CashflowPoint> points;
  final int selected;
  final bool year;
  final String currency;
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

    final maxFlow = points.fold<double>(
      0,
      (value, point) => math.max(value, math.max(point.income, point.expense)),
    );
    final flowCeiling = _niceCeiling(math.max(1, maxFlow * 1.12));
    final assetValues = points.map<double?>((p) => p.totalAssets).toList();
    final assetScale = _assetScale(assetValues);

    final labelIndices = _labelIndices(points.length, 7);
    _drawGrid(
      canvas,
      size,
      plotBottom,
      plotHeight,
      xFor,
      labelIndices,
      flowCeiling: flowCeiling,
      assetScale: assetScale,
    );

    List<Offset?> flowPositions(Iterable<double> values) => [
          for (final (index, value) in values.indexed)
            Offset(
              xFor(index),
              _top +
                  plotHeight *
                      (1 - (value / flowCeiling).clamp(0.0, 1.0)),
            ),
        ];

    final incomeValues = points.map((p) => p.income).toList(growable: false);
    final expenseValues = points.map((p) => p.expense).toList(growable: false);
    final incomePositions = flowPositions(incomeValues);
    final expensePositions = flowPositions(expenseValues);
    final assetPositions = _assetPositions(
      assetValues,
      xFor,
      plotHeight,
      assetScale,
    );

    _drawSeries(
      canvas,
      size,
      assetValues,
      assetPositions,
      homeTrendAssetColor.withValues(alpha: .58),
      plotBottom,
      strokeWidth: 1.45,
      fillAlpha: 0,
      drawPoints: false,
    );
    _drawSeries(
      canvas,
      size,
      incomeValues.map<double?>((v) => v).toList(),
      incomePositions,
      homeTrendIncomeColor,
      plotBottom,
      strokeWidth: 2,
      fillAlpha: .07,
      drawPoints: points.length <= 36,
    );
    _drawSeries(
      canvas,
      size,
      expenseValues.map<double?>((v) => v).toList(),
      expensePositions,
      homeTrendExpenseColor,
      plotBottom,
      strokeWidth: 2,
      fillAlpha: .07,
      drawPoints: points.length <= 36,
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
      homeTrendAssetColor.withValues(alpha: .74),
      radius: 4.6,
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
    List<int> labelIndices, {
    required double flowCeiling,
    required ({double min, double max})? assetScale,
  }) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .72)
      ..strokeWidth = .8;

    for (var row = 0; row < 5; row++) {
      final ratio = row / 4;
      final y = _top + ratio * plotHeight;
      _drawDashedLine(
        canvas,
        Offset(_left, y),
        Offset(size.width - _right, y),
        gridPaint,
        dash: 4,
        gap: 4,
      );
      _label(
        canvas,
        '¥${_compactAxisMoney(flowCeiling * (1 - ratio))}',
        Offset(0, y - 5.5),
        maxWidth: _left - 3,
        align: TextAlign.right,
      );
      if (assetScale != null) {
        final assetValue =
            assetScale.max - (assetScale.max - assetScale.min) * ratio;
        _label(
          canvas,
          _compactAxisMoney(assetValue, currency: currency),
          Offset(size.width - _right + 3, y - 5.5),
          maxWidth: _right - 3,
          color: homeTrendAssetColor.withValues(alpha: .72),
        );
      }
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
          (x - 14).clamp(_left - 5, size.width - _right - 27).toDouble(),
          plotBottom + 8,
        ),
        maxWidth: 32,
        align: TextAlign.center,
      );
    }

    final axis = Paint()
      ..color = axisTextColor.withValues(alpha: .30)
      ..strokeWidth = .8;
    canvas.drawLine(Offset(_left, _top), Offset(_left, plotBottom), axis);
    if (assetScale != null) {
      canvas.drawLine(
        Offset(size.width - _right, _top),
        Offset(size.width - _right, plotBottom),
        Paint()
          ..color = homeTrendAssetColor.withValues(alpha: .25)
          ..strokeWidth = .8,
      );
    }
    canvas.drawLine(
      Offset(_left, plotBottom),
      Offset(size.width - _right, plotBottom),
      axis,
    );
  }

  ({double min, double max})? _assetScale(List<double?> values) {
    final known = values.whereType<double>().toList(growable: false);
    if (known.isEmpty) return null;
    final minimum = known.reduce(math.min);
    final maximum = known.reduce(math.max);
    if (minimum == maximum) {
      final padding = math.max(1.0, minimum.abs() * .01);
      return (min: minimum - padding, max: maximum + padding);
    }
    final padding = (maximum - minimum) * .12;
    return (min: minimum - padding, max: maximum + padding);
  }

  List<Offset?> _assetPositions(
    List<double?> values,
    double Function(int index) xFor,
    double plotHeight,
    ({double min, double max})? scale,
  ) {
    if (scale == null) return List<Offset?>.filled(values.length, null);
    final span = math.max(1e-9, scale.max - scale.min);
    return List<Offset?>.generate(values.length, (index) {
      final value = values[index];
      if (value == null) return null;
      final normalized = ((value - scale.min) / span).clamp(0.0, 1.0);
      return Offset(xFor(index), _top + plotHeight * (1 - normalized));
    });
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double?> values,
    List<Offset?> positions,
    Color color,
    double plotBottom, {
    required double strokeWidth,
    required double fillAlpha,
    required bool drawPoints,
  }) {
    var start = -1;
    var segmentValues = <double>[];

    void paintSegment() {
      if (segmentValues.isEmpty || start < 0) return;
      if (segmentValues.length == 1) {
        if (drawPoints) _drawPoint(canvas, positions[start]!, color);
        segmentValues = [];
        start = -1;
        return;
      }
      final line = buildMonotoneSmoothLinePath(
        values: segmentValues,
        position: (_, localIndex) => positions[start + localIndex]!,
      );
      if (fillAlpha > 0) {
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
                color.withValues(alpha: fillAlpha),
                color.withValues(alpha: .008),
              ],
            ).createShader(
              Rect.fromLTWH(0, _top, size.width, plotBottom - _top),
            ),
        );
      }
      canvas.drawPath(
        line.path,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (drawPoints) {
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

  void _drawSelection(
    Canvas canvas,
    Offset? point,
    Color color, {
    double radius = 5.2,
  }) {
    if (point == null) return;
    canvas.drawCircle(
      point,
      radius + 1.8,
      Paint()..color = color.withValues(alpha: .16),
    );
    canvas.drawCircle(point, radius, Paint()..color = color);
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
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
    Color? color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? axisTextColor,
          fontSize: 7.5,
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
      oldDelegate.currency != currency ||
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
  if (value <= 0) return 1;
  final magnitude =
      math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
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

String _compactAxisMoney(double value, {String currency = 'CNY'}) {
  final absolute = value.abs();
  final prefix = _currencySymbol(currency);
  final sign = value < 0 ? '-' : '';
  if (absolute >= 100000000) {
    return '$sign$prefix${_trimAxis(absolute / 100000000)}亿';
  }
  if (absolute >= 10000) {
    return '$sign$prefix${_trimAxis(absolute / 10000)}万';
  }
  if (absolute >= 1000) {
    return '$sign$prefix${_trimAxis(absolute / 1000)}k';
  }
  return '$sign$prefix${MoneyFormatter.whole(absolute)}';
}

String _trimAxis(double value) =>
    value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

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
