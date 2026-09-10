import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/models/dashboard_snapshot.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/features/home/presentation/home_cards.dart';

import 'support/reference_capture.dart';

void main() {
  for (final size in [const Size(320, 700), const Size(393, 844)]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'amount visibility remains usable at $size and scale $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await loadReferenceFonts(tester);
          final boundaryKey = ValueKey('amount-boundary-${size.width}-$scale');
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                theme: AppTheme.light(),
                home: Scaffold(
                  body: RepaintBoundary(
                    key: boundaryKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: HomeSpendingGoalCard(
                        snapshot: DashboardSnapshot(
                          safeToSpend: 123456789,
                          forecastBalance: 0,
                          hasBudget: true,
                          month: DateTime(2026, 9),
                          income: 0,
                          expense: 0,
                          budgetAmount: 123456789,
                          availableAmount: 0,
                          remainingDays: 21,
                          goalReservation: 0,
                        ),
                        goal: Goal(
                          id: 'visibility-goal',
                          name: '应急储备',
                          icon: 'savings',
                          targetAmount: 160000,
                          currentAmount: 68500,
                          targetDate: DateTime(2027),
                          status: GoalStatus.active,
                          createdAt: DateTime(2026),
                          milestones: const [],
                        ),
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
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('home-hide-amount')),
            findsOneWidget,
          );
          expect(find.text('¥123,456,789'), findsOneWidget);
          await captureReference(
            tester,
            find.byKey(boundaryKey),
            'home-amount-visible-${size.width}-$scale',
          );

          final card = find.byKey(const ValueKey('home-spending-card'));
          final budget = find.byKey(const ValueKey('home-budget-area'));
          final calculation = find.byKey(const ValueKey('home-calculation'));
          final beforeCard = tester.getRect(card);
          final beforeBudget = tester.getRect(budget);
          final beforeCalculation = tester.getRect(calculation);
          await tester.tap(find.byKey(const ValueKey('home-hide-amount')));
          await tester.pump();
          expect(find.text('¥ ••••••'), findsOneWidget);
          expect(find.text('¥123,456,789'), findsNothing);
          expect(find.textContaining('¥••••••'), findsWidgets);
          await captureReference(
            tester,
            find.byKey(boundaryKey),
            'home-amount-hidden-${size.width}-$scale',
          );
          expect(tester.getRect(card), beforeCard);
          expect(tester.getRect(budget), beforeBudget);
          expect(
            tester.getRect(calculation).topLeft,
            beforeCalculation.topLeft,
          );
          expect(tester.getRect(calculation).height, beforeCalculation.height);
          await tester.tap(find.byKey(const ValueKey('home-hide-amount')));
          await tester.pump();
          expect(find.text('¥123,456,789'), findsOneWidget);
          expect(find.text('¥ ••••••'), findsNothing);
          expect(tester.getRect(card), beforeCard);
          expect(tester.getRect(budget), beforeBudget);
          expect(
            tester.getRect(calculation).topLeft,
            beforeCalculation.topLeft,
          );
          expect(tester.getRect(calculation).height, beforeCalculation.height);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
