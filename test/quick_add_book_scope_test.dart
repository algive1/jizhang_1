import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/quick_add_sheet.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';

void main() {
  testWidgets(
    'manual bookkeeping can target another ledger without switching browsing ledger',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final family = await DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      ).create(name: '家庭账本', type: BookType.family);
      final familyCategories = await DriftCategoryRepository(
        database,
        bookId: family.id,
      ).getActive();
      final familyExpense = familyCategories.firstWhere(
        (category) => category.type == CategoryType.expense,
      );
      final beforePersonal = await database.transactionDao.getActive(
        bookId: SeedIds.personalBook,
      );
      final beforeFamily = await database.transactionDao.getActive(
        bookId: family.id,
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const QuickAddSheet(),
                    ),
                    child: const Text('打开记一笔'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开记一笔'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick-book-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('quick-book-${family.id}')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('quick-category-${familyExpense.id}')),
        findsOneWidget,
      );
      expect(container.read(activeBookIdProvider), SeedIds.personalBook);

      await tester.tap(find.byKey(const ValueKey('quick-amount-input')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('amount-key-3')));
      await tester.tap(find.byKey(const ValueKey('amount-key-6')));
      await tester.tap(find.byKey(const ValueKey('quick-done')));
      await tester.pumpAndSettle();

      final personal = await database.transactionDao.getActive(
        bookId: SeedIds.personalBook,
      );
      final familyTransactions = await database.transactionDao.getActive(
        bookId: family.id,
      );
      expect(personal, hasLength(beforePersonal.length));
      expect(familyTransactions, hasLength(beforeFamily.length + 1));
      expect(familyTransactions.last.categoryId, familyExpense.id);
      expect(tester.takeException(), isNull);
    },
  );
}
