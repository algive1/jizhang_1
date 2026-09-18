import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/monotone_smooth_path.dart';
import '../../../core/widgets/privacy_amount.dart';

/// Simple line trend for 投资资产 and for a single holding's price.
///
/// Intentionally limited to a smooth line + area fill with a tappable
/// selection handle. No K-line, no intraday, no volume, no oscillators.
class InvestmentChart extends StatefulWidget {
  const InvestmentChart({
    required this.points,
    required this.amountHidden,
    this.height = 118,
    this.lineColor = AppColors.primary,
    this.valueFormatter,
    this.emptyLabel = '暂无趋势数据',
    this.keyPrefix = 'investment-chart',
    super.key,
  });

  final List<({DateTime date, double value})> points;
  final bool amountHidden;
  final double height;
  final Color lineColor;

  /// Overrides the axis/bubble formatting (money by default).
  final String Function(double value)? valueFormatter;

  final String emptyLabel;
  final String keyPrefix;

  @override
  State<InvestmentChart> createState() => _InvestmentChartState();
}

class _InvestmentChartState extends State<InvestmentChart> {
  int? _selectedIndex;

  int get _activeIndex {
    if (widget.points.isEmpty) return 0;
    return (_selectedIndex ?? widget.points.length - 1).clamp(
      0,
      widget.points.length - 1,
    );
  }

  void _selectAt(double dx, double width) {
    if (widget.points.length < 2) return;
    const left = 36.0;
    const right = 8.0;
    final plot = math.max(1.0, width - left - right);
    final ratio = ((dx - left) / plot).clamp(0.0, 1.0);
    final index = (ratio * (widget.points.length - 1)).round();
    if (index == _activeIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            widget.emptyLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    final selected = widget.points[_activeIndex];
    final label = widget.valueFormatter?.call(selected.value) ??
        '¥${MoneyFormatter.decimal(selected.value)}';
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                key: ValueKey('${widget.keyPrefix}-plot'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _selectAt(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragStart: (details) =>
                    _selectAt(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (details) =>
                    _selectAt(details.localPosition.dx, constraints.maxWidth),
                child: CustomPaint(
                  painter: _InvestmentChartPainter(
                    points: widget.points,
                    selectedIndex: _activeIndex,
                    lineColor: widget.lineColor,
                    fontFamily: Theme.of(
                      context,
                    ).textTheme.bodySmall?.fontFamily,
                    valueFormatter: widget.valueFormatter,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PrivacyAmount(
                key: ValueKey('${widget.keyPrefix}-selected'),
                text:
                    '${selected.date.month}/${selected.date.day} · $label',
                hidden: widget.amountHidden,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentChartPainter extends CustomPainter {
  _InvestmentChartPainter({
    required this.points,
    required this.selectedIndex,
    required this.lineColor,
    this.fontFamily,
    this.valueFormatter,
  });

  final List<({DateTime date, double value})> points;
  final int selectedIndex;
  final Color lineColor;
  final String? fontFamily;
  final String Function(double value)? valueFormatter;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    const right = 8.0;
    const top = 8.0;
    final width = math.max(1.0, size.width - left - right);
    final bottom = math.max(top + 1, size.height - 14);
    final height = math.max(1.0, bottom - top);

    final values = points.map((point) => point.value).toList(growable: false);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    // A flat series still needs a non-zero span so the line lands mid-chart.
    final span = (maxValue - minValue).abs() < 1e-9
        ? math.max(1.0, maxValue.abs() * .02)
        : maxValue - minValue;
    final padded = span * 1.25;
    final floor = minValue - (padded - span) / 2;

    Offset position(double value, int index) => Offset(
      left + width * (points.length == 1 ? .5 : index / (points.length - 1)),
      bottom - (value - floor) / padded * height,
    );

    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = .8;
    for (var row = 0; row < 3; row++) {
      final y = top + row * height / 2;
      for (var x = left; x < size.width - right; x += 7) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, size.width - right), y),
          grid,
        );
      }
      final value = maxValue - row * (maxValue - minValue) / 2;
      _label(canvas, _axis(value), Offset(0, y - 6), maxWidth: 34);
    }

    final line = buildMonotoneSmoothLinePath(
      values: values,
      position: position,
    );
    final area = Path.from(line.path)
      ..lineTo(line.coordinates.last.dx, bottom)
      ..lineTo(line.coordinates.first.dx, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: .22),
            lineColor.withValues(alpha: .02),
          ],
        ).createShader(Rect.fromLTWH(left, top, width, height)),
    );
    canvas.drawPath(
      line.path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (points.length < 33) {
      for (final coordinate in line.coordinates) {
        canvas.drawCircle(coordinate, 2, Paint()..color = lineColor);
      }
    }

    final current = line.coordinates[selectedIndex.clamp(0, points.length - 1)];
    canvas.drawLine(
      Offset(current.dx, top),
      Offset(current.dx, bottom),
      Paint()
        ..color = lineColor.withValues(alpha: .28)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      current,
      7,
      Paint()..color = lineColor.withValues(alpha: .16),
    );
    canvas.drawCircle(current, 3.5, Paint()..color = lineColor);
    canvas.drawCircle(
      current,
      3.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final labels = <int>{
      0,
      ((points.length - 1) / 2).round(),
      points.length - 1,
    };
    for (final index in labels) {
      final date = points[index].date;
      _label(
        canvas,
        '${date.month}/${date.day}',
        Offset(
          (position(0, index).dx - 13).clamp(left - 10, size.width - 34),
          bottom + 4,
        ),
        maxWidth: 40,
      );
    }
  }

  String _axis(double value) {
    final formatter = valueFormatter;
    if (formatter != null) return formatter(value);
    final magnitude = value.abs();
    if (magnitude >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return MoneyFormatter.whole(value);
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
  bool shouldRepaint(covariant _InvestmentChartPainter old) =>
      old.points != points ||
      old.selectedIndex != selectedIndex ||
      old.lineColor != lineColor ||
      old.valueFormatter != valueFormatter;
}

/// Period capsule row shared by the portfolio trend and the detail chart.
///
/// Takes `(value, label)` pairs rather than a generic Enum so the same widget
/// serves [PortfolioRange] and [InvestmentRange] without a dynamic cast.
class InvestmentRangeSelector<T> extends StatelessWidget {
  const InvestmentRangeSelector({
    required this.items,
    required this.selected,
    required this.onChanged,
    this.keyPrefix = 'investment-range',
    super.key,
  });

  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) =>
      // Scales the capsule row down when the header is tight (narrow screen or
      // a large text scale) instead of overflowing it. Callers wrap this in a
      // Flexible so a real width bound exists.
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: InkWell(
                  key: ValueKey(
                    '$keyPrefix-${item.$1 is Enum ? (item.$1 as Enum).name : item.$1}',
                  ),
                  onTap: () => onChanged(item.$1),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: item.$1 == selected
                          ? const Color(0xFF83A25D)
                          : const Color(0xFFF5F6EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.$2,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: item.$1 == selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: item.$1 == selected
                            ? Colors.white
                            : const Color(0xFF888C88),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
