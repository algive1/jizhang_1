import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/goals/domain/goal_forecast_service.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';

void main() {
  test(
    'initial savings and calibration never create a savings forecast',
    () async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      final repository = DriftGoalRepository(db);
      final goal = await repository.create(
        goal: _goal(),
        milestoneAmounts: [50, 100.50],
        initialAmount: 20,
      );
      final forecast = const GoalForecastService().forecast(
        goal,
        windowDays: 30,
      );
      expect(forecast.averageDailyDeposit, 0);
      expect(forecast.estimatedCompletionDate, isNull);
      await repository.adjustCurrentAmount(goalId: goal.id, newAmount: 30.51);
      final adjusted = (await repository.getById(goal.id))!;
      expect(adjusted.currentAmount, 30.51);
      expect(
        const GoalForecastService()
            .forecast(adjusted, windowDays: 30)
            .estimatedCompletionDate,
        isNull,
      );
    },
  );

  test(
    'invalid milestone edit rolls back target and preserves metadata',
    () async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      final repository = DriftGoalRepository(db);
      await repository.create(
        goal: _goal(),
        milestoneAmounts: [50, 100.50],
        initialAmount: 20,
      );
      await expectLater(
        repository.update(_goal(target: 200.25), milestoneAmounts: [75]),
        throwsArgumentError,
      );
      var loaded = (await repository.getById('review-goal'))!;
      expect(loaded.targetAmount, 100.50);
      expect(loaded.milestones.map((m) => m.amount), [50, 100.50]);
      loaded = await repository.update(
        _goal(target: 200.25),
        milestoneAmounts: [75, 200.25],
      );
      expect(loaded.targetAmount, 200.25);
      expect(loaded.milestones.last.amount, 200.25);
      expect(loaded.bookId, 'retained-book');
      expect(loaded.createdBy, 'retained-owner');
      expect(loaded.version, 2);
    },
  );

  test(
    'current month compares matching dates and excludes future expenses',
    () {
      const service = StatisticalAnalysisService();
      final now = DateTime(2026, 9, 8, 12);
      final snapshot = service.analyze([
        _expense('previous-matched', DateTime(2026, 8, 7), 60),
        _expense('previous-later', DateTime(2026, 8, 25), 400),
        _expense('current', DateTime(2026, 9, 7), 100),
        _expense('future-today', DateTime(2026, 9, 8, 22), 300),
        _expense('future-month', DateTime(2026, 9, 20), 800),
      ], now: now);
      expect(snapshot.totalExpense, 100);
      expect(snapshot.previousRegularExpense, 60);
      expect(snapshot.previousRange.endExclusive, DateTime(2026, 8, 9));
      final noBaseline = service.analyze([
        _expense('new-user', DateTime(2026, 9, 7), 100),
      ], now: now);
      expect(noBaseline.hasComparableBaseline, isFalse);
      expect(noBaseline.insights, isEmpty);
    },
  );
}

Goal _goal({double target = 100.50}) => Goal(
  id: 'review-goal',
  name: '保留小数',
  icon: 'savings',
  targetAmount: target,
  currentAmount: 0,
  targetDate: DateTime(2027),
  status: GoalStatus.active,
  createdAt: DateTime(2026, 9, 1),
  milestones: const [],
  bookId: 'retained-book',
  createdBy: 'retained-owner',
);

TransactionRecord _expense(String id, DateTime date, double amount) =>
    TransactionRecord(
      id: id,
      bookId: 'book',
      type: TransactionType.expense,
      amount: amount,
      accountId: 'cash',
      categoryId: 'food',
      occurredAt: date,
      createdAt: date,
      updatedAt: date,
    );
