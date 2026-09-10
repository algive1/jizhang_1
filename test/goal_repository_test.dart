import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/goals/domain/goal_forecast_service.dart';
import 'package:jizhang_app/features/goals/domain/goal_milestone_service.dart';

void main() {
  test('new goals append after the current book order', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    await DatabaseSeeder(db).seedIfNeeded();
    final repository = DriftGoalRepository(db);
    final before = await repository.getAll();
    final maxSortOrder = before
        .where((goal) => goal.bookId == 'book-personal')
        .fold<int>(
          -1,
          (max, goal) => goal.sortOrder > max ? goal.sortOrder : max,
        );
    final now = DateTime.now();
    final created = await repository.create(
      goal: Goal(
        id: 'goal-sort-append',
        name: '追加排序目标',
        icon: 'savings',
        targetAmount: 100,
        currentAmount: 0,
        targetDate: DateTime(now.year + 1),
        status: GoalStatus.active,
        createdAt: now,
        milestones: const [],
        bookId: 'book-personal',
      ),
      milestoneAmounts: const [100],
      initialAmount: 0,
    );

    expect(created.sortOrder, maxSortOrder + 1);
    final ordered = await repository.getAll();
    expect(
      ordered.where((goal) => goal.status == GoalStatus.active).last.id,
      'goal-sort-append',
    );
  });

  test('milestone suggestions are dynamic and always end at the target', () {
    final milestones = const GoalMilestoneService().suggest(160000);
    expect(milestones, [20000, 40000, 60000, 100000, 160000]);
    expect(const GoalMilestoneService().suggest(8500).last, 8500);
  });

  test(
    'contributions cross milestones once and complete without deletion',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftGoalRepository(database);
      final now = DateTime.now();
      final created = await repository.create(
        goal: Goal(
          id: 'goal-test',
          name: '测试目标',
          goalType: GoalType.majorPurchase,
          icon: 'savings',
          targetAmount: 100,
          currentAmount: 20,
          targetDate: DateTime(now.year + 1),
          status: GoalStatus.active,
          createdAt: now,
          milestones: const [],
        ),
        milestoneAmounts: const [25, 50, 75, 100],
        initialAmount: 20,
      );
      expect(created.currentAmount, 20);

      final crossed = await repository.contribute(
        goalId: created.id,
        amount: 35,
        type: GoalContributionType.deposit,
      );
      expect(crossed.goal.currentAmount, 55);
      expect(crossed.newlyCompletedMilestoneIds, hasLength(2));
      expect(crossed.goalJustCompleted, isFalse);
      expect(
        crossed.goal.milestones
            .where((item) => item.amount <= 50)
            .every(
              (item) => item.completedAt != null && !item.celebrationShown,
            ),
        isTrue,
      );

      await repository.markCelebrationsShown(
        goalId: created.id,
        milestoneIds: crossed.newlyCompletedMilestoneIds,
        goalCompletion: false,
      );
      final afterCelebration = await repository.getById(created.id);
      expect(
        afterCelebration!.milestones
            .where(
              (item) => crossed.newlyCompletedMilestoneIds.contains(item.id),
            )
            .every((item) => item.celebrationShown),
        isTrue,
      );

      final withdrawn = await repository.contribute(
        goalId: created.id,
        amount: 30,
        type: GoalContributionType.withdraw,
      );
      expect(withdrawn.goal.currentAmount, 25);
      expect(withdrawn.goal.status, GoalStatus.active);

      final completed = await repository.contribute(
        goalId: created.id,
        amount: 75,
        type: GoalContributionType.deposit,
      );
      expect(completed.goal.currentAmount, 100);
      expect(completed.goal.status, GoalStatus.completed);
      expect(completed.goalJustCompleted, isTrue);
      expect(await repository.getById(created.id), isNotNull);

      final finalMilestone = completed.goal.milestones.last;
      expect(
        () => repository.deleteMilestone(created.id, finalMilestone.id),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('goal forecast uses 30, 60 and 90 day contribution windows', () {
    final now = DateTime(2026, 8, 31);
    final goal = Goal(
      id: 'forecast',
      name: '预测目标',
      icon: 'savings',
      targetAmount: 600,
      currentAmount: 300,
      targetDate: DateTime(2027),
      status: GoalStatus.active,
      createdAt: now.subtract(const Duration(days: 100)),
      milestones: const [],
      contributions: [
        GoalContribution(
          id: 'deposit',
          goalId: 'forecast',
          amount: 300,
          type: GoalContributionType.deposit,
          createdAt: now.subtract(const Duration(days: 10)),
        ),
      ],
    );
    final forecasts = const GoalForecastService().allWindows(goal, now: now);
    expect(forecasts.map((item) => item.windowDays), [30, 60, 90]);
    expect(forecasts.first.averageDailyDeposit, 10);
    expect(
      forecasts.first.estimatedCompletionDate,
      now.add(const Duration(days: 30)),
    );
  });

  test('created goals and contributions survive reopening SQLite', () async {
    final directory = await Directory.systemTemp.createTemp('goal-reopen-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/goals.sqlite');
    var database = AppDatabase.forTesting(NativeDatabase(file));
    await DatabaseSeeder(database).seedIfNeeded();
    var repository = DriftGoalRepository(database);
    final now = DateTime.now();
    await repository.create(
      goal: Goal(
        id: 'persistent-goal',
        name: '持久目标',
        icon: 'savings',
        targetAmount: 1000,
        currentAmount: 0,
        targetDate: DateTime(now.year + 1),
        status: GoalStatus.active,
        createdAt: now,
        milestones: const [],
      ),
      milestoneAmounts: const [250, 500, 750, 1000],
      initialAmount: 0,
    );
    await repository.contribute(
      goalId: 'persistent-goal',
      amount: 88,
      type: GoalContributionType.deposit,
    );
    await database.close();

    database = AppDatabase.forTesting(NativeDatabase(file));
    repository = DriftGoalRepository(database);
    expect((await repository.getById('persistent-goal'))!.currentAmount, 88);
    await database.close();
  });
}
