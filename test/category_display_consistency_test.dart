import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/core/widgets/category_icon.dart';

void main() {
  testWidgets('vivid and list category icons use the same glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            CategoryIcon(category: '汽车', vivid: true),
            CategoryIcon(category: '汽车'),
          ],
        ),
      ),
    );

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons, hasLength(2));
    expect(icons[0].icon, Icons.directions_car_rounded);
    expect(icons[1].icon, icons[0].icon);
  });

  testWidgets('renamed custom categories resolve their persisted icon key', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            CategoryIcon(
              category: '健身',
              iconKey: 'devices_outlined',
              vivid: true,
            ),
            CategoryIcon(category: '健身', iconKey: 'devices_outlined'),
          ],
        ),
      ),
    );

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons[0].icon, Icons.devices_rounded);
    expect(icons[1].icon, icons[0].icon);
  });

  test('changing a derived category clears stale display metadata', () {
    final now = DateTime(2026, 9, 10);
    final original = TransactionRecord(
      id: 'copy-with-category',
      bookId: 'book-personal',
      type: TransactionType.expense,
      amount: 1,
      accountId: 'account-cash',
      categoryId: 'expense-food',
      categoryName: '餐饮',
      categoryIcon: 'restaurant_outlined',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final changed = original.copyWith(categoryId: 'expense-shopping');
    expect(changed.categoryName, isNull);
    expect(changed.categoryIcon, isNull);
    expect(original.copyWith(categoryName: '新名称').categoryName, '新名称');
  });

  test('transaction category lookup stays scoped to its ledger', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    await DatabaseSeeder(db).seedIfNeeded();
    await db.familyDao.upsertBook(
      BookEntriesCompanion.insert(
        id: 'book-enterprise',
        name: '企业账本',
        type: BookType.enterprise.name,
        ownerUserId: SeedIds.localUser,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await DatabaseSeeder(db)
        .seedBookDefaults('book-enterprise', type: BookType.enterprise);
    final now = DateTime.now();
    final personalCategory = (await db.categoryDao.getActive(
      bookId: 'book-personal',
    )).firstWhere((item) => item.id == 'expense-food');
    final enterpriseCategory = (await db.categoryDao.getActive(
      bookId: 'book-enterprise',
    )).firstWhere((item) => item.name == '商务餐饮');
    final personalAccount = (await db.accountDao.getActive(
      bookId: 'book-personal',
    )).first;
    final enterpriseAccount = (await db.accountDao.getActive(
      bookId: 'book-enterprise',
    )).first;

    Future<TransactionRecord> createRecord({
      required String bookId,
      required String id,
      required String categoryId,
      required String accountId,
    }) async {
      final record = TransactionRecord(
        id: id,
        bookId: bookId,
        type: TransactionType.expense,
        amount: 1,
        accountId: accountId,
        categoryId: categoryId,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await DriftTransactionRepository(db, bookId: bookId).create(record);
      return (await DriftTransactionRepository(
        db,
        bookId: bookId,
      ).getAll()).firstWhere((item) => item.id == id);
    }

    final personal = await createRecord(
      bookId: 'book-personal',
      id: 'category-scope-personal',
      categoryId: personalCategory.id,
      accountId: personalAccount.id,
    );
    final enterprise = await createRecord(
      bookId: 'book-enterprise',
      id: 'category-scope-enterprise',
      categoryId: enterpriseCategory.id,
      accountId: enterpriseAccount.id,
    );

    expect(personal.categoryName, '餐饮');
    expect(personal.categoryIcon, personalCategory.icon);
    expect(enterprise.categoryName, '商务餐饮');
    expect(enterprise.categoryIcon, enterpriseCategory.icon);
  });
}
