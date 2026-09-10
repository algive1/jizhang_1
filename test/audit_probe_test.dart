import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/app/app.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/widgets/goal_progress_card.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/intelligence/data/bill_inbox_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/voice/application/speech_recognition_service.dart';

void main() {
  testWidgets(
    'home spending card expands for screenshot size without a budget',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpApp(
        tester,
        budgetsOverride: const [],
        transactionsOverride: const [],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('收支结余'), findsOneWidget);
      expect(find.text('设置本月预算后计算 ›'), findsOneWidget);
    },
  );

  testWidgets('home spending card keeps budget status visible at large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 873));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final errors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await _pumpApp(tester, transactionsOverride: const []);
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previousErrorHandler;
    }

    expect(
      errors,
      isEmpty,
      reason: errors.map((error) => error.toString()).join('\n'),
    );
    expect(find.text('收支结余'), findsOneWidget);
    expect(find.text('设置本月预算后计算 ›'), findsNothing);
  });

  testWidgets('audit compact layout with enlarged text and keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpApp(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Home with enlarged text');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Quick add with enlarged text',
    );
    tester.view.viewInsets = FakeViewPadding(
      bottom: 280 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Quick add with system keyboard',
    );
  });

  testWidgets('audit home layout matrix reports every Flutter layout error', (
    tester,
  ) async {
    const cases = [
      (Size(320, 568), 1.3, false),
      (Size(320, 568), 1.6, false),
      (Size(320, 568), 1.3, true),
      (Size(320, 568), 1.6, true),
      (Size(360, 800), 1.3, false),
      (Size(360, 800), 1.6, false),
      (Size(360, 800), 1.3, true),
      (Size(360, 800), 1.6, true),
      (Size(393, 873), 1.3, false),
      (Size(393, 873), 1.6, false),
      (Size(393, 873), 1.3, true),
      (Size(393, 873), 1.6, true),
    ];

    for (final testCase in cases) {
      final (size, textScale, hasBudget) = testCase;
      await tester.binding.setSurfaceSize(size);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      final errors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await _pumpApp(
          tester,
          budgetsOverride: hasBudget ? null : const [],
          transactionsOverride: const [],
        );
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = previousErrorHandler;
      }
      expect(
        errors,
        isEmpty,
        reason:
            '${size.width}x${size.height} scale=$textScale '
            'budget=$hasBudget\n'
            '${errors.map(_layoutErrorSummary).join('\n')}',
      );
    }
  });

  testWidgets('audit goal card at compact sizes reports every layout error', (
    tester,
  ) async {
    const cases = [
      (Size(320, 568), 1.3),
      (Size(320, 568), 1.6),
      (Size(360, 800), 1.3),
      (Size(360, 800), 1.6),
      (Size(393, 873), 1.3),
      (Size(393, 873), 1.6),
    ];
    for (final testCase in cases) {
      final (size, textScale) = testCase;
      await tester.binding.setSurfaceSize(size);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      final errors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [GoalProgressCard(goal: _auditGoal)],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = previousErrorHandler;
      }
      expect(
        errors,
        isEmpty,
        reason:
            'goal card ${size.width}x${size.height} scale=$textScale\n'
            '${errors.map(_layoutErrorSummary).join('\n')}',
      );
    }
  });
}

final _auditGoal = Goal(
  id: 'audit-goal',
  name: '买车计划',
  goalType: GoalType.majorPurchase,
  icon: 'majorPurchase',
  targetAmount: 160000,
  currentAmount: 68500,
  targetDate: DateTime(2027, 12),
  status: GoalStatus.active,
  createdAt: DateTime(2025),
  milestones: const [
    GoalMilestone(
      id: 'audit-milestone-1',
      goalId: 'audit-goal',
      amount: 20000,
      title: '¥20,000',
      order: 0,
      isCompleted: true,
    ),
    GoalMilestone(
      id: 'audit-milestone-2',
      goalId: 'audit-goal',
      amount: 40000,
      title: '¥40,000',
      order: 1,
      isCompleted: true,
    ),
    GoalMilestone(
      id: 'audit-milestone-3',
      goalId: 'audit-goal',
      amount: 68500,
      title: '¥68,500',
      order: 2,
      isCompleted: true,
    ),
    GoalMilestone(
      id: 'audit-milestone-4',
      goalId: 'audit-goal',
      amount: 100000,
      title: '¥100,000',
      order: 3,
      isCompleted: false,
    ),
    GoalMilestone(
      id: 'audit-milestone-5',
      goalId: 'audit-goal',
      amount: 160000,
      title: '¥160,000',
      order: 4,
      isCompleted: false,
    ),
  ],
);

String _layoutErrorSummary(FlutterErrorDetails error) {
  final message = error.exceptionAsString();
  final overflow = RegExp(r'OVERFLOWED BY ([0-9.]+) PIXELS')
      .firstMatch(message);
  final direction = RegExp(r'(RIGHT|BOTTOM) OVERFLOWED').firstMatch(message);
  return 'direction=${direction?.group(1) ?? 'unknown'} '
      'pixels=${overflow?.group(1) ?? 'unknown'}\n$message';
}

Future<AppDatabase> _pumpApp(
  WidgetTester tester, {
  SpeechRecognitionService? speechService,
  List<Budget>? budgetsOverride,
  List<TransactionRecord>? transactionsOverride,
}) async {
  final database = createMemoryDatabase();
  await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);
  final transactions =
      transactionsOverride ??
      await DriftTransactionRepository(database).getAll();
  final accounts = await DriftAccountRepository(database).getActive();
  final categories = await DriftCategoryRepository(database).getActive();
  final goals = await DriftGoalRepository(database).getAll();
  final budgets =
      budgetsOverride ??
      await DriftBudgetRepository(
        database,
        const SafeToSpendService(),
      ).getMonth(budgetMonthKey(DateTime.now()));
  final membership = await LocalOnlyMembershipRepository().getCurrent();
  addTearDown(database.close);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      transactionsProvider.overrideWithValue(AsyncData(transactions)),
      accountsProvider.overrideWithValue(AsyncData(accounts)),
      allAccountsProvider.overrideWithValue(AsyncData(accounts)),
      categoriesProvider.overrideWithValue(AsyncData(categories)),
      allCategoriesProvider.overrideWithValue(AsyncData(categories)),
      goalsProvider.overrideWithValue(AsyncData(goals)),
      currentMonthBudgetsProvider.overrideWithValue(AsyncData(budgets)),
      pendingInboxProvider.overrideWithValue(const AsyncData([])),
      membershipProvider.overrideWithValue(AsyncData(membership)),
      if (speechService != null)
        speechRecognitionServiceProvider.overrideWithValue(speechService),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const JizhangApp()),
  );
  return database;
}
