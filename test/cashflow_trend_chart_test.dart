import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/analysis.dart';
import 'package:jizhang_app/core/widgets/cashflow_trend_chart.dart';
import 'package:jizhang_app/core/widgets/monotone_smooth_path.dart';

void main() {
  test('monotone path keeps markers aligned and avoids overshoot', () {
    final line = buildMonotoneSmoothLinePath(
      values: const [0, 100, 100, 50],
      position: (value, index) => Offset(index * 40, value),
    );

    expect(line.coordinates, const [
      Offset(0, 0),
      Offset(40, 100),
      Offset(80, 100),
      Offset(120, 50),
    ]);
    expect(line.path.getBounds().top, greaterThanOrEqualTo(0));
    expect(line.path.getBounds().bottom, lessThanOrEqualTo(100));
  });

  testWidgets('horizontal drag selects the nearest cashflow point', (
    tester,
  ) async {
    var selected = 0;
    final points = [
      for (var i = 0; i < 4; i++)
        CashflowPoint(DateTime(2026, 9, i + 1), 10.0 * i, 20.0 * i),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CashflowTrendChart(
              points: points,
              selected: selected,
              onSelected: (index) => selected = index,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final chart = tester.getRect(find.byType(CashflowTrendChart));
    await tester.dragFrom(
      Offset(chart.left + 44, chart.center.dy),
      Offset(chart.width - 52, 0),
    );
    expect(selected, points.length - 1);
  });
}
