import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';

void main() {
  test('new book categories are scoped to that book', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final book = await DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    ).create(name: '企业', type: BookType.enterprise);

    final categories = await DriftCategoryRepository(
      database,
      bookId: book.id,
    ).getActive();
    expect(categories, isNotEmpty);
    expect(categories.every((item) => item.bookId == book.id), isTrue);
    expect(
      categories.any(
        (item) => item.id == '${book.id}::enterprise-expense-food',
      ),
      isTrue,
    );
    expect(categories.any((item) => item.name == '餐饮'), isFalse);
    expect(
      categories.singleWhere((item) => item.name == '工资薪酬').type,
      CategoryType.expense,
    );
    expect(
      categories
          .singleWhere(
            (item) => item.id == '${book.id}::enterprise-income-salary',
          )
          .name,
      '主营业务收入',
    );
  });

  test(
    'bootstrap fills a missing category in an already seeded ledger',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final book = await DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      ).create(name: '企业缺分类', type: BookType.enterprise);
      final payrollId = '${book.id}::enterprise-expense-payroll';
      expect(await database.categoryDao.findById(payrollId), isNotNull);
      await database.customStatement(
        'DELETE FROM categories WHERE parent_id = ?',
        [payrollId],
      );
      await database.customStatement('DELETE FROM categories WHERE id = ?', [
        payrollId,
      ]);

      await DatabaseSeeder(database).ensureExistingBookDefaults();

      final restored = await database.categoryDao.findById(payrollId);
      expect(restored, isNotNull);
      expect(restored!.name, '工资薪酬');
    },
  );

  test(
    'bootstrap repairs an empty old local book and preserves custom rows',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final now = DateTime(2026, 9, 10);
      await database.familyDao.upsertBook(
        BookEntriesCompanion.insert(
          id: 'legacy-book',
          name: '旧账本',
          type: 'enterprise',
          ownerUserId: SeedIds.localUser,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.categoryDao.insertOne(
        CategoryEntriesCompanion.insert(
          id: 'legacy-book::expense-food',
          bookId: const Value('legacy-book'),
          name: '餐饮',
          icon: 'restaurant_outlined',
          type: 'expense',
          isDefault: const Value(true),
        ),
      );
      await DatabaseSeeder(database).ensureExistingBookDefaults();
      final repaired = await DriftCategoryRepository(
        database,
        bookId: 'legacy-book',
      ).getActive();
      expect(repaired.any((item) => item.name == '商务餐饮'), isTrue);
      expect(
        (await database.categoryDao.findById('legacy-book::expense-food'))!
            .isArchived,
        isTrue,
      );

      final custom = Category(
        id: 'legacy-custom',
        bookId: 'legacy-book',
        name: '自定义',
        icon: 'label',
        type: CategoryType.expense,
        sortOrder: 99,
        isDefault: false,
        isArchived: false,
      );
      await DriftCategoryRepository(
        database,
        bookId: 'legacy-book',
      ).create(custom);
      final before = await database.categoryDao.getAll(bookId: 'legacy-book');
      await DatabaseSeeder(database).ensureExistingBookDefaults();
      final after = await database.categoryDao.getAll(bookId: 'legacy-book');
      expect(after.map((item) => item.id), contains(custom.id));
      expect(after.length, before.length);
    },
  );

  test('changing type repairs only an empty local book', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final now = DateTime(2026, 9, 10);
    await database.familyDao.upsertBook(
      BookEntriesCompanion.insert(
        id: 'empty-book',
        name: '空账本',
        type: 'personal',
        ownerUserId: SeedIds.localUser,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final books = DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    );
    await books.changeType('empty-book', BookType.enterprise);
    expect(
      (await database.categoryDao.getActive(bookId: 'empty-book')),
      isNotEmpty,
    );
    expect(
      (await database.familyDao.findBook('empty-book'))!.type,
      'enterprise',
    );
    final custom = Category(
      id: 'empty-custom',
      bookId: 'empty-book',
      name: '自定义',
      icon: 'label',
      type: CategoryType.expense,
      sortOrder: 99,
      isDefault: false,
      isArchived: false,
    );
    await DriftCategoryRepository(
      database,
      bookId: 'empty-book',
    ).create(custom);
    await books.changeType('empty-book', BookType.family);
    await books.changeType('empty-book', BookType.enterprise);
    expect(await database.categoryDao.findById(custom.id), isNotNull);
    expect(
      (await database.categoryDao.getActive(bookId: 'empty-book'))
          .where((item) => item.name == '商务餐饮'),
      hasLength(1),
    );
  });

  test(
    'bootstrap preserves user archived defaults and type switching scopes',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final now = DateTime(2026, 9, 10);
      await database.familyDao.upsertBook(
        BookEntriesCompanion.insert(
          id: 'switch-book',
          name: '切换',
          type: 'personal',
          ownerUserId: SeedIds.localUser,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final books = DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      );
      await books.changeType('switch-book', BookType.enterprise);
      final enterpriseId = 'switch-book::enterprise-expense-food';
      await database.customStatement(
        'UPDATE categories SET is_archived=1 WHERE id=?',
        [enterpriseId],
      );
      await DatabaseSeeder(database).ensureExistingBookDefaults();
      expect(
        (await database.categoryDao.findById(enterpriseId))!.isArchived,
        isTrue,
      );
      await books.changeType('switch-book', BookType.family);
      await books.changeType('switch-book', BookType.personal);
      expect(
        (await database.categoryDao.findById(enterpriseId))!.isArchived,
        isTrue,
      );
      expect(
        (await database.categoryDao.findById('switch-book::expense-food'))!
            .isArchived,
        isFalse,
      );
    },
  );

  test(
    'renamed defaults with custom children and shared books are untouched',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final now = DateTime(2026, 9, 10);
      await database.familyDao.upsertBook(
        BookEntriesCompanion.insert(
          id: 'custom-book',
          name: '自定义',
          type: 'enterprise',
          ownerUserId: SeedIds.localUser,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await database.categoryDao.insertOne(
        CategoryEntriesCompanion.insert(
          id: 'custom-book::expense-food',
          bookId: const Value('custom-book'),
          name: '我改过的餐饮',
          icon: 'label',
          type: 'expense',
          isDefault: const Value(true),
        ),
      );
      await database.categoryDao.insertOne(
        CategoryEntriesCompanion.insert(
          id: 'custom-child',
          bookId: const Value('custom-book'),
          parentId: const Value('custom-book::expense-food'),
          name: '子类',
          icon: 'label',
          type: 'expense',
        ),
      );
      await DatabaseSeeder(database).ensureExistingBookDefaults();
      expect(
        (await database.categoryDao.findById('custom-book::expense-food'))!
            .isArchived,
        isFalse,
      );
      await database.familyDao.upsertBook(
        BookEntriesCompanion.insert(
          id: 'shared-empty',
          name: '共享',
          type: 'enterprise',
          ownerUserId: SeedIds.localUser,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await database.customStatement(
        'INSERT INTO sync_books(book_id,remote_id,user_id,role,access) VALUES(?,?,?,?,?)',
        ['shared-empty', 'remote', SeedIds.localUser, 'member', 1],
      );
      await DatabaseSeeder(database).ensureExistingBookDefaults();
      expect(
        await database.categoryDao.getAll(bookId: 'shared-empty'),
        isEmpty,
      );
    },
  );

  test(
    'category watcher refreshes when existing templates are restored',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final now = DateTime(2026, 9, 10);
      await database.familyDao.upsertBook(
        BookEntriesCompanion.insert(
          id: 'watch-book',
          name: '监听',
          type: 'personal',
          ownerUserId: SeedIds.localUser,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final books = DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      );
      await books.changeType('watch-book', BookType.enterprise);
      await books.changeType('watch-book', BookType.family);
      await books.changeType('watch-book', BookType.enterprise);
      final repository = DriftCategoryRepository(
        database,
        bookId: 'watch-book',
      );
      final refreshed = expectLater(
        repository.watchActive(),
        emitsThrough(
          predicate<List<Category>>(
            (items) => items.any((item) => item.name == '家庭采购'),
          ),
        ),
      );
      await books.changeType('watch-book', BookType.family);
      await refreshed;
    },
  );
}
