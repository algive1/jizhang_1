import '../../../core/utils/entity_id.dart';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/goal.dart';
import '../../books/data/book_repository.dart';
import '../domain/goal_forecast_service.dart';
import '../domain/goal_milestone_service.dart';

class GoalContributionResult {
  const GoalContributionResult({
    required this.goal,
    required this.newlyCompletedMilestoneIds,
    required this.goalJustCompleted,
  });

  final Goal goal;
  final List<String> newlyCompletedMilestoneIds;
  final bool goalJustCompleted;
}

abstract interface class GoalRepository {
  Stream<List<Goal>> watchAll();
  Future<void> reorder(List<String> goalIds);
  Future<void> setMonthlyReservation(String goalId, double amount);
  Future<List<Goal>> getAll();
  Future<Goal?> getById(String id);
  Future<Goal> create({
    required Goal goal,
    required List<double> milestoneAmounts,
    required double initialAmount,
  });
  Future<Goal> update(Goal goal, {List<double>? milestoneAmounts});
  Future<void> archive(String goalId);
  Future<void> restore(String goalId);
  Future<GoalContributionResult> contribute({
    required String goalId,
    required double amount,
    required GoalContributionType type,
    String? note,
    String? sourceTransactionId,
  });
  Future<GoalContributionResult> adjustCurrentAmount({
    required String goalId,
    required double newAmount,
    String? note,
  });
  Future<void> replaceMilestones(String goalId, List<double> amounts);
  Future<void> deleteMilestone(String goalId, String milestoneId);
  Future<void> markCelebrationsShown({
    required String goalId,
    required List<String> milestoneIds,
    required bool goalCompletion,
  });
}

class DriftGoalRepository implements GoalRepository {
  DriftGoalRepository(this._database, {this.bookId});
  final String? bookId;

  final AppDatabase _database;

  @override
  Stream<List<Goal>> watchAll() {
    return _database.goalDao.watchChanges().asyncMap((_) => getAll());
  }

  @override
  Future<List<Goal>> getAll() async {
    final rows = await _database.goalDao.getAllGoals(bookId: bookId);
    final goals = await Future.wait(rows.map(_mapGoal));
    goals.sort((a, b) {
      final statusComparison = _statusOrder(a.status)
          .compareTo(_statusOrder(b.status));
      return statusComparison != 0
          ? statusComparison
          : a.sortOrder != b.sortOrder
          ? a.sortOrder.compareTo(b.sortOrder)
          : b.createdAt.compareTo(a.createdAt);
    });
    return goals;
  }

  @override
  Future<void> reorder(List<String> goalIds) async {
    if (goalIds.toSet().length != goalIds.length) {
      throw ArgumentError('Duplicate goal IDs');
    }
    await _database.transaction(() async {
      for (var index = 0; index < goalIds.length; index++) {
        final goal = await _requireGoal(goalIds[index]);
        await (_database.update(
          _database.goalEntries,
        )..where((row) => row.id.equals(goal.id))).write(
          GoalEntriesCompanion(
            sortOrder: Value(index),
            updatedAt: Value(DateTime.now()),
            version: Value(goal.version + 1),
          ),
        );
      }
    });
  }

  @override
  Future<void> setMonthlyReservation(String goalId, double amount) async {
    if (!amount.isFinite || amount < 0 || amount > 1000000000000) {
      throw ArgumentError('Invalid reservation');
    }
    await _database.transaction(() async {
      final goal = await _requireGoal(goalId);
      await (_database.update(
        _database.goalEntries,
      )..where((row) => row.id.equals(goalId))).write(
        GoalEntriesCompanion(
          monthlyReservationInCents: Value(_toCents(amount)),
          updatedAt: Value(DateTime.now()),
          version: Value(goal.version + 1),
        ),
      );
    });
  }

  @override
  Future<Goal?> getById(String id) async {
    final row = await _database.goalDao.findGoal(id);
    return row == null || !await _database.canAccessBook(row.bookId)
        ? null
        : _mapGoal(row);
  }

  @override
  Future<Goal> create({
    required Goal goal,
    required List<double> milestoneAmounts,
    required double initialAmount,
  }) async {
    if (!goal.targetAmount.isFinite || goal.targetAmount <= 0) {
      throw ArgumentError('Target amount must be > 0');
    }
    if (!initialAmount.isFinite || initialAmount < 0) {
      throw ArgumentError('Initial amount cannot be negative');
    }
    final validatedMilestones = _validateMilestones(
      milestoneAmounts,
      goal.targetAmount,
    );
    await _ensureBookForWrite(goal.bookId);
    await _database.transaction(() async {
      if (await _database.goalDao.findGoal(goal.id) != null) {
        throw StateError('Goal ${goal.id} already exists');
      }
      final now = DateTime.now();
      final status = initialAmount >= goal.targetAmount
          ? GoalStatus.completed
          : GoalStatus.active;
      final existingGoals = await _database.goalDao.getAllGoals(
        bookId: goal.bookId,
      );
      final nextSortOrder = existingGoals.isEmpty
          ? 0
          : existingGoals
                    .map((item) => item.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      await _database.goalDao.insertGoal(
        _toGoalCompanion(
          goal,
          currentAmount: initialAmount,
          status: status,
          updatedAt: now,
          completionCelebrationShown: status == GoalStatus.completed,
          sortOrder: nextSortOrder,
        ),
      );
      for (var index = 0; index < validatedMilestones.length; index++) {
        final amount = validatedMilestones[index];
        final completed = initialAmount >= amount;
        await _database.goalDao.insertMilestone(
          GoalMilestoneEntriesCompanion.insert(
            id: '${goal.id}-milestone-$index',
            goalId: goal.id,
            amountInCents: _toCents(amount),
            title: '¥${amount.toStringAsFixed(2)}',
            sortOrder: index,
            completedAt: completed ? Value(now) : const Value.absent(),
            celebrationShown: Value(completed),
          ),
        );
      }
      if (initialAmount > 0) {
        await _database.goalDao.insertContribution(
          GoalContributionEntriesCompanion.insert(
            id: '${goal.id}-initial-${newEntityId()}',
            goalId: goal.id,
            amountInCents: _toCents(initialAmount),
            type: GoalContributionType.adjustment.name,
            createdAt: now,
            note: const Value('初始金额'),
            contributorUserId: Value(_database.currentActor),
          ),
        );
      }
    });
    return (await getById(goal.id))!;
  }

  @override
  Future<Goal> update(Goal goal, {List<double>? milestoneAmounts}) async {
    if (!goal.targetAmount.isFinite || goal.targetAmount <= 0) {
      throw ArgumentError('Target amount must be > 0');
    }
    await _database.transaction(() async {
      final existing = await _requireGoal(goal.id);
      final currentAmount = await _currentAmount(goal.id);
      final status = currentAmount >= goal.targetAmount
          ? GoalStatus.completed
          : goal.status == GoalStatus.archived
          ? GoalStatus.archived
          : GoalStatus.active;
      await _database.goalDao.upsertGoal(
        _toGoalCompanion(
          goal,
          currentAmount: currentAmount,
          status: status,
          updatedAt: DateTime.now(),
          completionCelebrationShown: existing.completionCelebrationShown,
          version: existing.version + 1,
          sortOrder: existing.sortOrder,
          monthlyReservation: existing.monthlyReservationInCents / 100,
          bookId: existing.bookId,
          createdBy: existing.createdBy,
          updatedBy: goal.updatedBy ?? existing.updatedBy,
        ),
      );
      if (milestoneAmounts != null) {
        await _replaceMilestonesInTransaction(
          goal.id,
          milestoneAmounts,
          currentAmount: currentAmount,
        );
      }
    });
    return (await getById(goal.id))!;
  }

  @override
  Future<void> archive(String goalId) =>
      _setStatus(goalId, GoalStatus.archived);

  @override
  Future<void> restore(String goalId) async {
    final goal = await getById(goalId);
    if (goal == null) throw StateError('Goal $goalId not found');
    if (goal.status != GoalStatus.archived) return;
    final status = goal.currentAmount >= goal.targetAmount
        ? GoalStatus.completed
        : GoalStatus.active;
    await _setStatus(goalId, status);
  }

  Future<void> _setStatus(String goalId, GoalStatus status) async {
    await _database.transaction(() async {
      final existing = await _requireGoal(goalId);
      if (existing.status == status.name) return;
      final currentAmount = await _currentAmount(goalId);
      await _database.goalDao.upsertGoal(
        GoalEntriesCompanion(
          id: Value(existing.id),
          name: Value(existing.name),
          goalType: Value(existing.goalType),
          icon: Value(existing.icon),
          targetAmountInCents: Value(existing.targetAmountInCents),
          currentAmountInCents: Value(_toCents(currentAmount)),
          targetDate: Value(existing.targetDate),
          status: Value(status.name),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(DateTime.now()),
          description: Value(existing.description),
          coverPath: Value(existing.coverPath),
          completionCelebrationShown: Value(
            existing.completionCelebrationShown,
          ),
          bookId: Value(existing.bookId),
          createdBy: Value(existing.createdBy),
          updatedBy: Value(_database.currentActor),
          version: Value(existing.version + 1),
          sortOrder: Value(existing.sortOrder),
          monthlyReservationInCents: Value(existing.monthlyReservationInCents),
        ),
      );
    });
  }

  @override
  Future<GoalContributionResult> contribute({
    required String goalId,
    required double amount,
    required GoalContributionType type,
    String? note,
    String? sourceTransactionId,
  }) async {
    if (type == GoalContributionType.adjustment) {
      throw ArgumentError('Use adjustCurrentAmount for adjustments');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be > 0');
    }
    final signedAmount = type == GoalContributionType.withdraw
        ? -amount
        : amount;
    return _recordContribution(
      goalId: goalId,
      signedAmount: signedAmount,
      storedAmount: amount,
      type: type,
      note: note,
      sourceTransactionId: sourceTransactionId,
    );
  }

  @override
  Future<GoalContributionResult> adjustCurrentAmount({
    required String goalId,
    required double newAmount,
    String? note,
  }) async {
    if (!newAmount.isFinite || newAmount < 0) {
      throw ArgumentError.value(newAmount, 'newAmount', 'must be >= 0');
    }
    return _database.transaction(() async {
      await _requireGoal(goalId);
      final current = await _currentAmount(goalId);
      final difference = newAmount - current;
      if (difference == 0) {
        final goal = await getById(goalId);
        if (goal == null) throw StateError('Goal $goalId not found');
        return GoalContributionResult(
          goal: goal,
          newlyCompletedMilestoneIds: const [],
          goalJustCompleted: false,
        );
      }
      return _recordContributionInTransaction(
        goalId: goalId,
        signedAmount: difference,
        storedAmount: difference,
        type: GoalContributionType.adjustment,
        note: note,
      );
    });
  }

  Future<GoalContributionResult> _recordContribution({
    required String goalId,
    required double signedAmount,
    required double storedAmount,
    required GoalContributionType type,
    String? note,
    String? sourceTransactionId,
  }) async {
    return _database.transaction(() async {
      return _recordContributionInTransaction(
        goalId: goalId,
        signedAmount: signedAmount,
        storedAmount: storedAmount,
        type: type,
        note: note,
        sourceTransactionId: sourceTransactionId,
      );
    });
  }

  Future<GoalContributionResult> _recordContributionInTransaction({
    required String goalId,
    required double signedAmount,
    required double storedAmount,
    required GoalContributionType type,
    String? note,
    String? sourceTransactionId,
  }) async {
    List<String> newlyCompleted = const [];
    var goalJustCompleted = false;
    final goal = await _requireGoal(goalId);
    final oldAmount = await _currentAmount(goalId);
    final newAmount = oldAmount + signedAmount;
    if (newAmount < 0) {
      throw StateError('Goal amount cannot become negative');
    }
    final now = DateTime.now();
    await _database.goalDao.insertContribution(
      GoalContributionEntriesCompanion.insert(
        id: '$goalId-contribution-${newEntityId()}',
        goalId: goalId,
        amountInCents: _toCents(storedAmount),
        type: type.name,
        sourceTransactionId: Value(sourceTransactionId),
        createdAt: now,
        note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
        contributorUserId: Value(_database.currentActor),
      ),
    );
    final milestones = await _database.goalDao.getMilestones(goalId);
    final completed = <String>[];
    for (final milestone in milestones) {
      if (oldAmount < milestone.amountInCents / 100 &&
          newAmount >= milestone.amountInCents / 100 &&
          milestone.completedAt == null) {
        completed.add(milestone.id);
        await _database.goalDao.upsertMilestone(
          GoalMilestoneEntriesCompanion(
            id: Value(milestone.id),
            goalId: Value(milestone.goalId),
            amountInCents: Value(milestone.amountInCents),
            title: Value(milestone.title),
            sortOrder: Value(milestone.sortOrder),
            completedAt: Value(now),
            celebrationShown: const Value(false),
          ),
        );
      }
    }
    newlyCompleted = completed;
    goalJustCompleted =
        oldAmount < goal.targetAmountInCents / 100 &&
        newAmount >= goal.targetAmountInCents / 100;
    final newStatus = newAmount >= goal.targetAmountInCents / 100
        ? GoalStatus.completed
        : GoalStatus.active;
    await _database.goalDao.upsertGoal(
      GoalEntriesCompanion(
        id: Value(goal.id),
        name: Value(goal.name),
        goalType: Value(goal.goalType),
        icon: Value(goal.icon),
        targetAmountInCents: Value(goal.targetAmountInCents),
        currentAmountInCents: Value(_toCents(newAmount)),
        targetDate: Value(goal.targetDate),
        status: Value(newStatus.name),
        createdAt: Value(goal.createdAt),
        updatedAt: Value(now),
        description: Value(goal.description),
        coverPath: Value(goal.coverPath),
        completionCelebrationShown: Value(
          goalJustCompleted ? false : goal.completionCelebrationShown,
        ),
        bookId: Value(goal.bookId),
        createdBy: Value(goal.createdBy),
        updatedBy: Value(_database.currentActor),
        version: Value(goal.version + 1),
        sortOrder: Value(goal.sortOrder),
        monthlyReservationInCents: Value(goal.monthlyReservationInCents),
      ),
    );
    return GoalContributionResult(
      goal: (await getById(goalId))!,
      newlyCompletedMilestoneIds: newlyCompleted,
      goalJustCompleted: goalJustCompleted,
    );
  }

  @override
  Future<void> replaceMilestones(String goalId, List<double> amounts) async {
    final goal = await getById(goalId);
    if (goal == null) throw StateError('Goal $goalId not found');
    final validated = _validateMilestones(amounts, goal.targetAmount);
    await _database.transaction(() async {
      await _replaceMilestonesInTransaction(
        goalId,
        validated,
        currentAmount: goal.currentAmount,
      );
    });
  }

  Future<void> _replaceMilestonesInTransaction(
    String goalId,
    List<double> amounts, {
    required double currentAmount,
  }) async {
    final existing = await _database.goalDao.getMilestones(goalId);
    final goal = await _database.goalDao.findGoal(goalId);
    if (goal == null) throw StateError('Goal $goalId not found');
    final validated = _validateMilestones(
      amounts,
      goal.targetAmountInCents / 100,
    );
    for (final milestone in existing) {
      if (milestone.amountInCents == goal.targetAmountInCents) continue;
      if (!validated.any(
        (amount) => _toCents(amount) == milestone.amountInCents,
      )) {
        await _database.goalDao.deleteMilestone(milestone.id);
      }
    }
    for (var index = 0; index < validated.length; index++) {
      final amount = validated[index];
      final matched = existing
          .where((item) => item.amountInCents == _toCents(amount))
          .firstOrNull;
      final now = DateTime.now();
      await _database.goalDao.upsertMilestone(
        GoalMilestoneEntriesCompanion(
          id: Value(matched?.id ?? '$goalId-milestone-${newEntityId()}-$index'),
          goalId: Value(goalId),
          amountInCents: Value(_toCents(amount)),
          title: Value('¥${amount.toStringAsFixed(2)}'),
          sortOrder: Value(index),
          completedAt: Value(
            matched?.completedAt ?? (currentAmount >= amount ? now : null),
          ),
          celebrationShown: Value(
            matched?.celebrationShown ?? currentAmount >= amount,
          ),
        ),
      );
    }
  }

  @override
  Future<void> deleteMilestone(String goalId, String milestoneId) async {
    final goal = await _requireGoal(goalId);
    final milestone = await _database.goalDao.findMilestone(milestoneId);
    if (milestone == null || milestone.goalId != goalId) return;
    if (milestone.amountInCents == goal.targetAmountInCents) {
      throw StateError('The final goal milestone cannot be deleted');
    }
    await _database.goalDao.deleteMilestone(milestoneId);
  }

  @override
  Future<void> markCelebrationsShown({
    required String goalId,
    required List<String> milestoneIds,
    required bool goalCompletion,
  }) async {
    await _database.transaction(() async {
      final goal = await _requireGoal(goalId);
      for (final id in milestoneIds) {
        final milestone = await _database.goalDao.findMilestone(id);
        if (milestone == null || milestone.goalId != goalId) continue;
        await _database.goalDao.upsertMilestone(
          GoalMilestoneEntriesCompanion(
            id: Value(milestone.id),
            goalId: Value(milestone.goalId),
            amountInCents: Value(milestone.amountInCents),
            title: Value(milestone.title),
            sortOrder: Value(milestone.sortOrder),
            completedAt: Value(milestone.completedAt),
            celebrationShown: const Value(true),
          ),
        );
      }
      if (goalCompletion) {
        await _database.goalDao.upsertGoal(
          GoalEntriesCompanion(
            id: Value(goal.id),
            name: Value(goal.name),
            goalType: Value(goal.goalType),
            icon: Value(goal.icon),
            targetAmountInCents: Value(goal.targetAmountInCents),
            currentAmountInCents: Value(goal.currentAmountInCents),
            targetDate: Value(goal.targetDate),
            status: Value(goal.status),
            createdAt: Value(goal.createdAt),
            updatedAt: Value(DateTime.now()),
            description: Value(goal.description),
            coverPath: Value(goal.coverPath),
            completionCelebrationShown: const Value(true),
            sortOrder: Value(goal.sortOrder),
            monthlyReservationInCents: Value(goal.monthlyReservationInCents),
            bookId: Value(goal.bookId),
            version: Value(goal.version),
            createdBy: Value(goal.createdBy),
            updatedBy: Value(goal.updatedBy),
          ),
        );
      }
    });
  }

  Future<double> _currentAmount(String goalId) async {
    final contributions = await _database.goalDao.getContributions(goalId);
    final cents = contributions.fold<int>(0, (total, contribution) {
      return switch (GoalContributionType.values.byName(contribution.type)) {
        GoalContributionType.deposit => total + contribution.amountInCents,
        GoalContributionType.withdraw => total - contribution.amountInCents,
        GoalContributionType.adjustment => total + contribution.amountInCents,
      };
    });
    return cents / 100;
  }

  Future<GoalEntity> _requireGoal(String id) async {
    final goal = await _database.goalDao.findGoal(id);
    if (goal == null || (bookId != null && goal.bookId != bookId)) {
      throw StateError('目标不属于当前账本');
    }
    if (!await _database.canAccessBook(goal.bookId)) {
      throw StateError('目标所属账本当前不可用');
    }
    return goal;
  }

  Future<void> _ensureBookForWrite(String id) async {
    if (bookId != null && id != bookId) {
      throw ArgumentError('目标必须属于当前账本');
    }
    if (!await _database.canAccessBook(id)) {
      throw StateError('目标所属账本当前不可用');
    }
  }

  Future<Goal> _mapGoal(GoalEntity row) async {
    final milestones = await _database.goalDao.getMilestones(row.id);
    final contributionRows = await _database.goalDao.getContributions(row.id);
    final contributions = contributionRows
        .map(
          (item) => GoalContribution(
            id: item.id,
            goalId: item.goalId,
            amount: item.amountInCents / 100,
            type: GoalContributionType.values.byName(item.type),
            sourceTransactionId: item.sourceTransactionId,
            createdAt: item.createdAt,
            note: item.note,
            contributorUserId: item.contributorUserId,
          ),
        )
        .toList(growable: false);
    final currentInCents = contributionRows.fold<int>(0, (total, contribution) {
      return switch (GoalContributionType.values.byName(contribution.type)) {
        GoalContributionType.deposit => total + contribution.amountInCents,
        GoalContributionType.withdraw => total - contribution.amountInCents,
        GoalContributionType.adjustment => total + contribution.amountInCents,
      };
    });
    return Goal(
      id: row.id,
      name: row.name,
      goalType: GoalType.values.byName(row.goalType),
      icon: row.icon,
      targetAmount: row.targetAmountInCents / 100,
      currentAmount: currentInCents / 100,
      targetDate: row.targetDate,
      status: GoalStatus.values.byName(row.status),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      description: row.description,
      coverPath: row.coverPath,
      completionCelebrationShown: row.completionCelebrationShown,
      contributions: contributions,
      bookId: row.bookId,
      version: row.version,
      sortOrder: row.sortOrder,
      monthlyReservation: row.monthlyReservationInCents / 100,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      milestones: milestones
          .map(
            (milestone) => GoalMilestone(
              id: milestone.id,
              goalId: milestone.goalId,
              amount: milestone.amountInCents / 100,
              title: milestone.title,
              order: milestone.sortOrder,
              isCompleted: currentInCents >= milestone.amountInCents,
              completedAt: milestone.completedAt,
              celebrationShown: milestone.celebrationShown,
            ),
          )
          .toList(growable: false),
    );
  }

  GoalEntriesCompanion _toGoalCompanion(
    Goal goal, {
    required double currentAmount,
    required GoalStatus status,
    required DateTime updatedAt,
    required bool completionCelebrationShown,
    int? version,
    int? sortOrder,
    double? monthlyReservation,
    String? bookId,
    String? createdBy,
    String? updatedBy,
  }) {
    return GoalEntriesCompanion(
      id: Value(goal.id),
      name: Value(goal.name.trim()),
      goalType: Value(goal.goalType.name),
      icon: Value(goal.icon),
      targetAmountInCents: Value(_toCents(goal.targetAmount)),
      currentAmountInCents: Value(_toCents(currentAmount)),
      targetDate: Value(goal.targetDate),
      status: Value(status.name),
      createdAt: Value(goal.createdAt),
      updatedAt: Value(updatedAt),
      description: Value(goal.description),
      coverPath: Value(goal.coverPath),
      completionCelebrationShown: Value(completionCelebrationShown),
      bookId: Value(bookId ?? goal.bookId),
      version: Value(version ?? goal.version),
      sortOrder: Value(sortOrder ?? goal.sortOrder),
      monthlyReservationInCents: Value(
        _toCents(monthlyReservation ?? goal.monthlyReservation),
      ),
      createdBy: Value(createdBy ?? goal.createdBy ?? _database.currentActor),
      updatedBy: Value(_database.currentActor),
    );
  }

  List<double> _validateMilestones(List<double> amounts, double targetAmount) {
    final result =
        amounts
            .where(
              (amount) =>
                  amount.isFinite && amount > 0 && amount <= targetAmount,
            )
            .toSet()
            .toList()
          ..sort();
    if (result.isEmpty || _toCents(result.last) != _toCents(targetAmount)) {
      throw ArgumentError('Milestones must include the final target amount');
    }
    return result;
  }

  int _toCents(double amount) => (amount * 100).round();

  int _statusOrder(GoalStatus status) => switch (status) {
    GoalStatus.active => 0,
    GoalStatus.paused => 1,
    GoalStatus.completed => 2,
    GoalStatus.archived => 3,
  };
}

final goalMilestoneServiceProvider = Provider<GoalMilestoneService>(
  (ref) => const GoalMilestoneService(),
);

final goalForecastServiceProvider = Provider<GoalForecastService>(
  (ref) => const GoalForecastService(),
);

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return DriftGoalRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});

final goalsProvider = StreamProvider<List<Goal>>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  final bookId = ref.watch(activeBookIdProvider);
  yield* DriftGoalRepository(
    ref.watch(databaseProvider),
    bookId: bookId,
  ).watchAll();
});
