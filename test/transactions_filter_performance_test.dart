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
