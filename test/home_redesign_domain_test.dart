import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/core/models/analysis.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';

void main() {
  test('explicit goal reservation and ordering persist through contributions and edits', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    await DatabaseSeeder(db).seedIfNeeded();
    final repository = DriftGoalRepository(db);
    final a = await repository.create(
      goal: _goal('a'),
      milestoneAmounts: [50, 100],
      initialAmount: 0,
    );
    await repository.create(
      goal: _goal('b'),
      milestoneAmounts: [50, 100],
      initialAmount: 0,
    );
    expect(a.monthlyReservation, 0);
    await repository.setMonthlyReservation('a', 12.34);
    await repository.reorder(['b', 'a']);
    expect((await repository.getAll()).map((g) => g.id), ['b', 'a']);
    await repository.update(
      a,
    ); // A stale form must not reset separate plan settings.
    await repository.contribute(
      goalId: 'a',
      amount: 10,
      type: GoalContributionType.deposit,
    );
    final updated = (await repository.getById('a'))!;
    expect(updated.monthlyReservation, 12.34);
    expect(updated.sortOrder, 1);
    expect(updated.currentAmount, 10);
    expect(await db.transactionDao.getActive(), isEmpty);
    await repository.setMonthlyReservation('a', 0);
    expect((await repository.getById('a'))!.monthlyReservation, 0);
    await expectLater(
      repository.setMonthlyReservation('a', -1),
      throwsArgumentError,
    );
    await expectLater(repository.reorder(['a', 'missing']), throwsStateError);
    expect((await repository.getAll()).map((g) => g.id), ['b', 'a']);
  });

  test('budget deducts explicit reservations, excludes future transactions and keeps cents', () {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    final now = DateTime(2026, 9, 30, 12);
    final repo = DriftBudgetRepository(db, const SafeToSpendService());
    BudgetOverview calculate(double reservation) => repo.calculateOverview(
      budgets: [
        Budget(
          id: 'budget',
          monthKey: '2026-09',
          amount: 100,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      transactions: [
        _transaction('spent', now, 0.01),
        _transaction('future', now.add(const Duration(hours: 1)), 90),
      ],
      categories: [],
      now: now,
      goalReservation: reservation,
    );
    final total = calculate(10.01).total!;
    expect(total.used, .01);
    expect(total.remaining, 89.98);
    expect(total.dailyAvailable, closeTo(89.98, .00001));
    expect(total.remainingDays, 1);
    expect(calculate(110).total!.dailyAvailable, 0);
    expect(calculate(110).total!.status, BudgetAlertStatus.exceeded);
    expect(calculate(0).total!.dailyAvailable, closeTo(99.99, .00001));
  });

  test('personal expense amount keeps budget and home totals reimbursement-aware', () {
    final now = DateTime(2026, 9, 20, 12);
    final pending = _transaction('pending', now, 500).copyWith(
      reimbursementStatus: ReimbursementStatus.pending,
      reimbursementAmount: 400,
    );
    final full = _transaction('full', now, 300).copyWith(
      reimbursementStatus: ReimbursementStatus.reimbursed,
      reimbursementAmount: 300,
    );
    final refund = _transaction('refund', now, 200).copyWith(
      refundStatus: RefundStatus.partial,
      refundAmount: 50,
    );

    expect(pending.personalExpenseAmount, 100);
    expect(full.personalExpenseAmount, 0);
    expect(refund.personalExpenseAmount, 150);
  });

  test('year trend includes actual expenses including large purchases, excludes transfers, future and other currencies', () {
    final now = DateTime(2026, 9, 8, 12);
    final snapshot = const StatisticalAnalysisService().analyze(
      [
        _transaction('jan', DateTime(2026, 1, 1), 5000),
        _transaction('today', now, 12.34),
        _transaction('future', DateTime(2026, 10), 999),
        _transaction('old', DateTime(2025, 12, 31), 999),
        _transaction('usd', now, 999, currency: 'USD'),
        _transaction('transfer', now, 999, type: TransactionType.transfer),
      ],
      period: AnalysisPeriod.currentYear,
      now: now,
    );
    expect(snapshot.totalExpense, 5012.34);
    expect(snapshot.expenseCount, 2);
    expect(snapshot.cashflowTrend.last.date, DateTime(2026, 9, 8));
    expect(
      snapshot.cashflowTrend.fold<double>(0, (v, p) => v + p.expense),
      5012.34,
    );
    expect(snapshot.previousRange.endExclusive, DateTime(2025, 9, 9));
  });

  test(
    'v7 migration preserves ledger data and defaults goal plans to opt-out',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'home-v7-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/ledger.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      await DatabaseSeeder(original).seedIfNeeded(includeDemoData: true);
      final originalRecords = await original.transactionDao.getActive();
      await original.close();
      final old = sqlite.sqlite3.open(file.path);
      for (final row in old.select(
        "SELECT name FROM sqlite_master WHERE type='trigger'",
      )) {
        old.execute('DROP TRIGGER ${row['name']}');
      }
      old.execute('ALTER TABLE goals DROP COLUMN sort_order');
      old.execute('ALTER TABLE goals DROP COLUMN monthly_reservation_in_cents');
      old.userVersion = 7;
      old.close();
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      final goals = await DriftGoalRepository(upgraded).getAll();
      expect(goals, isNotEmpty);
      expect(
        goals.every((g) => g.monthlyReservation == 0 && g.sortOrder == 0),
        isTrue,
      );
      expect(
        (await upgraded.transactionDao.getActive()).map((r) => r.id),
        originalRecords.map((r) => r.id),
      );
      await DriftGoalRepository(upgraded)
          .setMonthlyReservation(goals.first.id, 321.09);
      await upgraded.close();
      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await DriftGoalRepository(reopened).getById(goals.first.id))!
            .monthlyReservation,
        321.09,
      );
      await reopened.close();
    },
  );
}

Goal _goal(String id) => Goal(
  id: id,
  name: id,
  icon: 'savings',
  targetAmount: 100,
  currentAmount: 0,
  targetDate: DateTime(2027),
  status: GoalStatus.active,
  createdAt: DateTime(2026),
  milestones: [],
);
TransactionRecord _transaction(
  String id,
  DateTime date,
  double amount, {
  String currency = 'CNY',
  TransactionType type = TransactionType.expense,
}) => TransactionRecord(
  id: id,
  bookId: 'book-personal',
  type: type,
  amount: amount,
  currency: currency,
  accountId: 'account-cash',
  occurredAt: date,
  createdAt: date,
  updatedAt: date,
);
