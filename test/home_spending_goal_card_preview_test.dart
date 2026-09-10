import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/models/dashboard_snapshot.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/features/home/presentation/home_cards.dart';

import 'support/reference_capture.dart';

void main() {
  testWidgets('renders isolated home spending and goal card preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await loadReferenceFonts(tester);

    final goal = Goal(
      id: 'preview-goal',
      name: '买车计划',
      icon: 'car',
      targetAmount: 160000,
      currentAmount: 68500,
      targetDate: DateTime(2027),
      status: GoalStatus.active,
      createdAt: DateTime(2026),
      milestones: [
        _milestone('20k', 20000),
        _milestone('40k', 40000),
        _milestone('100k', 100000),
      ],
    );
    final snapshot = DashboardSnapshot(
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
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().copyWith(
          textTheme: AppTheme.light().textTheme.apply(
            fontFamily: 'Reference Latin',
            fontFamilyFallback: const ['PingFang SC'],
          ),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFFFAF9F4),
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('home-card-preview-boundary'),
              child: SizedBox(
                width: 357,
                child: HomeSpendingGoalCard(
                  snapshot: snapshot,
                  goal: goal,
                  bookType: BookType.personal,
                  onBudget: () {},
                  onGoal: () {},
                  onCalculation: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/home_living_scene.png'),
        tester.element(find.byType(HomeSpendingGoalCard)),
      );
    });
    await tester.pumpAndSettle();
    await captureReference(
      tester,
      find.byKey(const ValueKey('home-card-preview-boundary')),
      'home-spending-goal-card',
    );
  });
}

GoalMilestone _milestone(String id, double amount) => GoalMilestone(
  id: id,
  goalId: 'preview-goal',
  amount: amount,
  title: id,
  order: amount.toInt(),
  isCompleted: amount < 68500,
);
