import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/features/budgets/data/budget_period_provider.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/budget_period.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/budgets/presentation/budget_page.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';

const capture = bool.fromEnvironment('BUDGET_CAPTURE');
void main() {
  setUpAll(() async {
    if (!capture) return;
    for (final font in {
      'Microsoft YaHei': 'C:/Windows/Fonts/msyh.ttc',
      'MaterialIcons': 'E:/jizhang_1/tools/flutter_sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await File(font.value).readAsBytes();
      await (FontLoader(
        font.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final theme in [BuiltInThemes.freshGreen, BuiltInThemes.liquidGlass]) {
    for (final scenario in ['normal', 'dark', 'large', 'empty', 'error']) {
      testWidgets(
        '${theme.id} budget $scenario stays usable and scrolls above fixed actions',
        (tester) async {
          final large = scenario == 'large', empty = scenario == 'empty';
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(large ? 320 : 390, large ? 720 : 873);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var base = scenario == 'dark'
              ? AppTheme.dark(theme)
              : AppTheme.light(theme);
          if (capture)
            base = base.copyWith(
              textTheme: base.textTheme.apply(fontFamily: 'Microsoft YaHei'),
            );
          final settings = _Settings();
          final state = scenario == 'error'
              ? AsyncError<BudgetPeriodOverview>(
                  StateError('offline'),
                  StackTrace.current,
                )
              : AsyncData(fixture(empty: empty));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                budgetPeriodOverviewProvider.overrideWith(
                  (ref, period) => state,
                ),
                goalsProvider.overrideWithValue(
                  AsyncData(empty ? [] : fixtureGoals),
                ),
                appSettingsRepositoryProvider.overrideWithValue(settings),
              ],
              child: MaterialApp(
                theme: base,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 30),
                    viewPadding: const EdgeInsets.only(top: 30),
                    textScaler: TextScaler.linear(large ? 1.6 : 1),
                  ),
                  child: child!,
                ),
                home: const RepaintBoundary(
                  key: ValueKey('capture'),
                  child: BudgetPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (capture) {
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 200));
            });
            await tester.pumpAndSettle();
            await screenshot(tester, '${theme.id}-$scenario');
          }
          expect(tester.takeException(), isNull);
          expect(find.text('编辑预算'), findsOneWidget);
          if (scenario == 'error') {
            expect(find.text('重新加载'), findsOneWidget);
          } else {
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('budget-switch-smartAdvice')),
              180,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const ValueKey('budget-switch-smartAdvice')),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('budget-switch-smartAdvice')),
            );
            await tester.pumpAndSettle();
            expect(settings.values.values, contains('0'));
            await tester.scrollUntilVisible(
              find.text('智能建议已关闭'),
              100,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(find.text('智能建议已关闭'), findsOneWidget);
            if (capture && large)
              await screenshot(tester, '${theme.id}-large-bottom');
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  testWidgets(
    'month and year selector update actual aggregation; custom cancel preserves selection',
    (tester) async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      final now = DateTime.now(),
          repo = DriftBudgetRepository(db, const SafeToSpendService());
      await repo.setBudget(monthKey: budgetMonthKey(now), amount: 1000);
      await repo.setBudget(
        monthKey: budgetMonthKey(DateTime(now.year, now.month == 1 ? 2 : 1)),
        amount: 500,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(theme: AppTheme.light(), home: const BudgetPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('${now.year}年${now.month}月'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('budget-period-year')));
      await tester.pumpAndSettle();
      expect(find.text('${now.year}年'), findsOneWidget);
      final context = tester.element(find.byType(BudgetPage));
      final container = ProviderScope.containerOf(context);
      expect(
        container
            .read(budgetPeriodOverviewProvider(BudgetPeriod.year(now)))
            .value!
            .overview
            .total!
            .budget
            .amount,
        1500,
      );
      await tester.tap(find.byKey(const ValueKey('budget-period-custom')));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      Navigator.pop(tester.element(find.byType(DateRangePickerDialog)));
      await tester.pumpAndSettle();
      expect(find.text('${now.year}年'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('budget-period-month')));
      await tester.pumpAndSettle();
      // Switching from a year starts at January; choose an explicit month to edit elsewhere.
      expect(find.text('${now.year}年1月'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

Future<void> screenshot(WidgetTester tester, String name) =>
    tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          )
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('.agent/budget-prototype-20261004/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
BudgetPeriodOverview fixture({bool empty = false}) {
  final date = DateTime(2024, 5),
      period = BudgetPeriod.month(DateTime(2024, 5));
  BudgetProgress row(
    String? id,
    double amount,
    double spent, [
    Category? category,
  ]) => BudgetProgress(
    budget: Budget(
      id: id ?? 'total',
      monthKey: '2024-05',
      categoryId: id,
      amount: amount,
      createdAt: date,
      updatedAt: date,
    ),
    category: category,
    used: spent,
    remaining: amount - spent,
    percentage: spent / amount,
    remainingDays: 12,
    dailyAvailable: (amount - spent) / 12,
    status: spent / amount >= .8
        ? BudgetAlertStatus.nearLimit
        : BudgetAlertStatus.normal,
  );
  final specs = [
    ('food', '餐饮', 1500.0, 1280.0),
    ('transport', '交通', 800.0, 320.0),
    ('shopping', '购物', 1500.0, 980.0),
    ('daily', '日用', 800.0, 450.0),
  ];
  return BudgetPeriodOverview(
    period: period,
    spent: empty ? 0 : 3900,
    previousSpent: 3900 / 1.12,
    previousCategorySpending: {'food': 1280 / 1.12},
    overview: BudgetOverview(
      total: empty ? null : row(null, 6000, 3900),
      categories: empty
          ? []
          : [
              for (final (id, name, amount, spent) in specs)
                row(
                  id,
                  amount,
                  spent,
                  Category(
                    id: id,
                    name: name,
                    icon: id,
                    type: CategoryType.expense,
                    sortOrder: 0,
                    isDefault: true,
                    isArchived: false,
                  ),
                ),
            ],
    ),
  );
}

final fixtureGoals = [
  Goal(
    id: 'travel',
    name: '旅行基金',
    goalType: GoalType.travel,
    icon: 'travel',
    targetAmount: 6000,
    currentAmount: 3000,
    targetDate: DateTime(2024, 10),
    status: GoalStatus.active,
    createdAt: DateTime(2024),
    milestones: [],
    description: '去看更大的世界',
  ),
  Goal(
    id: 'emergency',
    name: '应急基金',
    goalType: GoalType.emergencyFund,
    icon: 'emergency',
    targetAmount: 20000,
    currentAmount: 8000,
    targetDate: DateTime(2024, 12),
    status: GoalStatus.active,
    createdAt: DateTime(2024),
    milestones: [],
    description: '给未来多一份安心',
  ),
];

class _Settings implements AppSettingsRepository {
  final values = <String, String>{};
  @override
  Future<String?> get(String key) async => values[key];
  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}
