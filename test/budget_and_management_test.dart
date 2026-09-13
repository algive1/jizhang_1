import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'budget progress follows real expense transactions and alert thresholds',
    () {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      final repository = DriftBudgetRepository(
        database,
        const SafeToSpendService(),
      );
      final now = DateTime(2026, 8, 20);
      final budget = Budget(
        id: 'total',
        monthKey: '2026-08',
        amount: 1000,
        createdAt: now,
        updatedAt: now,
      );

      BudgetOverview overviewFor(double spent) {
        return repository.calculateOverview(
          budgets: [budget],
          transactions: [_expense(spent, now)],
          categories: const [],
          now: now,
        );
      }

      expect(overviewFor(799).total!.status, BudgetAlertStatus.normal);
      expect(overviewFor(800).total!.status, BudgetAlertStatus.nearLimit);
      expect(overviewFor(1001).total!.status, BudgetAlertStatus.exceeded);
      expect(overviewFor(800).total!.remaining, 200);
      expect(overviewFor(800).total!.remainingDays, 12);
      expect(overviewFor(800).total!.dailyAvailable, closeTo(16.67, .01));
    },
  );

  test(
    'account edits preserve transaction-derived balance and archive safely',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftAccountRepository(database);
      final existing = (await repository.getActive()).first;

      final updated = await repository.update(
        Account(
          id: existing.id,
          name: '日常${existing.name}',
          type: existing.type,
          balance: 999999,
          currency: existing.currency,
          icon: existing.icon,
          color: existing.color,
          sortOrder: existing.sortOrder,
          isArchived: false,
          identifierSuffix: existing.identifierSuffix,
          assetForm: existing.assetForm,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      expect(updated.balance, existing.balance);
      await repository.archive(existing.id);
      expect(
        (await repository.getActive()).where((item) => item.id == existing.id),
        isEmpty,
      );
    },
  );

  test('account order persists through the repository', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftAccountRepository(database);
    final accounts = await repository.getActive();
    final reordered = accounts.reversed.map((account) => account.id).toList();

    await repository.reorder(reordered);

    expect(
      (await repository.getActive()).map((account) => account.id).toList(),
      reordered,
    );
  });

  test(
    'archiving a parent category hides its children without deleting rows',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftCategoryRepository(database);
      final nowId = DateTime.now().microsecondsSinceEpoch;
      final parent = Category(
        id: 'custom-parent-$nowId',
        name: '家庭',
        icon: 'home',
        type: CategoryType.expense,
        sortOrder: 99,
        isDefault: false,
        isArchived: false,
      );
      final child = Category(
        id: 'custom-child-$nowId',
        parentId: parent.id,
        name: '日用品',
        icon: 'shopping_bag',
        type: CategoryType.expense,
        sortOrder: 0,
        isDefault: false,
        isArchived: false,
      );
      await repository.create(parent);
      await repository.create(child);
      await repository.archive(parent.id);

      final activeIds = (await repository.getActive()).map((item) => item.id);
      expect(activeIds, isNot(contains(parent.id)));
      expect(activeIds, isNot(contains(child.id)));
      expect(await database.categoryDao.findById(parent.id), isNotNull);
      expect(await database.categoryDao.findById(child.id), isNotNull);
    },
  );

  test(
    'schema v1 migrates forward and creates budgets without deleting data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'jizhang-migration-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/migration.sqlite');
      final oldDatabase = sqlite.sqlite3.open(file.path);
      oldDatabase.execute(
        'CREATE TABLE accounts ('
        'id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, '
        'balance_in_cents INTEGER NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT "CNY", '
        'icon TEXT NOT NULL, color INTEGER NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0, '
        'is_archived INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
      );
      oldDatabase.execute(
        'CREATE TABLE categories ('
        'id TEXT NOT NULL PRIMARY KEY, parent_id TEXT, name TEXT NOT NULL, '
        'icon TEXT NOT NULL, type TEXT NOT NULL, sort_order INTEGER NOT NULL, '
        'is_default INTEGER NOT NULL, is_archived INTEGER NOT NULL)',
      );
      oldDatabase.execute(
        'CREATE TABLE goals ('
        'id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, icon TEXT NOT NULL, '
        'target_amount_in_cents INTEGER NOT NULL, '
        'current_amount_in_cents INTEGER NOT NULL DEFAULT 0, '
        'target_date INTEGER NOT NULL, status TEXT NOT NULL DEFAULT "active", '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
        'description TEXT, cover_path TEXT)',
      );
      oldDatabase.execute(
        'CREATE TABLE transactions ('
        'id TEXT NOT NULL PRIMARY KEY)',
      );
      oldDatabase.execute(
        'CREATE TABLE goal_milestones (id TEXT PRIMARY KEY,goal_id TEXT NOT NULL,amount_in_cents INTEGER NOT NULL,title TEXT NOT NULL,sort_order INTEGER NOT NULL,completed_at INTEGER,celebration_shown INTEGER NOT NULL DEFAULT 0)',
      );
      oldDatabase.execute(
        'CREATE TABLE goal_contributions ('
        'id TEXT NOT NULL PRIMARY KEY)',
      );
      oldDatabase.execute(
        "INSERT INTO categories VALUES "
        "('kept', NULL, '保留分类', 'home', 'expense', 0, 1, 0)",
      );
      oldDatabase.execute(
        'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)',
      );
      oldDatabase.userVersion = 1;
      oldDatabase.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      expect(await migrated.budgetDao.getMonth('2026-08'), isEmpty);
      expect((await migrated.categoryDao.findById('kept'))?.name, '保留分类');
      await migrated.close();
    },
  );
}

TransactionRecord _expense(double amount, DateTime occurredAt) {
  return TransactionRecord(
    id: 'expense-$amount',
    bookId: 'book',
    type: TransactionType.expense,
    amount: amount,
    accountId: 'account',
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}
