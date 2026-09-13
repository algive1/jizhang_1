import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/book.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';

void main() {
  test('shared books owned by another user do not consume the quota', () {
    final shared = LedgerBook(
      id: 'shared',
      name: '共享账本',
      type: BookType.family,
      ownerUserId: 'user-owner',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      isArchived: false,
      sharedId: 'remote-shared',
      role: 'member',
    );

    expect(BookLimitPolicy.ownedCount([shared], ownerUserId: 'user-local'), 0);
    expect(BookLimitPolicy.ownedCount([shared], ownerUserId: 'user-owner'), 1);
  });

  test('free users can create up to ten active books', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    );

    final first = await repository.create(name: '旅行', type: BookType.personal);
    for (var index = 2; index <= 9; index++) {
      await repository.create(name: '账本$index', type: BookType.personal);
    }

    expect(
      () => repository.create(name: '第十一本', type: BookType.personal),
      throwsA(isA<BookLimitReachedException>()),
    );
    await repository.rename(first.id, '旅行计划');
    expect(
      (await repository.getForUser(SeedIds.localUser))
          .firstWhere((book) => book.id == first.id)
          .name,
      '旅行计划',
    );
  });

  test(
    'book deletion is a confirmed archive and protects the default book',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      );
      final book = await repository.create(
        name: '待删除',
        type: BookType.personal,
      );

      await repository.archive(book.id);
      expect(
        (await repository.getForUser(SeedIds.localUser))
            .any((item) => item.id == book.id),
        isFalse,
      );
      expect(() => repository.archive(SeedIds.personalBook), throwsStateError);
    },
  );

  test('book order and default book preference persist locally', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    );
    final family = await repository.create(name: '家庭账本', type: BookType.family);
    final work = await repository.create(
      name: '工作账本',
      type: BookType.enterprise,
    );

    await repository.reorder([family.id, SeedIds.personalBook, work.id]);
    expect(
      (await repository.getForUser(SeedIds.localUser))
          .map((book) => book.id)
          .toList(),
      [family.id, SeedIds.personalBook, work.id],
    );

    await repository.setDefault(family.id);
    expect(
      await database.appSettingsDao.getValue(defaultBookIdSettingKey),
      family.id,
    );
  });
}
