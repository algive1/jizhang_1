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
      final firstDay = DateTime(now.year, now.month, 1, 12);
      final secondDay = DateTime(now.year, now.month, 2, 12);

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

      expect(find.text('本月支出'), findsOneWidget);
      expect(find.text('日均支出'), findsOneWidget);
      expect(find.text('消费天数'), findsOneWidget);
      expect(find.text('最高消费日'), findsOneWidget);
      expect(find.text('¥80'), findsOneWidget);
      expect(find.text('1日'), findsOneWidget);
      expect(find.text('999'), findsNothing);
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
        occurredAt: DateTime(now.year, now.month, 3, 12),
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
    expect(find.text('¥115'), findsOneWidget);
    expect(find.text('2天'), findsOneWidget);

    await tester.tap(find.text('全部账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试家庭账本'));
    await tester.pumpAndSettle();
    expect(find.text('测试家庭账本'), findsOneWidget);
    expect(find.text('¥35'), findsNWidgets(2));
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
  );
}
