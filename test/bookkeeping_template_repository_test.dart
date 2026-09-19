import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/bookkeeping_templates/data/bookkeeping_template_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('bookkeeping templates persist per book and support update/delete', () async {
    final firstBook = DriftBookkeepingTemplateRepository(
      database,
      bookId: 'book-a',
    );
    final secondBook = DriftBookkeepingTemplateRepository(
      database,
      bookId: 'book-b',
    );

    final created = newBookkeepingTemplate(
      bookId: 'book-a',
      accountId: 'wechat',
      categoryId: 'food',
      sortOrder: 0,
    ).copyWith(
      name: '工作日午餐',
      type: TransactionType.expense,
      amount: 28,
      merchant: '食堂',
    );
    await firstBook.save(created);

    await secondBook.save(
      newBookkeepingTemplate(
        bookId: 'book-b',
        accountId: 'cash',
        categoryId: 'salary',
        sortOrder: 0,
      ).copyWith(
        name: '另一个账本',
        type: TransactionType.income,
        amount: 100,
      ),
    );

    final first = await firstBook.list();
    expect(first, hasLength(1));
    expect(first.single.name, '工作日午餐');
    expect(first.single.amount, 28);
    expect(await secondBook.list(), hasLength(1));

    await firstBook.save(
      created.copyWith(
        name: '午餐',
        amount: 30,
        sortOrder: 2,
      ),
    );
    final updated = (await firstBook.list()).single;
    expect(updated.id, created.id);
    expect(updated.name, '午餐');
    expect(updated.amount, 30);
    expect(updated.sortOrder, 2);

    await firstBook.delete(created.id);
    expect(await firstBook.list(), isEmpty);
    expect(await secondBook.list(), hasLength(1));
  });

  test('template repository rejects invalid cross-book data', () async {
    final repository = DriftBookkeepingTemplateRepository(
      database,
      bookId: 'book-a',
    );
    final invalid = newBookkeepingTemplate(
      bookId: 'book-b',
      accountId: 'wechat',
      categoryId: 'food',
      sortOrder: 0,
    );
    expect(
      () => repository.save(invalid),
      throwsArgumentError,
    );
  });
}
