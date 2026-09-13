import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/models/dashboard_snapshot.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/books/presentation/book_selector.dart';
import 'package:jizhang_app/features/home/data/home_data.dart';
import 'package:jizhang_app/features/home/presentation/home_cards.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';

void main() {
  testWidgets('390dp cards meet compact height targets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final snapshot = DashboardSnapshot(
      safeToSpend: 50,
      forecastBalance: 200,
      hasBudget: true,
      month: DateTime.now(),
      income: 1000,
      expense: 800,
      budgetAmount: 2000,
      availableAmount: 1200,
      remainingDays: 20,
      goalReservation: 0,
    );
    final goal = Goal(
      id: 'goal',
      name: '一家人的旅行',
      icon: 'travel',
      targetAmount: 10000,
      currentAmount: 2500,
      targetDate: DateTime(2027),
      status: GoalStatus.active,
      createdAt: DateTime(2026),
      milestones: [
        for (final amount in [1000.0, 3000.0, 10000.0])
          GoalMilestone(
            id: '$amount',
            goalId: 'goal',
            amount: amount,
            title: '$amount',
            order: 0,
            isCompleted: amount <= 2500,
          ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                HomeMonthlySummary(
                  snapshot: snapshot,
                  onTap: () {},
                  onYear: () {},
                  onMonth: () {},
                  onPrevious: () {},
                  onNext: () {},
                ),
                HomeSpendingGoalCard(
                  snapshot: snapshot,
                  goal: goal,
                  onBudget: () {},
                  onGoal: () {},
                  onCalculation: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(HomeMonthlySummary)).height,
      lessThanOrEqualTo(112),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home-spending-card'))).height,
      // The combined budget/goal card uses the reference layout height;
      // accessibility text and long fixture names may grow the upper section.
      lessThanOrEqualTo(400),
    );
    expect(tester.takeException(), isNull);
  });
  for (final layout in [
    (const Size(320, 700), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 1.6),
    (const Size(800, 320), 1.6),
  ]) {
    testWidgets('bookshelf switches and closes without overflow at $layout', (
      tester,
    ) async {
      final db = createMemoryDatabase();
      await DatabaseSeeder(db).seedIfNeeded();
      addTearDown(db.close);
      final repo = DriftBookRepository(db, LocalOnlyMembershipRepository());
      final family = await repo.create(
        name: '家庭一起生活与旅行的很长账本名称',
        type: BookType.family,
      );
      await repo.create(name: '企业经营', type: BookType.enterprise);
      await tester.binding.setSurfaceSize(layout.$1);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(layout.$2)),
              child: child!,
            ),
            home: const Scaffold(body: SafeArea(child: BookSelectorButton())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BookSelectorButton));
      await tester.pumpAndSettle();
      expect(find.text('选择账本'), findsOneWidget);
      final cover = find.text(family.name);
      await tester.ensureVisible(cover);
      await tester.tap(cover);
      await tester.pumpAndSettle();
      expect(container.read(activeBookIdProvider), family.id);
      expect(find.text('选择账本'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BookSelectorButton));
      await tester.pumpAndSettle();
      await tester.drag(find.text('记录生活  更好地生活').last, const Offset(0, 96));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('我的账本'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test(
    'month selection affects only top summary; book selection keeps month',
    () async {
      final db = createMemoryDatabase();
      await DatabaseSeeder(db).seedIfNeeded();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(booksProvider, (_, _) {});
      addTearDown(subscription.close);
      final family = await DriftBookRepository(
        db,
        LocalOnlyMembershipRepository(),
      ).create(name: '家庭', type: BookType.family);
      final now = DateTime.now(),
          month = DateTime(DateTime.now().year, DateTime.now().month);
      TransactionRecord record(
        String id,
        String book,
        DateTime at,
        double amount,
      ) => TransactionRecord(
        id: id,
        bookId: book,
        type: TransactionType.expense,
        amount: amount,
        accountId: scopedSeedId(book, SeedIds.cashAccount),
        occurredAt: at,
        createdAt: now,
        updatedAt: now,
      );
      await DriftTransactionRepository(db).createAll([
        record('this', 'book-personal', month, 10),
        record(
          'last',
          'book-personal',
          DateTime(month.year, month.month - 1),
          20,
        ),
        record(
          'two-before',
          'book-personal',
          DateTime(month.year, month.month - 2),
          30,
        ),
        record(
          'family-last',
          family.id,
          DateTime(month.year, month.month - 1),
          40,
        ),
      ]);
      await DriftBudgetRepository(
        db,
        const SafeToSpendService(),
      ).setBudget(monthKey: budgetMonthKey(month), amount: 1000);
      final txSubscription = container.listen(transactionsProvider, (_, _) {});
      addTearDown(txSubscription.close);
      final budgetSubscription = container.listen(
        currentMonthBudgetsProvider,
        (_, _) {},
      );
      addTearDown(budgetSubscription.close);
      await container.pump();
      await container.read(booksProvider.future);
      await container.read(transactionsProvider.future);
      await container.read(currentMonthBudgetsProvider.future);
      final today = container.read(dashboardSnapshotProvider).safeToSpend;
      final selected = container.read(selectedHomeMonthProvider.notifier);
      selected.select(DateTime(month.year, month.month - 1));
      expect(container.read(homeMonthlySummaryProvider).expense, 20);
      expect(container.read(dashboardSnapshotProvider).safeToSpend, today);
      selected.select(DateTime(month.year, month.month - 2));
      expect(container.read(homeMonthlySummaryProvider).expense, 30);
      expect(container.read(dashboardSnapshotProvider).safeToSpend, today);
      selected.select(DateTime(month.year, month.month - 1));
      await container.read(activeBookIdProvider.notifier).select(family.id);
      await container.read(transactionsProvider.future);
      expect(container.read(homeMonthlySummaryProvider).expense, 40);
      expect(
        container.read(selectedHomeMonthProvider),
        DateTime(month.year, month.month - 1),
      );
      final leap = record('leap', 'book-personal', DateTime(2024, 2, 29), 0.01);
      expect(monthlySummary([leap], DateTime(2024, 2), now).expense, .01);
      expect(monthlySummary([leap], DateTime(2024, 3), now).expense, 0);
      final yearEnd = record('dec', 'book-personal', DateTime(2025, 12, 31), 5);
      expect(monthlySummary([yearEnd], DateTime(2025, 12), now).expense, 5);
      expect(monthlySummary([yearEnd], DateTime(2026, 1), now).expense, 0);
      selected.select(DateTime(month.year, month.month + 1));
      expect(
        container.read(selectedHomeMonthProvider),
        DateTime(month.year, month.month - 1),
      );
    },
  );
}
