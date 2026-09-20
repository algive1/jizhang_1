import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';

void main() {
  test('personal defaults include detailed high-frequency categories', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    final seeder = DatabaseSeeder(db);

    await seeder.seedIfNeeded();

    final active = await db.categoryDao.getActive(bookId: SeedIds.personalBook);
    final household = active.firstWhere((item) => item.name == '家居日用');
    final tobaccoTea = active.firstWhere((item) => item.name == '烟酒茶');

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
  });

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
    final deprecated =
        all.firstWhere((item) => item.id == 'expense-shopping-daily');
    final customized =
        all.firstWhere((item) => item.id == 'expense-shopping-furniture');

    expect(deprecated.isArchived, isTrue);
    expect(customized.isArchived, isFalse);
  });
}
