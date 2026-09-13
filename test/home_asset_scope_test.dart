import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';

void main() {
  test('new ledgers can opt into the primary ledger asset scope', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    );

    final shared = await repository.create(
      name: '旅行账本',
      type: BookType.personal,
      usePrimaryAssets: true,
    );
    final isolated = await repository.create(
      name: '装修账本',
      type: BookType.personal,
    );

    expect(shared.usesPrimaryAssets, isTrue);
    expect(shared.assetBookId, 'book-personal');
    expect(isolated.usesPrimaryAssets, isFalse);
    expect(isolated.assetBookId, isolated.id);
  });

  test(
    'account repository reads and writes the selected asset scope',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      );
      final shared = await repository.create(
        name: '共享资产账本',
        type: BookType.family,
        usePrimaryAssets: true,
      );
      final accounts = DriftAccountRepository(
        database,
        bookId: shared.assetBookId,
      );

      final primaryAccounts = await accounts.getAll();
      expect(primaryAccounts, isNotEmpty);
      expect(
        primaryAccounts.every((account) => account.bookId == 'book-personal'),
        isTrue,
      );
    },
  );

  test(
    'existing ledgers can switch between isolated and primary assets',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      );
      final book = await repository.create(
        name: '可切换账本',
        type: BookType.personal,
      );

      await repository.setUsePrimaryAssets(book.id, true);
      final sharedRow = await database.familyDao.findBook(book.id);
      expect(sharedRow?.assetSourceBookId, 'book-personal');

      await repository.setUsePrimaryAssets(book.id, false);
      final isolatedRow = await database.familyDao.findBook(book.id);
      expect(isolatedRow?.assetSourceBookId, isNull);
    },
  );
}
