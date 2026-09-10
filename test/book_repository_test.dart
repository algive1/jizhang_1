import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';

void main() {
  test('free users can create up to three active books', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    );

    final first = await repository.create(name: '旅行', type: BookType.personal);
    await repository.create(name: '装修', type: BookType.personal);

    expect(
      () => repository.create(name: '第四本', type: BookType.personal),
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
}
