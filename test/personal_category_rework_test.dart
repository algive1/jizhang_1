import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test('个人一级分类从餐饮到其他，无二级分类及新增明细正确，其他账本不变', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    final seeder = DatabaseSeeder(db);
    await seeder.seedIfNeeded();
    final categories = await DriftCategoryRepository(db).getActive();
    expect(
      categories
          .where((c) => c.parentId == null && c.type.name == 'expense')
          .map((c) => c.name),
      [
        '餐饮',
        '零食',
        '烟酒茶',
        '烹饪食材',
        '购物',
        '交通',
        '娱乐',
        '美妆',
        '生活缴费',
        '住房',
        '教育培训',
        '宠物',
        '汽车',
        '旅行',
        '数码',
        '医疗',
        '家居日用',
        '人情',
        '其他',
      ],
    );
    expect(
      categories.where(
        (c) =>
            c.parentId == 'expense-snacks' ||
            c.parentId == 'expense-tobacco-tea',
      ),
      isEmpty,
    );
    expect(
      categories.where((c) => c.parentId == 'expense-food').map((c) => c.name),
      [
        '早餐',
        '午餐',
        '晚餐',
        '外卖',
        '夜宵',
        '火锅',
        '宴席',
        '小吃',
        '奶茶咖啡',
        '零食',
        '水果',
        '甜品',
      ],
    );
    expect(
      categories
          .where((c) => c.parentId == 'expense-beauty')
          .map((c) => c.name),
      contains('头饰'),
    );
    expect(
      categories
          .where((c) => c.parentId == 'expense-digital')
          .map((c) => c.name),
      containsAll(['耳机', '拍摄设备']),
    );
    for (final type in [BookType.family, BookType.enterprise]) {
      await seeder.seedBookDefaults(type.name, type: type);
      final other = await db.categoryDao.getActive(bookId: type.name);
      expect(
        other.where((c) => c.parentId == null && c.type == 'expense'),
        hasLength(type == BookType.family ? 16 : 15),
      );
      expect(
        other.any((c) => ['美妆', '烹饪食材', '耳机', '头饰', '百货'].contains(c.name)),
        isFalse,
      );
    }
  });

  test('旧账本升级一次，保留历史引用、定制分类和用户后续排序', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    final seeder = DatabaseSeeder(db);
    await seeder.seedIfNeeded();
    await db.customStatement(
      "DELETE FROM app_settings WHERE key='personal_categories_v2:book-personal'",
    );
    await db.appSettingsDao.setValue(
      'book_defaults_version',
      '1',
      DateTime.now(),
    );
    for (final child in [
      ('expense-food-grocery', 'expense-food', '买菜', 'detail:买菜'),
      ('expense-food-milk-tea', 'expense-food', '奶茶', 'detail:奶茶'),
      (
        'expense-tobacco-tea-cigarette',
        'expense-tobacco-tea',
        '香烟',
        'detail:香烟',
      ),
      ('expense-shopping-beauty', 'expense-shopping', '美妆护肤', 'detail:美妆护肤'),
      (
        'expense-digital-accessory',
        'expense-digital',
        '我的配件',
        'stars_outlined',
      ),
    ]) {
      await db.categoryDao.upsert(
        CategoryEntriesCompanion.insert(
          id: child.$1,
          bookId: const Value(SeedIds.personalBook),
          parentId: Value(child.$2),
          name: child.$3,
          icon: child.$4,
          type: 'expense',
          isDefault: const Value(true),
        ),
      );
    }
    await db.customStatement(
      "UPDATE categories SET name='甜品烘焙',icon='detail:甜品烘焙' WHERE id='expense-food-dessert'",
    );
    await db.customStatement(
      "UPDATE categories SET sort_order=0 WHERE parent_id IS NULL",
    );
    final now = DateTime(2026, 10, 4);
    await db.transactionDao.insertOne(
      TransactionEntriesCompanion.insert(
        id: 'historical-grocery',
        bookId: SeedIds.personalBook,
        type: 'expense',
        amountInCents: 2500,
        categoryId: const Value('expense-food'),
        subcategoryId: const Value('expense-food-grocery'),
        accountId: SeedIds.cashAccount,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await seeder.seedIfNeeded();
    final active = await DriftCategoryRepository(db).getActive();
    expect(active.any((c) => c.id == 'expense-food-grocery'), isFalse);
    expect(active.any((c) => c.id == 'expense-tobacco-tea-cigarette'), isFalse);
    expect(active.any((c) => c.id == 'expense-shopping-beauty'), isFalse);
    expect(active.any((c) => c.name == '我的配件'), isTrue);
    expect(
      active.where((c) => c.id == 'expense-food-dessert').single.name,
      '甜品',
    );
    final bill = (await DriftTransactionRepository(db).getAll()).single;
    expect(bill.subcategoryName, '买菜');
    expect(bill.amount, 25);
    final roots = active
        .where((c) => c.parentId == null && c.type.name == 'expense')
        .toList()
        .reversed
        .toList();
    await DriftCategoryRepository(db).reorder(roots);
    await seeder.ensureExistingBookDefaults();
    expect(
      (await DriftCategoryRepository(db).getActive())
          .where((c) => c.parentId == null && c.type.name == 'expense')
          .map((c) => c.id),
      [
        'expense-food',
        ...roots.where((c) => c.displayPriority == 0).map((c) => c.id),
        'expense-other',
      ],
    );
  });
}
