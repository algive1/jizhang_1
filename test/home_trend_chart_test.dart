import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/analysis.dart';
import 'package:jizhang_app/features/home/presentation/home_trend_chart.dart';

void main() {
  testWidgets('home trend drag snaps to the nearest time point', (tester) async {
    var selected = 3;
    final points = [
      for (var i = 0; i < 7; i++)
        CashflowPoint(
          DateTime(2026, 9, 19 + i),
          100 + i * 20,
          60 + i * 15,
          totalAssets: 9800 + i * 10,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: SizedBox(
              width: 357,
              child: StatefulBuilder(
                builder: (context, setState) => HomeTrendChart(
                  points: points,
                  selected: selected,
                  onSelected: (index) => setState(() => selected = index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final chart = tester.getRect(find.byType(HomeTrendChart));
    await tester.dragFrom(
      Offset(chart.left + 34, chart.center.dy),
      Offset(chart.width - 44, 0),
    );
    await tester.pump();

    expect(selected, points.length - 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home trend renders the three prototype series and tooltip', (
    tester,
  ) async {
    final points = [
      CashflowPoint(
        DateTime(2026, 9, 21),
        280,
        140,
        totalAssets: 9780,
      ),
      CashflowPoint(
        DateTime(2026, 9, 22),
        320,
        186,
        totalAssets: 9860,
      ),
      CashflowPoint(
        DateTime(2026, 9, 23),
        260,
        80,
        totalAssets: 9820,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: SizedBox(
              width: 357,
              child: HomeTrendChart(
                points: points,
                selected: 1,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('9/22（周二）'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('资产'), findsOneWidget);
    expect(find.text('¥186'), findsOneWidget);
    expect(find.text('¥320'), findsOneWidget);
    expect(find.text('¥9,860'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
