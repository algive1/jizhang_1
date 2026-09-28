import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/widgets/transaction_date_group.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/transactions/presentation/transactions_page.dart';

void main() {
  test('monthly SQL aggregates preserve cashflow semantics', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );

    Future<void> add(
      String id,
      TransactionType type,
      double amount, {
      double? refundAmount,
      ReimbursementStatus reimbursementStatus = ReimbursementStatus.none,
      double? reimbursementAmount,
    }) {
      final occurredAt = DateTime(2026, 8, 10, 12);
      return repository
          .create(
            TransactionRecord(
              id: id,
              bookId: SeedIds.personalBook,
              type: type,
              amount: amount,
              accountId: SeedIds.bankAccount,
              occurredAt: occurredAt,
              createdAt: occurredAt,
              updatedAt: occurredAt,
              refundStatus: refundAmount == null
                  ? RefundStatus.none
                  : RefundStatus.partial,
              refundAmount: refundAmount,
              reimbursementStatus: reimbursementStatus,
              reimbursementAmount: reimbursementAmount,
            ),
          )
          .then((_) {});
    }

    await add('sql-income', TransactionType.income, 1000);
    await add('sql-borrow', TransactionType.borrow, 200);
    await add(
      'sql-refund-expense',
      TransactionType.expense,
      100,
      refundAmount: 20,
    );
    await add(
      'sql-reimbursed-expense',
      TransactionType.expense,
      100,
      reimbursementStatus: ReimbursementStatus.pending,
      reimbursementAmount: 60,
    );
    await add('sql-asset-purchase', TransactionType.assetPurchase, 500);

    final summary = await database.transactionDao
        .watchMonthSummary(
          bookId: SeedIds.personalBook,
          start: DateTime(2026, 8),
          endExclusive: DateTime(2026, 9),
          now: DateTime(2026, 8, 20),
        )
        .first;
    expect(summary.incomeCents, 120000);
    expect(summary.personalExpenseCents, 12000);

    final categories = await database.transactionDao
        .watchMonthExpenseCategories(
          bookId: SeedIds.personalBook,
          start: DateTime(2026, 8),
          endExclusive: DateTime(2026, 9),
          now: DateTime(2026, 8, 20),
        )
        .first;
    expect(categories, hasLength(1));
    expect(categories.single.id, 'uncategorized');
    expect(categories.single.amountCents, 68000);
    expect(categories.single.count, 3);
  });

  test('large expense threshold is derived from full scoped history in SQL', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );

    for (var index = 1; index <= 5; index++) {
      final occurredAt = DateTime(2026, 7, index, 12);
      await repository.create(
        TransactionRecord(
          id: 'threshold-$index',
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: index * 100,
          accountId: SeedIds.bankAccount,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          updatedAt: occurredAt,
        ),
      );
    }
    final assetAt = DateTime(2026, 7, 10, 12);
    await repository.create(
      TransactionRecord(
        id: 'threshold-asset',
        bookId: SeedIds.personalBook,
        type: TransactionType.assetPurchase,
        amount: 10000,
        accountId: SeedIds.bankAccount,
        occurredAt: assetAt,
        createdAt: assetAt,
        updatedAt: assetAt,
      ),
    );
    final futureAt = DateTime(2026, 9, 1);
    await repository.create(
      TransactionRecord(
        id: 'threshold-future',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 10000,
        accountId: SeedIds.bankAccount,
        occurredAt: futureAt,
        createdAt: futureAt,
        updatedAt: futureAt,
      ),
    );

    final threshold = await database.transactionDao
        .watchLargeExpenseThresholdInCents(
          bookId: SeedIds.personalBook,
          cutoff: DateTime(2026, 8, 20),
        )
        .first;

    expect(threshold, 150000);
  });

  test('pending reimbursement query keeps old unresolved expenses', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final occurredAt = DateTime(2025, 1, 10, 12);
    await repository.create(
      TransactionRecord(
        id: 'old-pending-reimbursement',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 200,
        accountId: SeedIds.bankAccount,
        occurredAt: occurredAt,
        createdAt: occurredAt,
        updatedAt: occurredAt,
        reimbursementStatus: ReimbursementStatus.pending,
        reimbursementAmount: 120,
      ),
    );

    final rows = await repository.watchPendingReimbursements().first;
    expect(rows.map((item) => item.id), contains('old-pending-reimbursement'));
  });

  test('recorded month neighbors ignore future rows and respect gaps', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );

    for (final entry in <({String id, DateTime occurredAt})>[
      (id: 'neighbor-march', occurredAt: DateTime(2026, 3, 12)),
      (id: 'neighbor-may', occurredAt: DateTime(2026, 5, 8)),
      (id: 'neighbor-june', occurredAt: DateTime(2026, 6, 10)),
      (id: 'neighbor-future', occurredAt: DateTime(2026, 7, 1)),
    ]) {
      await repository.create(
        TransactionRecord(
          id: entry.id,
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 10,
          accountId: SeedIds.bankAccount,
          occurredAt: entry.occurredAt,
          createdAt: entry.occurredAt,
          updatedAt: entry.occurredAt,
        ),
      );
    }

    final neighbors = await database.transactionDao
        .watchRecordedMonthNeighbors(
          month: DateTime(2026, 5),
          now: DateTime(2026, 6, 20),
          bookId: SeedIds.personalBook,
        )
        .first;

    expect(neighbors.previousMonthKey, 202603);
    expect(neighbors.nextMonthKey, 202606);
  });

  test('transaction range query excludes rows outside the requested month', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );

    for (final entry in <({String id, DateTime occurredAt})>[
      (id: 'range-before', occurredAt: DateTime(2026, 7, 31, 23, 59)),
      (id: 'range-inside', occurredAt: DateTime(2026, 8, 15, 12)),
      (id: 'range-after', occurredAt: DateTime(2026, 9, 1)),
    ]) {
      await repository.create(
        TransactionRecord(
          id: entry.id,
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 12,
          accountId: SeedIds.bankAccount,
          occurredAt: entry.occurredAt,
          createdAt: entry.occurredAt,
          updatedAt: entry.occurredAt,
        ),
      );
    }

    final rows = await repository
        .watchRange(
          start: DateTime(2026, 8),
          endExclusive: DateTime(2026, 9),
        )
        .first;

    expect(rows.map((item) => item.id), ['range-inside']);
  });

  testWidgets('transactions page lazily builds date groups and switches filters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(database);
    final now = DateTime.now();
    for (var index = 0; index < 45; index++) {
      final occurredAt = DateTime(
        now.year,
        now.month,
        now.day,
        12,
      ).subtract(Duration(days: index));
      await repository.create(
        TransactionRecord(
          id: 'perf-expense-$index',
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 10 + index.toDouble(),
          accountId: SeedIds.bankAccount,
          categoryName: '餐饮',
          note: '性能回归-$index',
          occurredAt: occurredAt,
          createdAt: occurredAt,
          updatedAt: occurredAt,
        ),
      );
    }

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TransactionsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final builtGroups = find.byType(TransactionDateGroup).evaluate().length;
    expect(builtGroups, greaterThan(0));
    expect(
      builtGroups,
      lessThan(45),
      reason: 'Only viewport-near date groups should be built initially.',
    );

    await tester.tap(find.byKey(const ValueKey('transactions-filter-2')));
    await tester.pumpAndSettle();
    expect(find.text('没有找到匹配的记录'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('transactions-filter-1')));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDateGroup), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
