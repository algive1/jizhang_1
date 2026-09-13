import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/models/dashboard_snapshot.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/features/home/data/home_data.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
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
          final card = find.byKey(const ValueKey('home-spending-card'));
          expect(
            find.byKey(const ValueKey('home-hide-amount')),
            findsOneWidget,
          );
          expect(find.text('¥123,456,789'), findsOneWidget);
          if (scale == 1.0) {
            final amountText = tester.getRect(find.text('¥123,456,789'));
            final decorationText = find.text('好好花钱\n也好好生活');
            expect(decorationText, findsNothing);
            expect(
              amountText.right,
              lessThanOrEqualTo(tester.getRect(card).right),
            );
          }
          await captureReference(
            tester,
            find.byKey(boundaryKey),
            'home-amount-visible-${size.width}-$scale',
          );

          final budget = find.byKey(const ValueKey('home-budget-area'));
          final calculation = find.byKey(const ValueKey('home-calculation'));
          final beforeCard = tester.getRect(card);
          final beforeBudget = tester.getRect(budget);
          final beforeCalculation = tester.getRect(calculation);
          await tester.tap(find.byKey(const ValueKey('home-hide-amount')));
          await tester.pump();
          expect(find.text('••••'), findsOneWidget);
          expect(find.text('¥123,456,789'), findsNothing);
          final mask = tester.widget<Text>(find.text('••••'));
          expect(mask.style?.fontSize, 13);
          expect(mask.style?.letterSpacing, 3);
          expect(find.text('¥68,500\n当前'), findsOneWidget);
          expect(find.text('¥160,000\n目标'), findsOneWidget);
          if (scale == 1.0) {
            final hiddenAmountText = tester.getRect(find.text('••••'));
            expect(
              hiddenAmountText.right,
              lessThanOrEqualTo(tester.getRect(card).right),
            );
          }
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
          expect(find.text('••••'), findsNothing);
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

  test('persists home amount visibility independently for each book', () async {
    final settings = _MemoryAppSettings({'home.amountsHidden.book-a': '1'});
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    final controller = container.read(homeAmountVisibilityProvider.notifier);
    await controller.ensureLoaded('book-a');
    await controller.ensureLoaded('book-b');
    expect(container.read(homeAmountVisibilityProvider), {
      'book-a': true,
      'book-b': false,
    });

    await controller.setHidden('book-b', true);
    expect(settings.values['home.amountsHidden.book-b'], '1');
    expect(container.read(homeAmountVisibilityProvider)['book-a'], isTrue);
    expect(container.read(homeAmountVisibilityProvider)['book-b'], isTrue);
  });

  test('stores today, goal and asset visibility independently', () async {
    final settings = _MemoryAppSettings({
      'home.amountsHidden.today.book-a': '1',
      'home.amountsHidden.assets.book-a': '1',
    });
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    final controller = container.read(homeCardVisibilityProvider.notifier);
    await controller.ensureLoaded('book-a');
    final initial = container.read(homeCardVisibilityProvider)['book-a'];
    expect(initial?.today, isTrue);
    expect(initial?.goal, isFalse);
    expect(initial?.assets, isTrue);

    await controller.setHidden('book-a', HomeAmountSection.goal, true);
    expect(settings.values['home.amountsHidden.goal.book-a'], '1');
    final allHidden = container.read(homeCardVisibilityProvider)['book-a'];
    expect(allHidden?.today, isTrue);
    expect(allHidden?.goal, isTrue);
    expect(allHidden?.assets, isTrue);

    await controller.setHidden('book-a', HomeAmountSection.today, false);
    expect(settings.values['home.amountsHidden.today.book-a'], '0');
    expect(
      container.read(homeCardVisibilityProvider)['book-a']?.assets,
      isTrue,
    );
  });

  testWidgets('today and goal eyes mask only their own card amounts', (
    tester,
  ) async {
    var todayHidden = false;
    var goalHidden = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => HomeSpendingGoalCard(
              snapshot: DashboardSnapshot(
                safeToSpend: 1234,
                forecastBalance: 0,
                hasBudget: true,
                month: DateTime(2026, 9),
                income: 0,
                expense: 0,
                budgetAmount: 2000,
                availableAmount: 1234,
                remainingDays: 20,
                goalReservation: 0,
              ),
              goal: Goal(
                id: 'privacy-goal',
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
              todayAmountHidden: todayHidden,
              goalAmountHidden: goalHidden,
              onTodayAmountHiddenChanged: (value) => setState(() {
                todayHidden = value;
              }),
              onGoalAmountHiddenChanged: (value) => setState(() {
                goalHidden = value;
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-hide-amount')));
    await tester.pump();
    expect(find.text('••••'), findsOneWidget);
    expect(find.textContaining('¥68,500'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('home-goal-hide-amount')));
    await tester.pump();
    expect(find.text('¥•••• / ¥••••'), findsOneWidget);
    expect(find.textContaining('¥160,000'), findsNothing);
    expect(find.textContaining('¥68,500'), findsNothing);
  });
}

class _MemoryAppSettings implements AppSettingsRepository {
  _MemoryAppSettings(this.values);

  final Map<String, String> values;

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}
