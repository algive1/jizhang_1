import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../formatters/money_formatter.dart';
import '../models/analysis.dart';
import 'monotone_smooth_path.dart';

class CashflowTrendChart extends StatelessWidget {
  const CashflowTrendChart({
    required this.points,
    required this.selected,
    required this.onSelected,
    this.showIncome = false,
    this.showExpense = true,
    this.year = false,
    this.bubbleLabel,
    this.height = 132,
    super.key,
  });

  final List<CashflowPoint> points;
  final int selected;
  final ValueChanged<int>? onSelected;
  final bool showIncome;
  final bool showExpense;
  final bool year;
  final String? bubbleLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return SizedBox(height: height);
    return LayoutBuilder(
      builder: (context, constraints) {
        void select(double dx) {
          if (onSelected == null) return;
          final chartWidth = math.max(1, constraints.maxWidth - 48);
          final ratio = ((dx - 38) / chartWidth).clamp(0, 1);
          onSelected!((ratio * (points.length - 1)).round());
        }

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
            child: CustomPaint(
              painter: CashflowTrendPainter(
                points: points,
                selected: selected,
                showIncome: showIncome,
                showExpense: showExpense,
                year: year,
                bubbleLabel: bubbleLabel,
                fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CashflowTrendPainter extends CustomPainter {
  const CashflowTrendPainter({
    required this.points,
    required this.selected,
    required this.showIncome,
    required this.showExpense,
    required this.year,
    required this.bubbleLabel,
    this.fontFamily,
  });

  final List<CashflowPoint> points;
  final int selected;
  final bool showIncome;
  final bool showExpense;
  final bool year;
  final String? bubbleLabel;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const right = 10.0;
    const top = 10.0;
    final width = math.max(1.0, size.width - left - right);
    final bottom = size.height - 25;
    final height = math.max(1.0, bottom - top);
    final maximum = points.fold<double>(
      0,
      (value, point) => math.max(
        value,
        math.max(
          showIncome ? point.income : 0,
          showExpense ? point.expense : 0,
        ),
      ),
    );
    final ceiling = math.max(2.0, maximum * 1.2);
    final selectedIndex = selected.clamp(0, points.length - 1).toInt();

    Offset position(double value, int index) => Offset(
      left + width * (points.length == 1 ? .5 : index / (points.length - 1)),
      bottom - math.max(0, value) / ceiling * height,
    );

    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = .8;
    for (var row = 0; row < 4; row++) {
      final y = top + row * height / 3;
      for (var x = left; x < size.width - right; x += 7) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, size.width - right), y),
          grid,
        );
      }
      final amount = ceiling * (1 - row / 3);
      _label(
        canvas,
        amount >= 10000
            ? '${(amount / 10000).toStringAsFixed(1)}万'
            : MoneyFormatter.whole(amount),
        Offset(0, y - 6),
        maxWidth: 35,
      );
    }

    final expenseColor = showIncome ? AppColors.warning : AppColors.primary;
    if (showExpense) {
      final expenseValues = points.map((point) => point.expense).toList();
      final expenseLine = _smoothPath(expenseValues, position);
      final area = Path.from(expenseLine.path)
        ..lineTo(expenseLine.coordinates.last.dx, bottom)
        ..lineTo(expenseLine.coordinates.first.dx, bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              expenseColor.withValues(alpha: .22),
              expenseColor.withValues(alpha: .02),
            ],
          ).createShader(Rect.fromLTWH(left, top, width, height)),
      );
      _drawSeries(canvas, expenseLine, expenseValues, expenseColor);
    }
    if (showIncome) {
      final incomeValues = points.map((point) => point.income).toList();
      final incomeLine = _smoothPath(incomeValues, position);
      _drawSeries(canvas, incomeLine, incomeValues, AppColors.income);
    }

    final selectedPoint = points[selectedIndex];
    final selectedValue = showExpense
        ? selectedPoint.expense
        : selectedPoint.income;
    final current = position(selectedValue, selectedIndex);
    canvas.drawLine(
      Offset(current.dx, top),
      Offset(current.dx, bottom),
      Paint()
        ..color = AppColors.primaryDark.withValues(alpha: .25)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      current,
      7,
      Paint()
        ..color = (showIncome ? AppColors.warning : AppColors.primary)
            .withValues(alpha: .16),
    );
    canvas.drawCircle(
      current,
      4,
      Paint()..color = showIncome ? AppColors.warning : AppColors.primary,
    );
    canvas.drawCircle(
      current,
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final label = bubbleLabel ?? MoneyFormatter.whole(selectedValue);
    final bubbleText = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
        ).copyWith(fontFamily: fontFamily),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 100);
    final bubbleWidth = bubbleText.width + 12;
    final bubbleLeft = (current.dx - bubbleWidth / 2)
        .clamp(left, size.width - bubbleWidth)
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
    for (final index in labels) {
      final date = points[index].date;
      _label(
        canvas,
        year ? '${date.month}月' : '${date.month}/${date.day}',
        Offset(
          (position(0, index).dx - 13).clamp(left - 8, size.width - 33),
          bottom + 10,
        ),
        maxWidth: 40,
      );
    }
  }

  SmoothLinePath _smoothPath(
    List<double> values,
    Offset Function(double value, int index) position,
  ) => buildMonotoneSmoothLinePath(values: values, position: position);

  void _drawSeries(
    Canvas canvas,
    SmoothLinePath line,
    List<double> values,
    Color color,
  ) {
    canvas.drawPath(
      line.path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (points.length < 33) {
      for (var i = 0; i < values.length; i++) {
        canvas.drawCircle(line.coordinates[i], 2, Paint()..color = color);
      }
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
  bool shouldRepaint(covariant CashflowTrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selected != selected ||
      oldDelegate.showIncome != showIncome ||
      oldDelegate.showExpense != showExpense ||
      oldDelegate.year != year ||
      oldDelegate.bubbleLabel != bubbleLabel;
}
