import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';

void main() {
  test('all book types pin dining first and other last, with children under their parent', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    final seeder = DatabaseSeeder(db);
    await seeder.seedIfNeeded();
    for (final type in BookType.values) {
      final bookId = type == BookType.personal
          ? SeedIds.personalBook
          : type.name;
      if (type != BookType.personal)
        await seeder.seedBookDefaults(bookId, type: type);
      final repository = DriftCategoryRepository(db, bookId: bookId);
      final all = await repository.getActive();
      for (final categoryType in CategoryType.values) {
        final roots = all
            .where((c) => c.parentId == null && c.type == categoryType)
            .toList();
        if (categoryType == CategoryType.expense)
          expect(roots.first.id, endsWith('expense-food'));
        expect(roots.last.name, startsWith('其他'));
        for (final root in roots) {
          final children = all.where((c) => c.parentId == root.id).toList();
          expect(
            all.skip(all.indexOf(root) + 1).take(children.length),
            children,
          );
        }
      }
      final template = all.first;
      await repository.create(
        Category(
          id: '$bookId-custom',
          bookId: bookId,
          name: '我的分类',
          icon: template.icon,
          type: CategoryType.expense,
          sortOrder: 999,
          isDefault: false,
          isArchived: false,
        ),
      );
      final roots = (await repository.getActive())
          .where((c) => c.parentId == null && c.type == CategoryType.expense)
          .toList();
      expect(roots.first.id, endsWith('expense-food'));
      expect(roots[roots.length - 2].name, '我的分类');
      expect(roots.last.name, startsWith('其他'));
    }
  });
}
