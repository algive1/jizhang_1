import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/models/dashboard_snapshot.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/widgets/sliding_segmented_control.dart';
import 'package:jizhang_app/features/home/presentation/home_cards.dart';

void main() {
  for (final hasBudget in [true, false]) {
    for (final hasGoal in [true, false]) {
      testWidgets(
        'combination card budget=$hasBudget goal=$hasGoal at 320dp and large text',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final snapshot = DashboardSnapshot(
            safeToSpend: 1234567.89,
            forecastBalance: -7654321.09,
            hasBudget: hasBudget,
            month: DateTime(2026, 9),
            income: 1234567.89,
            expense: 8888888.98,
            budgetAmount: 10000000,
            availableAmount: -1234567.89,
            remainingDays: 1,
            goalReservation: 50000,
          );
          final goal = Goal(
            id: 'goal',
            name: '为全家人一起准备的旅行与新家这是一个非常长的目标名称',
            icon: 'home',
            targetAmount: 9000000.99,
            currentAmount: 3000000.01,
            targetDate: DateTime(2027),
            status: GoalStatus.active,
            createdAt: DateTime(2026),
            milestones: [
              for (var i = 1; i <= 12; i++)
                GoalMilestone(
                  id: '$i',
                  goalId: 'goal',
                  amount: i * 750000,
                  title: '$i',
                  order: i,
                  isCompleted: i <= 4,
                ),
            ],
          );
          var budgetTaps = 0;
          var goalTaps = 0;
          var calculationTaps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.6)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        HomeSpendingGoalCard(
                          snapshot: snapshot,
                          goal: hasGoal ? goal : null,
                          onBudget: () => budgetTaps++,
                          onGoal: () => goalTaps++,
                          onCalculation: () => calculationTaps++,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('home-budget-area')));
          await tester.ensureVisible(
            find.byKey(const ValueKey('home-goal-area')),
          );
          await tester.tap(find.byKey(const ValueKey('home-goal-area')));
          await tester.ensureVisible(
            find.byKey(const ValueKey('home-calculation')),
          );
          await tester.tap(find.byKey(const ValueKey('home-calculation')));
          expect((budgetTaps, goalTaps, calculationTaps), (1, 1, 1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'selection capsule moves continuously and swipe changes selection',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) => SlidingSegmentedControl<int>(
                    items: const [(0, '支出'), (1, '收入'), (2, '转账')],
                    selected: selected,
                    onChanged: (value) => setState(() => selected = value),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final capsule = find.descendant(
        of: find.byType(AnimatedAlign),
        matching: find.byType(DecoratedBox),
      );
      final initialX = tester.getTopLeft(capsule).dx;
      await tester.tap(find.byKey(const ValueKey('segment-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final middleX = tester.getTopLeft(capsule).dx;
      await tester.pumpAndSettle();
      final endX = tester.getTopLeft(capsule).dx;
      expect(middleX, greaterThan(initialX));
      expect(middleX, lessThan(endX));
      await tester.drag(
        find.byType(SlidingSegmentedControl<int>),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      expect(selected, 2);
    },
  );
}
