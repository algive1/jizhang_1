import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';

void main() {
  test(
    'required account types validate and format identifier suffix',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      final repository = DriftAccountRepository(database);

      final bank = await repository.create(_account('bank', '招商银行', '7777'));
      expect(bank.displayName, '招商银行-7777');

      await expectLater(
        repository.create(_account('missing', '银行卡', null)),
        throwsArgumentError,
      );
      await expectLater(
        repository.create(_account('short', '银行卡', '123')),
        throwsArgumentError,
      );
      await expectLater(
        repository.create(_account('letters', '银行卡', '12a4')),
        throwsArgumentError,
      );
      await expectLater(
        repository.create(_account('duplicate', '另一张卡', '7777')),
        throwsArgumentError,
      );

      final updated = await repository.update(
        Account(
          bookId: bank.bookId,
          id: bank.id,
          name: '工资卡',
          type: AccountType.cash,
          balance: bank.balance,
          currency: bank.currency,
          icon: bank.icon,
          color: bank.color,
          sortOrder: bank.sortOrder,
          isArchived: bank.isArchived,
          assetForm: bank.assetForm,
          createdAt: bank.createdAt,
          updatedAt: bank.updatedAt,
        ),
      );
      expect(updated.displayName, '工资卡');
      expect((await repository.getAll()).single.identifierSuffix, isNull);
    },
  );

  test('same identifier suffix is allowed in different books', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DriftAccountRepository(
      database,
      bookId: 'book-a',
    ).create(_account('a-bank', '银行卡', '3827', bookId: 'book-a'));
    final other = DriftAccountRepository(database, bookId: 'book-b');
    final account = await other.create(
      _account('b-bank', '银行卡', '3827', bookId: 'book-b'),
    );
    expect(account.displayName, '银行卡-3827');
  });
}

Account _account(
  String id,
  String name,
  String? suffix, {
  String bookId = 'book-personal',
  AccountType type = AccountType.debitCard,
}) {
  final now = DateTime(2026, 9, 12);
  return Account(
    bookId: bookId,
    id: id,
    name: name,
    type: type,
    balance: 100,
    currency: 'CNY',
    icon: 'wallet',
    color: 0xff73963b,
    sortOrder: 0,
    isArchived: false,
    identifierSuffix: suffix,
    createdAt: now,
    updatedAt: now,
  );
}
