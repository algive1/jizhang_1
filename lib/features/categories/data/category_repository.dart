import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../books/data/book_repository.dart';
import '../../../core/models/category.dart';

abstract interface class CategoryRepository {
  Stream<List<Category>> watchActive();
  Future<List<Category>> getActive();
  Future<List<Category>> getAll();
  Future<Category> create(Category category);
  Future<Category> update(Category category);
  Future<void> archive(String id);
  Future<void> reorder(List<Category> categories);
}

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._database, {this.bookId = 'book-personal'});

  final String bookId;

  final AppDatabase _database;

  @override
  Stream<List<Category>> watchActive() =>
      _database.categoryDao.watchActive(bookId: bookId).map(_map);

  @override
  Future<List<Category>> getActive() async {
    return _map(await _database.categoryDao.getActive(bookId: bookId));
  }

  @override
  Future<List<Category>> getAll() async {
    return _map(await _database.categoryDao.getAll(bookId: bookId));
  }

  @override
  Future<Category> create(Category category) async {
    if (category.name.trim().isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }
    if (await _database.categoryDao.findById(category.id) != null) {
      throw StateError('Category ${category.id} already exists');
    }
    await _validateParent(category);
    await _database.categoryDao.insertOne(_toCompanion(category));
    return _map([(await _database.categoryDao.findById(category.id))!]).single;
  }

  @override
  Future<Category> update(Category category) async {
    final existing = await _database.categoryDao.findById(category.id);
    if (existing == null || existing.bookId != bookId)
      throw StateError('Category ${category.id} not found');
    await _validateParent(category);
    await _database.categoryDao.upsert(_toCompanion(category));
    return _map([(await _database.categoryDao.findById(category.id))!]).single;
  }

  @override
  Future<void> archive(String id) async {
    final existing = await _database.categoryDao.findById(id);
    if (existing == null || existing.bookId != bookId) return;
    final all = await _database.categoryDao.getActive(bookId: bookId);
    await _database.transaction(() async {
      for (final category in all.where((item) => item.parentId == id)) {
        await _database.categoryDao.upsert(
          _entityToCompanion(category, archived: true),
        );
      }
      await _database.categoryDao.upsert(
        _entityToCompanion(existing, archived: true),
      );
    });
  }

  @override
  Future<void> reorder(List<Category> categories) async {
    await _database.transaction(() async {
      for (var index = 0; index < categories.length; index++) {
        final existing = await _database.categoryDao.findById(
          categories[index].id,
        );
        if (existing == null || existing.bookId != bookId)
          throw StateError('分类不属于当前账本');
        {
          await _database.categoryDao.upsert(
            _entityToCompanion(existing, sortOrder: index),
          );
        }
      }
    });
  }

  Future<void> _validateParent(Category category) async {
    final parentId = category.parentId;
    if (parentId == null) return;
    if (parentId == category.id) {
      throw ArgumentError('A category cannot be its own parent');
    }
    final parent = await _database.categoryDao.findById(parentId);
    if (parent == null ||
        parent.bookId != bookId ||
        parent.parentId != null ||
        parent.type != category.type.name) {
      throw ArgumentError('Parent category must be a root of the same type');
    }
  }

  List<Category> _map(List<CategoryEntity> rows) {
    return rows
        .map(
          (row) => Category(
            id: row.id,
            bookId: row.bookId,
            parentId: row.parentId,
            name: row.name,
            icon: row.icon,
            type: CategoryType.values.byName(row.type),
            sortOrder: row.sortOrder,
            isDefault: row.isDefault,
            isArchived: row.isArchived,
          ),
        )
        .toList(growable: false);
  }

  CategoryEntriesCompanion _toCompanion(Category category) {
    return CategoryEntriesCompanion(
      id: Value(category.id),
      bookId: Value(bookId),
      parentId: Value(category.parentId),
      name: Value(category.name.trim()),
      icon: Value(category.icon),
      type: Value(category.type.name),
      sortOrder: Value(category.sortOrder),
      isDefault: Value(category.isDefault),
      isArchived: Value(category.isArchived),
    );
  }

  CategoryEntriesCompanion _entityToCompanion(
    CategoryEntity category, {
    bool? archived,
    int? sortOrder,
  }) {
    return CategoryEntriesCompanion(
      id: Value(category.id),
      bookId: Value(bookId),
      parentId: Value(category.parentId),
      name: Value(category.name),
      icon: Value(category.icon),
      type: Value(category.type),
      sortOrder: Value(sortOrder ?? category.sortOrder),
      isDefault: Value(category.isDefault),
      isArchived: Value(archived ?? category.isArchived),
    );
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return DriftCategoryRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});

final categoriesByBookProvider = StreamProvider.family<List<Category>, String>((
  ref,
  bookId,
) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* DriftCategoryRepository(
    ref.watch(databaseProvider),
    bookId: bookId,
  ).watchActive();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref.watch(categoryRepositoryProvider).watchActive();
});

final allCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  await ref.watch(databaseBootstrapProvider.future);
  return ref.watch(categoryRepositoryProvider).getAll();
});
