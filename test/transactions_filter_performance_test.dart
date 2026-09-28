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
import 'package:jizhang_app/features/profile/data/profile_stats.dart';
import 'package:jizhang_app/features/transactions/presentation/transaction_search_page.dart';

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

    final ledgerSummary = await database.transactionDao
        .watchLedgerMonthSummary(
          bookId: SeedIds.personalBook,
          start: DateTime(2026, 8),
          endExclusive: DateTime(2026, 9),
          now: DateTime(2026, 8, 20),
        )
        .first;
    expect(ledgerSummary.incomeCents, 120000);
    expect(
      ledgerSummary.expenseCents,
      68000,
      reason:
          'Ledger summary keeps asset purchases and ignores reimbursement offsets, matching the transaction page.',
    );

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

  test('account scoped SQL preserves monthly inflow and outflow semantics', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final occurredAt = DateTime(2026, 8, 10, 12);

    Future<void> add(
      String id,
      TransactionType type,
      double amount, {
      String accountId = SeedIds.bankAccount,
      String? destinationAccountId,
      DateTime? at,
    }) async {
      final time = at ?? occurredAt;
      await repository.create(
        TransactionRecord(
          id: id,
          bookId: SeedIds.personalBook,
          type: type,
          amount: amount,
          accountId: accountId,
          destinationAccountId: destinationAccountId,
          occurredAt: time,
          createdAt: time,
          updatedAt: time,
        ),
      );
    }

    await add('account-income', TransactionType.income, 100);
    await add(
      'account-transfer',
      TransactionType.transfer,
      30,
      destinationAccountId: SeedIds.cashAccount,
    );
    await add(
      'account-repayment',
      TransactionType.repayment,
      20,
      destinationAccountId: SeedIds.cashAccount,
    );
    await add('account-expense', TransactionType.expense, 10);
    await add(
      'account-unrelated',
      TransactionType.expense,
      99,
      accountId: SeedIds.wechatAccount,
    );
    await add(
      'account-future',
      TransactionType.income,
      999,
      at: DateTime(2026, 9, 1),
    );

    final bankRows = await repository
        .watchForAccount(accountId: SeedIds.bankAccount)
        .first;
    expect(bankRows.map((item) => item.id), contains('account-income'));
    expect(bankRows.map((item) => item.id), contains('account-future'));
    expect(bankRows.map((item) => item.id), isNot(contains('account-unrelated')));

    final summary = await database.transactionDao
        .watchAccountMonthSummary(
          accountId: SeedIds.bankAccount,
          start: DateTime(2026, 8),
          endExclusive: DateTime(2026, 9),
          now: DateTime(2026, 8, 20),
        )
        .first;
    expect(summary.inflowCents, 10000);
    expect(summary.outflowCents, 6000);

    final cashSummary = await database.transactionDao
        .watchAccountMonthSummary(
          accountId: SeedIds.cashAccount,
          start: DateTime(2026, 8),
          endExclusive: DateTime(2026, 9),
          now: DateTime(2026, 8, 20),
        )
        .first;
    expect(cashSummary.inflowCents, 5000);
    expect(cashSummary.outflowCents, 0);
  });

  test('reimbursement source stream and linked sum avoid full ledger scans', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final now = DateTime(2026, 8, 20, 12);
    final source = TransactionRecord(
      id: 'reimbursement-source-sql',
      bookId: SeedIds.personalBook,
      type: TransactionType.expense,
      amount: 300,
      accountId: SeedIds.bankAccount,
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      reimbursementStatus: ReimbursementStatus.partial,
      reimbursementAmount: 100,
    );
    await repository.create(source);
    for (final entry in <({String id, double amount})>[
      (id: 'reimbursement-linked-a', amount: 40),
      (id: 'reimbursement-linked-b', amount: 60),
    ]) {
      await repository.create(
        TransactionRecord(
          id: entry.id,
          bookId: SeedIds.personalBook,
          type: TransactionType.reimbursement,
          amount: entry.amount,
          accountId: SeedIds.bankAccount,
          relatedTransactionId: source.id,
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final sources = await repository.watchReimbursementSources().first;
    expect(sources.map((item) => item.id), contains(source.id));
    expect(
      sources.map((item) => item.id),
      isNot(contains('reimbursement-linked-a')),
    );

    expect(
      await database.transactionDao.sumRelatedReimbursementsInCents(
        bookId: SeedIds.personalBook,
        relatedTransactionId: source.id,
      ),
      10000,
    );
    expect(
      await database.transactionDao.sumRelatedReimbursementsInCents(
        bookId: SeedIds.personalBook,
        relatedTransactionId: source.id,
        excludingTransactionId: 'reimbursement-linked-b',
      ),
      4000,
    );
  });

  test('import dedupe candidates exclude unrelated transaction sources', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final now = DateTime.now();

    Future<void> add(
      String id,
      TransactionSource source,
    ) async {
      await repository.create(
        TransactionRecord(
          id: id,
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 10,
          accountId: SeedIds.bankAccount,
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
          source: source,
        ),
      );
    }

    await add('dedupe-import', TransactionSource.import);
    await add('dedupe-auto', TransactionSource.auto);
    await add('dedupe-manual', TransactionSource.manual);
    await add('dedupe-ocr', TransactionSource.ocr);

    final candidates = await repository.getImportDedupCandidates();
    expect(
      candidates.map((item) => item.id).toSet(),
      containsAll({'dedupe-import', 'dedupe-auto'}),
    );
    expect(
      candidates.map((item) => item.id).toSet(),
      isNot(contains('dedupe-manual')),
    );
    expect(
      candidates.map((item) => item.id).toSet(),
      isNot(contains('dedupe-ocr')),
    );
  });

  test('profile activity summary stays fixed-size and ignores future rows', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final now = DateTime.now();
    final firstToday = now.subtract(const Duration(minutes: 2));
    final secondToday = now.subtract(const Duration(minutes: 1));
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));

    Future<void> add(String id, DateTime occurredAt) async {
      await repository.create(
        TransactionRecord(
          id: id,
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 1,
          accountId: SeedIds.bankAccount,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          updatedAt: occurredAt,
        ),
      );
    }

    await add('profile-day-a', firstToday);
    await add('profile-day-b', secondToday);
    await add('profile-day-yesterday', yesterday);
    await add('profile-day-future', tomorrow);

    final summary = await database.transactionDao
        .watchProfileActivitySummary(
          bookId: SeedIds.personalBook,
          now: now,
        )
        .first;
    expect(summary.recordedDays, greaterThanOrEqualTo(1));
    expect(summary.firstRecordedDay, isNotNull);
    expect(summary.firstRecordedDay!.isAfter(DateTime(now.year, now.month, now.day + 1)), isFalse);
    expect(summary.streak, greaterThanOrEqualTo(2));

    final activity = ProfileActivity.fromSummary(
      firstRecordedDay: summary.firstRecordedDay,
      recordedDays: summary.recordedDays,
      streak: summary.streak,
      now: now,
    );
    expect(activity.streak, summary.streak);
    expect(activity.recordedDays, summary.recordedDays);
  });

  test('type month SQL sum excludes other transaction types and months', () async {
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
      double amount,
      DateTime occurredAt,
    ) async {
      await repository.create(
        TransactionRecord(
          id: id,
          bookId: SeedIds.personalBook,
          type: type,
          amount: amount,
          accountId: SeedIds.bankAccount,
          occurredAt: occurredAt,
          createdAt: occurredAt,
          updatedAt: occurredAt,
        ),
      );
    }

    await add(
      'month-reimbursement-a',
      TransactionType.reimbursement,
      40,
      DateTime(2026, 9, 5),
    );
    await add(
      'month-reimbursement-b',
      TransactionType.reimbursement,
      60,
      DateTime(2026, 9, 20),
    );
    await add(
      'month-income-noise',
      TransactionType.income,
      999,
      DateTime(2026, 9, 10),
    );
    await add(
      'month-reimbursement-outside',
      TransactionType.reimbursement,
      70,
      DateTime(2026, 8, 31),
    );

    final total = await database.transactionDao
        .watchTypeAmountSumBetween(
          bookId: SeedIds.personalBook,
          type: TransactionType.reimbursement.name,
          start: DateTime(2026, 9),
          endExclusive: DateTime(2026, 10),
        )
        .first;
    expect(total, 10000);
  });

  test('asset history stream keeps one year plus future rows only', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final now = DateTime.now();
    for (final entry in <({String id, DateTime occurredAt})>[
      (
        id: 'asset-history-old',
        occurredAt: now.subtract(const Duration(days: 800)),
      ),
      (
        id: 'asset-history-recent',
        occurredAt: now.subtract(const Duration(days: 100)),
      ),
      (
        id: 'asset-history-future',
        occurredAt: now.add(const Duration(days: 30)),
      ),
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

    final rows = await DriftTransactionRepository(database)
        .watchSince(
          start: DateTime(now.year, now.month, now.day - 366),
          onlyOccurred: false,
        )
        .first;
    expect(rows.map((item) => item.id), contains('asset-history-recent'));
    expect(rows.map((item) => item.id), contains('asset-history-future'));
    expect(rows.map((item) => item.id), isNot(contains('asset-history-old')));
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

  test('SQLite transaction search preserves text amount and status semantics', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final now = DateTime.now();

    await repository.create(
      TransactionRecord(
        id: 'sql-search-target',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 88,
        accountId: SeedIds.bankAccount,
        merchant: 'SQL搜索商户',
        note: '唯一搜索备注',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        reimbursementStatus: ReimbursementStatus.pending,
        reimbursementAmount: 20,
        metadataJson: '{"search_token":"SQL_SEARCH_META"}',
      ),
    );
    await repository.create(
      TransactionRecord(
        id: 'sql-search-noise',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 12,
        accountId: SeedIds.bankAccount,
        merchant: '无关商户',
        note: '普通备注',
        occurredAt: now.subtract(const Duration(minutes: 1)),
        createdAt: now.subtract(const Duration(minutes: 1)),
        updatedAt: now.subtract(const Duration(minutes: 1)),
      ),
    );

    final noteRows = await repository
        .watchSearchCandidates(query: '唯一搜索备注')
        .first;
    expect(noteRows.map((item) => item.id), contains('sql-search-target'));
    expect(noteRows.map((item) => item.id), isNot(contains('sql-search-noise')));

    final metadataRows = await repository
        .watchSearchCandidates(query: 'SQL_SEARCH_META')
        .first;
    expect(metadataRows.map((item) => item.id), contains('sql-search-target'));

    final statusRows = await repository
        .watchSearchCandidates(query: '待报销')
        .first;
    expect(statusRows.map((item) => item.id), contains('sql-search-target'));

    final amountRows = await repository
        .watchSearchCandidates(query: '>=88')
        .first;
    expect(amountRows.map((item) => item.id), contains('sql-search-target'));

    final lowerAmountRows = await repository
        .watchSearchCandidates(query: '<20')
        .first;
    expect(lowerAmountRows.map((item) => item.id), contains('sql-search-noise'));
    expect(
      lowerAmountRows.map((item) => item.id),
      isNot(contains('sql-search-target')),
    );
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
    for (var index = 0; index < 105; index++) {
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
      lessThan(100),
      reason:
          'The default ledger loads 100 records and only builds viewport-near date groups.',
    );

    await tester.tap(find.byKey(const ValueKey('transactions-filter-2')));
    await tester.pumpAndSettle();
    expect(find.text('没有找到匹配的记录'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transactions-load-more-empty')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('transactions-load-more-empty')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('transactions-load-more-empty')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('transactions-filter-1')));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDateGroup), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TransactionSearchPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final firstSearchPage = await container.read(
      recentTransactionsPageProvider(100).future,
    );
    expect(firstSearchPage.length, 100);

    final relatedRows = await DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    ).watchByIds(['perf-expense-0', 'perf-expense-104']).first;
    expect(
      relatedRows.map((item) => item.id).toSet(),
      {'perf-expense-0', 'perf-expense-104'},
    );
    expect(
      transactionIdsProviderKey(['perf-expense-104', 'perf-expense-0']),
      transactionIdsProviderKey(['perf-expense-0', 'perf-expense-104']),
    );

    final firstKeywordPage = await DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    ).watchSearchCandidates(query: '性能回归-', limit: 100).first;
    expect(firstKeywordPage.length, 100);
    final expandedKeywordPage = await DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    ).watchSearchCandidates(query: '性能回归-', limit: 200).first;
    expect(expandedKeywordPage.length, 105);

    await tester.enterText(find.byType(TextField), '性能回归-104');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('最近记录 · 100 笔'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('找到 1 笔记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
