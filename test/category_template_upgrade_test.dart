import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';

void main() {
  test(
    'personal defaults include detailed high-frequency categories',
    () async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      final seeder = DatabaseSeeder(db);

      await seeder.seedIfNeeded();

      final active = await db.categoryDao.getActive(
        bookId: SeedIds.personalBook,
      );
      final shopping = active.firstWhere((item) => item.name == '购物');
      final household = active.firstWhere((item) => item.name == '家居日用');
      final tobaccoTea = active.firstWhere((item) => item.name == '烟酒茶');

      expect(
        active
            .where((item) => item.parentId == shopping.id)
            .map((item) => item.name),
        containsAll(['服饰鞋包', '美妆护肤', '饰品', '个人护理', '母婴用品', '其他']),
      );
      expect(
        active
            .where((item) => item.parentId == household.id)
            .map((item) => item.name),
        containsAll(['日用品', '清洁用品', '厨房用品', '收纳用品', '家纺寝具', '家具', '小家电']),
      );
      expect(
        active
            .where((item) => item.parentId == tobaccoTea.id)
            .map((item) => item.name),
        containsAll(['香烟', '酒类', '茶叶', '茶具']),
      );
    },
  );

  test(
    'defaults separate drinks and transport from vehicle expenses',
    () async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      final active = await db.categoryDao.getActive(
        bookId: SeedIds.personalBook,
      );
      final food = active
          .where((c) => c.parentId == 'expense-food')
          .map((c) => c.name);
      expect(food, containsAll(['奶茶', '咖啡']));
      expect(food, isNot(contains('奶茶咖啡')));
      final shopping = active
          .where((c) => c.parentId == 'expense-shopping')
          .map((c) => c.name);
      expect(shopping, isNot(contains('淘宝')));
      final transport = active
          .where((c) => c.parentId == 'expense-transport')
          .map((c) => c.name);
      expect(transport, isNot(contains('加油')));
      expect(transport, isNot(contains('停车')));
    },
  );

  test('upgrade hides only untouched legacy shopping overlaps', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    final seeder = DatabaseSeeder(db);
    await seeder.seedIfNeeded();

    final shopping = (await db.categoryDao.getActive(
      bookId: SeedIds.personalBook,
    )).firstWhere((item) => item.id == 'expense-shopping');

    await db.categoryDao.insertOne(
      CategoryEntriesCompanion.insert(
        id: 'expense-shopping-daily',
        bookId: const Value(SeedIds.personalBook),
        parentId: Value(shopping.id),
        name: '日用百货',
        icon: shopping.icon,
        type: 'expense',
        sortOrder: const Value(100),
        isDefault: const Value(true),
      ),
    );
    await db.categoryDao.insertOne(
      CategoryEntriesCompanion.insert(
        id: 'expense-shopping-online',
        bookId: const Value(SeedIds.personalBook),
        parentId: Value(shopping.id),
        name: '网购',
        icon: shopping.icon,
        type: 'expense',
        sortOrder: const Value(102),
        isDefault: const Value(true),
      ),
    );
    await db.categoryDao.insertOne(
      CategoryEntriesCompanion.insert(
        id: 'expense-shopping-furniture',
        bookId: const Value(SeedIds.personalBook),
        parentId: Value(shopping.id),
        name: '我改过的家居',
        icon: shopping.icon,
        type: 'expense',
        sortOrder: const Value(101),
        isDefault: const Value(true),
      ),
    );

    await seeder.ensureBookDefaults(
      SeedIds.personalBook,
      type: BookType.personal,
    );

    final all = await db.categoryDao.getAll(bookId: SeedIds.personalBook);
    final deprecated = all.firstWhere(
      (item) => item.id == 'expense-shopping-daily',
    );
    final online = all.firstWhere(
      (item) => item.id == 'expense-shopping-online',
    );
    final customized = all.firstWhere(
      (item) => item.id == 'expense-shopping-furniture',
    );

    expect(deprecated.isArchived, isTrue);
    expect(online.isArchived, isTrue);
    expect(customized.isArchived, isFalse);
  });
  test(
    'upgrade retains historical links and customized legacy categories',
    () async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      final seeder = DatabaseSeeder(db);
      await seeder.seedIfNeeded();
      for (final item in [
        ('expense-shopping-taobao', '淘宝', 'shopping_bag_outlined'),
        ('expense-shopping-jd', '我的京东', 'shopping_bag_outlined'),
        ('expense-shopping-pinduoduo', '拼多多', 'stars_outlined'),
      ]) {
        await db.categoryDao.insertOne(
          CategoryEntriesCompanion.insert(
            id: item.$1,
            bookId: const Value(SeedIds.personalBook),
            parentId: const Value('expense-shopping'),
            name: item.$2,
            icon: item.$3,
            type: 'expense',
            isDefault: const Value(true),
          ),
        );
      }
      final now = DateTime(2026, 9, 23);
      await db.transactionDao.insertOne(
        TransactionEntriesCompanion.insert(
          id: 'legacy-platform-bill',
          bookId: SeedIds.personalBook,
          type: 'expense',
          amountInCents: 1800,
          categoryId: const Value('expense-shopping'),
          subcategoryId: const Value('expense-shopping-taobao'),
          accountId: SeedIds.cashAccount,
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await seeder.ensureExistingBookDefaults();
      await seeder.ensureExistingBookDefaults();
      expect(
        (await db.categoryDao.findById('expense-shopping-taobao'))!.isArchived,
        isTrue,
      );
      expect(
        (await db.categoryDao.findById('expense-shopping-jd'))!.isArchived,
        isFalse,
      );
      expect(
        (await db.categoryDao.findById('expense-shopping-pinduoduo'))!
            .isArchived,
        isFalse,
      );
      final bill = (await DriftTransactionRepository(db).getAll()).single;
      expect(bill.subcategoryName, '淘宝');
      expect(bill.amount, 18);
      expect(bill.categoryId, 'expense-shopping');
    },
  );

  test('inherited child glyph upgrades preserve custom icons and hidden categories', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    final seeder = DatabaseSeeder(db);
    await seeder.seedIfNeeded();
    await db.customStatement(
      "UPDATE categories SET icon='directions_car_outlined' WHERE id='expense-transport-taxi'",
    );
    await db.customStatement(
      "UPDATE categories SET icon='stars_outlined' WHERE id='expense-transport-metro'",
    );
    await db.customStatement(
      "UPDATE categories SET is_archived=1 WHERE id='expense-food-milk-tea'",
    );
    await seeder.ensureExistingBookDefaults();
    expect(
      (await db.categoryDao.findById('expense-transport-taxi'))!.icon,
      'detail:打车',
    );
    expect(
      (await db.categoryDao.findById('expense-transport-metro'))!.icon,
      'stars_outlined',
    );
    expect(
      (await db.categoryDao.findById('expense-food-milk-tea'))!.isArchived,
      isTrue,
    );
  });
}
