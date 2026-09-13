import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/models/dashboard_snapshot.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/features/home/presentation/home_cards.dart';

void main() {
  testWidgets('privacy hides only primary amount and restores it', (
    tester,
  ) async {
    await _pumpCard(tester);
    expect(find.text('¥5,788'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-hide-amount')));
    await tester.pump();
    final contents = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .toList();
    expect(contents.every((content) => !content.contains('5,788')), isTrue);
    expect(contents.any((content) => content.contains('9,588')), isTrue);
    expect(contents.any((content) => content.contains('68,500')), isTrue);
    expect(contents.any((content) => content.contains('160,000')), isTrue);
    await tester.tap(find.byKey(const ValueKey('home-hide-amount')));
    await tester.pump();
    expect(find.text('¥5,788'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('budget card exposes the real monthly budget entry', (
    tester,
  ) async {
    var budgetTaps = 0;
    await _pumpCard(tester, onBudget: () => budgetTaps++);
    expect(find.text('本周预算'), findsNothing);
    expect(find.text('¥5,788'), findsOneWidget);
    expect(budgetTaps, 0);
    await tester.tap(find.text('本月预算'));
    expect(budgetTaps, 1);
  });

  testWidgets(
    'many milestones retain current and target with bounded node count',
    (tester) async {
      await _pumpCard(tester);
      expect(find.text('¥68,500\n当前'), findsOneWidget);
      expect(find.text('¥160,000\n目标'), findsOneWidget);
      expect(find.text('¥40,000\n已完成'), findsOneWidget);
      expect(find.text('¥60,000\n已完成'), findsOneWidget);
      expect(find.text('¥80,000\n待达成'), findsOneWidget);
      expect(find.text('¥20,000\n已完成'), findsOneWidget);
    },
  );
}

Future<void> _pumpCard(WidgetTester tester, {VoidCallback? onBudget}) async {
  await tester.binding.setSurfaceSize(const Size(393, 650));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final goal = Goal(
    id: 'qa',
    name: '买车计划',
    icon: 'car',
    targetAmount: 160000,
    currentAmount: 68500,
    targetDate: DateTime(2027),
    status: GoalStatus.active,
    createdAt: DateTime(2026),
    milestones: [
      for (var i = 1; i <= 8; i++)
        GoalMilestone(
          id: '$i',
          goalId: 'qa',
          amount: i * 20000,
          title: '节点$i',
          order: i,
          isCompleted: i <= 3,
        ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HomeSpendingGoalCard(
              snapshot: DashboardSnapshot(
                safeToSpend: 5788,
                forecastBalance: 9588,
                hasBudget: true,
                month: DateTime(2026, 9),
                income: 12000,
                expense: 2412,
                budgetAmount: 10000,
                availableAmount: 5788,
                remainingDays: 21,
                goalReservation: 0,
              ),
              goal: goal,
              onBudget: onBudget ?? () {},
              onGoal: () {},
              onCalculation: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
