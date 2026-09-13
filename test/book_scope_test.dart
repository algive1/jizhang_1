import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/models/transaction_intelligence.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/intelligence/data/bill_inbox_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test(
    'three book types isolate accounts, budgets, transfers and calibration',
    () async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      final books = DriftBookRepository(db, LocalOnlyMembershipRepository());
      final family = await books.create(name: '家庭', type: BookType.family);
      final company = await books.create(name: '企业', type: BookType.enterprise);
      final tx = DriftTransactionRepository(db);
      for (final book in ['book-personal', family.id, company.id]) {
        final accounts = DriftAccountRepository(db, bookId: book);
        final cash = (await accounts.getActive()).first;
        await accounts.reconcileBalance(cash.id, 100);
        await tx.create(record('expense-$book', book, cash.id, 10));
        final budget = DriftBudgetRepository(
          db,
          const SafeToSpendService(),
          bookId: book,
        );
        await budget.setBudget(
          monthKey: '2026-09',
          amount: book == family.id ? 200 : 300,
        );
        expect((await accounts.getActive()).first.balance, 90);
        expect(
          (await budget.getMonth('2026-09')).single.amount,
          book == family.id ? 200 : 300,
        );
      }
      expect(
        (await tx.getAll())
            .where((t) => t.type == TransactionType.adjustment)
            .map((t) => t.bookId)
            .toSet(),
        {'book-personal', family.id, company.id},
      );
      await expectLater(
        tx.create(record('wrong', family.id, SeedIds.cashAccount, 10)),
        throwsArgumentError,
      );
      await expectLater(
        tx.create(
          record(
            'wrong-transfer',
            family.id,
            scopedSeedId(family.id, SeedIds.cashAccount),
            10,
          ).copyWith(
            type: TransactionType.transfer,
            destinationAccountId: SeedIds.cashAccount,
          ),
        ),
        throwsArgumentError,
      );
      await tx.softDelete('expense-${family.id}');
      expect(
        (await DriftAccountRepository(
          db,
          bookId: family.id,
        ).getActive()).single.balance,
        100,
      );
      expect(
        (await DriftAccountRepository(
          db,
          bookId: company.id,
        ).getActive()).single.balance,
        90,
      );
      final scopedTransactions = DriftTransactionRepository(
        db,
        bookId: family.id,
      );
      await expectLater(
        scopedTransactions.create(
          record(
            'wrong-scoped-write',
            SeedIds.personalBook,
            SeedIds.cashAccount,
            1,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        DriftBillInboxRepository(db, bookId: family.id).add(
          reason: InboxReason.uncertainCategory,
          transactionId: 'expense-book-personal',
        ),
        throwsStateError,
      );
      await books.archive(company.id);
      expect(
        (await books.getForUser(SeedIds.localUser)).map((b) => b.id),
        isNot(contains(company.id)),
      );
    },
  );

  test('goals and contributions cannot cross book boundaries', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    await DatabaseSeeder(db).seedIfNeeded();
    final books = DriftBookRepository(db, LocalOnlyMembershipRepository());
    final family = await books.create(name: '家庭目标', type: BookType.family);
    final now = DateTime(2026, 9, 9);
    Goal goal(String id, String bookId) => Goal(
      id: id,
      name: id,
      icon: 'savings',
      targetAmount: 100,
      currentAmount: 0,
      targetDate: DateTime(2027),
      status: GoalStatus.active,
      createdAt: now,
      milestones: const [],
      bookId: bookId,
    );
    final personal = DriftGoalRepository(db, bookId: SeedIds.personalBook);
    final shared = DriftGoalRepository(db, bookId: family.id);
    await personal.create(
      goal: goal('personal-goal', SeedIds.personalBook),
      milestoneAmounts: const [100],
      initialAmount: 0,
    );
    await shared.create(
      goal: goal('family-goal', family.id),
      milestoneAmounts: const [100],
      initialAmount: 0,
    );
    expect((await personal.getAll()).map((item) => item.id), ['personal-goal']);
    expect((await shared.getAll()).map((item) => item.id), ['family-goal']);
    await expectLater(
      personal.contribute(
        goalId: 'family-goal',
        amount: 10,
        type: GoalContributionType.deposit,
      ),
      throwsStateError,
    );
    expect((await shared.getById('family-goal'))!.currentAmount, 0);
  });

  test('v8 split preserves total signed balances and deleted references after reopening', () async {
    final dir = await Directory.systemTemp.createTemp('book-scope-v8-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.sqlite');
    final db = AppDatabase.forTesting(NativeDatabase(file));
    await DatabaseSeeder(db).seedIfNeeded();
    final now = DateTime(2026, 9, 8);
    await db.familyDao.upsertBook(
      BookEntriesCompanion.insert(
        id: 'family',
        name: '家',
        type: 'family',
        ownerUserId: SeedIds.localUser,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final tx = DriftTransactionRepository(db);
    await tx.create(
      record('personal', 'book-personal', SeedIds.cashAccount, 10),
    );
    // Create the former v8 shared-account state without bypassing new repository validation.
    await db.customStatement(
      'INSERT INTO transactions (id,book_id,type,amount_in_cents,account_id,occurred_at,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)',
      [
        'shared',
        'family',
        'expense',
        2500,
        SeedIds.cashAccount,
        1900000000,
        1,
        1,
      ],
    );
    await db.customStatement(
      'INSERT INTO transactions (id,book_id,type,amount_in_cents,account_id,occurred_at,created_at,updated_at,deleted_at) VALUES (?,?,?,?,?,?,?,?,?)',
      ['deleted', 'family', 'expense', 500, SeedIds.cashAccount, 1, 1, 1, 2],
    );
    await db.customStatement(
      'UPDATE accounts SET balance_in_cents = 6500 WHERE id = ?',
      [SeedIds.cashAccount],
    );
    await DriftBudgetRepository(
      db,
      const SafeToSpendService(),
    ).setBudget(monthKey: '2026-09', amount: 200);
    await db.close();
    final old = sqlite.sqlite3.open(file.path);
    old.execute('PRAGMA foreign_keys=OFF');
    for (final row in old.select(
      "SELECT name FROM sqlite_master WHERE type='trigger'",
    )) {
      old.execute('DROP TRIGGER ${row['name']}');
    }
    for (final table in [
      'accounts',
      'categories',
      'merchant_rules',
      'inbox_items',
    ]) {
      old.execute('DROP INDEX IF EXISTS idx_${table}_book');
      if (table == 'merchant_rules') {
        final columns = old
            .select('PRAGMA table_info(merchant_rules)')
            .map((r) => r['name'])
            .where((n) => n != 'book_id')
            .join(',');
        old.execute('ALTER TABLE merchant_rules RENAME TO scoped_rules');
        old.execute(
          'CREATE TABLE merchant_rules AS SELECT $columns FROM scoped_rules',
        );
        old.execute('DROP TABLE scoped_rules');
      } else {
        if (table == 'accounts') {
          old.execute(
            'DROP INDEX IF EXISTS idx_accounts_book_identifier_suffix',
          );
        }
        old.execute('ALTER TABLE $table DROP COLUMN book_id');
      }
    }
    old.execute('ALTER TABLE accounts DROP COLUMN opening_balance_in_cents');
    old.execute('DROP INDEX idx_budget_scope');
    old.execute('ALTER TABLE budgets RENAME TO new_budgets');
    old.execute(
      'CREATE TABLE budgets (id TEXT PRIMARY KEY,month_key TEXT NOT NULL,category_id TEXT,amount_in_cents INTEGER NOT NULL,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,UNIQUE(month_key,category_id))',
    );
    old.execute(
      'INSERT INTO budgets SELECT id,month_key,category_id,amount_in_cents,created_at,updated_at FROM new_budgets',
    );
    old.execute('DROP TABLE new_budgets');
    old.userVersion = 8;
    old.close();
    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    expect(
      (await upgraded.accountDao.findById(SeedIds.cashAccount))!.balanceInCents,
      9000,
    );
    expect(
      (await upgraded.accountDao.findById(SeedIds.cashAccount))!
          .openingBalanceInCents,
      10000,
    );
    expect(
      (await upgraded.accountDao.findById('family::${SeedIds.cashAccount}'))!
          .balanceInCents,
      -2500,
    );
    expect(
      (await upgraded.transactionDao.findById('deleted'))!.accountId,
      'family::${SeedIds.cashAccount}',
    );
    expect(
      (await upgraded.accountDao.getAll()).fold<int>(
        0,
        (v, a) => v + a.balanceInCents,
      ),
      6500,
    );
    expect(
      await upgraded.budgetDao.getMonth('2026-09', bookId: 'family'),
      isEmpty,
    );
    await upgraded.close();
    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    expect(
      (await reopened.accountDao.getAll()).fold<int>(
        0,
        (v, a) => v + a.balanceInCents,
      ),
      6500,
    );
    await reopened.close();
  });
}

TransactionRecord record(
  String id,
  String book,
  String account,
  double amount,
) => TransactionRecord(
  id: id,
  bookId: book,
  type: TransactionType.expense,
  amount: amount,
  accountId: account,
  occurredAt: DateTime(2026, 9, 8),
  createdAt: DateTime(2026, 9, 8),
  updatedAt: DateTime(2026, 9, 8),
);
