import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/transactions/presentation/transaction_actions.dart';

void main() {
  testWidgets(
    'cross-book actions require switching before showing write actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      final otherBook = await container
          .read(bookRepositoryProvider)
          .create(name: '另一账本', type: BookType.family);
      final transaction = _transaction(bookId: otherBook.id);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showTransactionActions(context, ref, transaction);
                    },
                    child: const Text('流水'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('流水'));
      await tester.pumpAndSettle();

      expect(find.text('切换到该账本并操作'), findsOneWidget);
      expect(find.text('查看流水详情'), findsOneWidget);
      expect(find.text('编辑流水'), findsNothing);
      expect(find.text('删除流水'), findsNothing);

      await tester.tap(find.text('切换到该账本并操作'));
      await tester.pumpAndSettle();

      expect(container.read(activeBookIdProvider), otherBook.id);
      expect(find.text('编辑流水'), findsOneWidget);
      expect(find.text('删除流水'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('same-book long press opens the existing action sheet directly', (
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
    addTearDown(container.dispose);
    final transaction = _transaction(bookId: SeedIds.personalBook);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showTransactionActions(context, ref, transaction);
                  },
                  child: const Text('流水'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('流水'));
    await tester.pumpAndSettle();

    expect(find.text('编辑流水'), findsOneWidget);
    expect(find.text('删除流水'), findsOneWidget);
    expect(find.text('切换到该账本并操作'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

TransactionRecord _transaction({required String bookId}) {
  final occurredAt = DateTime(2026, 9, 24, 12);
  return TransactionRecord(
    id: 'scope-check-$bookId',
    bookId: bookId,
    type: TransactionType.expense,
    amount: 38,
    accountId: 'account-bank',
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}
