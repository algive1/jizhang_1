import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/calendar/presentation/consumption_calendar_page.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  testWidgets(
    'calendar uses net expense amounts, excludes transfers, and shows daily average',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftTransactionRepository(database);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
      });
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final secondDay = DateTime(now.year, now.month, now.day == 1 ? 1 : 2);

      await repository.create(
        _record(
          id: 'calendar-refunded',
          type: TransactionType.expense,
          amount: 100,
          occurredAt: firstDay,
          refundAmount: 40,
          refundStatus: RefundStatus.partial,
        ),
      );
      await repository.create(
        _record(
          id: 'calendar-expense',
          type: TransactionType.expense,
          amount: 20,
          occurredAt: secondDay,
        ),
      );
      await repository.create(
        _record(
          id: 'calendar-transfer',
          type: TransactionType.transfer,
          amount: 999,
          occurredAt: secondDay,
          destinationAccountId: SeedIds.cashAccount,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ConsumptionCalendarPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('本月概览'), findsOneWidget);
      expect(find.text('月支出'), findsOneWidget);
      expect(find.text('月收入'), findsOneWidget);
      expect(find.text('有消费'), findsOneWidget);
      expect(find.text('¥80.00'), findsOneWidget);
      expect(find.text(now.day == 1 ? '1天' : '2天'), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar includes imported expenses in the current month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(database);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      await tester.pump();
    });
    final now = DateTime.now();

    await repository.create(
      _record(
        id: 'calendar-imported-expense',
        type: TransactionType.expense,
        amount: 27.30,
        occurredAt: DateTime(now.year, now.month, now.day),
        source: TransactionSource.import,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ConsumptionCalendarPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¥27.30'), findsWidgets);
    expect(find.text('全部账本'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'calendar canonical totals exclude reimbursement, refund and lending',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftTransactionRepository(database);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
        await tester.pump();
      });
      final now = DateTime.now();
      final occurredAt = DateTime(now.year, now.month, now.day, 10);

      await repository.create(_record(
        id: 'canonical-expense',
        type: TransactionType.expense,
        amount: 36,
        occurredAt: occurredAt,
        source: TransactionSource.import,
      ));
      await repository.create(_record(
        id: 'canonical-reimbursable',
        type: TransactionType.expense,
        amount: 100,
        occurredAt: occurredAt.add(const Duration(minutes: 1)),
        reimbursementStatus: ReimbursementStatus.pending,
        reimbursementAmount: 80,
        source: TransactionSource.import,
      ));
      await repository.create(_record(
        id: 'canonical-refund',
        type: TransactionType.refund,
        amount: 50,
        occurredAt: occurredAt.add(const Duration(minutes: 2)),
        source: TransactionSource.import,
      ));
      await repository.create(_record(
        id: 'canonical-lend',
        type: TransactionType.lend,
        amount: 70,
        occurredAt: occurredAt.add(const Duration(minutes: 3)),
        source: TransactionSource.import,
      ));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ConsumptionCalendarPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¥56.00'), findsWidgets);
      expect(find.textContaining('¥156.00'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar defaults to all ledgers and can filter one ledger', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      await tester.pump();
    });
    final now = DateTime.now();
    final family = await container
        .read(bookRepositoryProvider)
        .create(name: '测试家庭账本', type: BookType.family);
    final familyDay = now.day == 1 ? 1 : 2;
    final repository = DriftTransactionRepository(database);
    await repository.create(
      _record(
        id: 'calendar-personal-expense',
        type: TransactionType.expense,
        amount: 80,
        occurredAt: DateTime(now.year, now.month, 1, 12),
      ),
    );
    await repository.create(
      _record(
        id: 'calendar-family-expense',
        bookId: family.id,
        accountId: scopedSeedId(family.id, SeedIds.cashAccount),
        type: TransactionType.expense,
        amount: 35,
        occurredAt: DateTime(now.year, now.month, familyDay),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ConsumptionCalendarPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('全部账本'), findsOneWidget);
    expect(find.text('¥115.00'), findsOneWidget);
    expect(find.text(now.day == 1 ? '1天' : '2天'), findsOneWidget);

    await tester.tap(find.text('全部账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试家庭账本'));
    await tester.pumpAndSettle();
    expect(find.text('测试家庭账本'), findsOneWidget);
    expect(find.text('¥35.00'), findsNWidgets(2));
  });
}

TransactionRecord _record({
  required String id,
  required TransactionType type,
  String bookId = SeedIds.personalBook,
  String accountId = SeedIds.bankAccount,
  required double amount,
  required DateTime occurredAt,
  String? destinationAccountId,
  RefundStatus refundStatus = RefundStatus.none,
  double? refundAmount,
  ReimbursementStatus reimbursementStatus = ReimbursementStatus.none,
  double? reimbursementAmount,
  TransactionSource source = TransactionSource.manual,
}) {
  return TransactionRecord(
    id: id,
    bookId: bookId,
    type: type,
    amount: amount,
    accountId: accountId,
    destinationAccountId: destinationAccountId,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
    refundStatus: refundStatus,
    refundAmount: refundAmount,
    reimbursementStatus: reimbursementStatus,
    reimbursementAmount: reimbursementAmount,
    source: source,
  );
}
