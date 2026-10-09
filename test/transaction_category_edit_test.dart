import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/models/transaction_intelligence.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/components/category_grid.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/intelligence/data/merchant_rule_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/transactions/presentation/transaction_actions.dart';

void main() {
  testWidgets(
    'long-press menu reuses confirmation picker, saves child and merchant rule without changing money',
    (tester) async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      final repository = DriftTransactionRepository(db);
      await repository.create(_transaction());
      final before = (await db.accountDao.findById('account-cash'))!
          .balanceInCents;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await _pumpMenu(
        tester,
        container,
        (await repository.getById('category-edit'))!,
      );
      await tester.tap(find.text('流水菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑分类'));
      await tester.pumpAndSettle();
      final grid = tester.widget<CategoryGrid>(find.byType(CategoryGrid));
      expect(grid.categories.first.name, '餐饮');
      expect(grid.categories.last.name, '其他');
      expect(grid.selected?.id, 'expense-food');
      expect(grid.selectedSubcategoryId, 'expense-food-breakfast');
      await tester.tap(
        find.byKey(const ValueKey('quick-category-expense-food')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('quick-subcategory-bubble')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('quick-subcategory-expense-food-lunch')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('以后都这样分类'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并记住规则'));
      await tester.pumpAndSettle();
      final saved = (await repository.getById('category-edit'))!;
      expect(saved.categoryId, 'expense-food');
      expect(saved.subcategoryId, 'expense-food-lunch');
      expect(saved.displayCategoryPath, '餐饮 · 午餐');
      expect(saved.amount, 38);
      expect(saved.userCorrected, isTrue);
      expect(
        (await db.accountDao.findById('account-cash'))!.balanceInCents,
        before,
      );
      final rules = await container
          .read(merchantRuleRepositoryProvider)
          .getRules(bookId: SeedIds.personalBook);
      final remembered = rules
          .where(
            (rule) =>
                rule.source == MerchantRuleSource.userCorrection &&
                rule.merchantPattern == '早餐店',
          )
          .single;
      expect(remembered.categoryId, 'expense-food');
      expect(remembered.subcategoryId, 'expense-food-lunch');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel leaves original classification and archived child intact, root-only edit clears child',
    (tester) async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      final repository = DriftTransactionRepository(db);
      await repository.create(_transaction());
      await DriftCategoryRepository(db).archive('expense-food-breakfast');
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await _pumpMenu(
        tester,
        container,
        (await repository.getById('category-edit'))!,
      );
      Future<void> openPicker() async {
        await tester.tap(find.text('流水菜单'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('编辑分类'));
        await tester.pumpAndSettle();
      }

      await openPicker();
      expect(
        tester
            .widget<CategoryGrid>(find.byType(CategoryGrid))
            .selectedSubcategoryId,
        'expense-food-breakfast',
      );
      await tester.tap(
        find.byKey(const ValueKey('quick-category-expense-snacks')),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        (await repository.getById('category-edit'))!.subcategoryId,
        'expense-food-breakfast',
      );
      await openPicker();
      await tester.tap(find.text('仅保留一级分类'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('仅修改本次'));
      await tester.pumpAndSettle();
      expect(
        (await repository.getById('category-edit'))!.categoryId,
        'expense-food',
      );
      expect(
        (await repository.getById('category-edit'))!.subcategoryId,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

TransactionRecord _transaction() {
  final now = DateTime(2026, 10, 5, 12);
  return TransactionRecord(
    id: 'category-edit',
    bookId: SeedIds.personalBook,
    type: TransactionType.expense,
    amount: 38,
    accountId: 'account-cash',
    categoryId: 'expense-food',
    subcategoryId: 'expense-food-breakfast',
    merchant: '早餐店',
    occurredAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpMenu(
  WidgetTester tester,
  ProviderContainer container,
  TransactionRecord transaction,
) async {
  await tester.binding.setSurfaceSize(const Size(393, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await container.read(databaseBootstrapProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    showTransactionActions(context, ref, transaction),
                child: const Text('流水菜单'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
