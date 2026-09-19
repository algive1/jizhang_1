import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/bookkeeping/data/bookkeeping_template_repository.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';

class _MemorySettings implements AppSettingsRepository {
  final values = <String, String>{};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test('bookkeeping templates are isolated by book and can update/delete', () async {
    final repository = SettingsBookkeepingTemplateRepository(_MemorySettings());

    final created = await repository.save(
      bookId: 'book-a',
      name: '工作日午餐',
      type: TransactionType.expense,
      amount: 28,
      accountId: 'wechat',
      categoryId: 'food',
      merchant: '食堂',
    );
    await repository.save(
      bookId: 'book-b',
      name: '另一个账本',
      type: TransactionType.income,
      amount: 100,
    );

    final first = await repository.list('book-a');
    expect(first, hasLength(1));
    expect(first.single.name, '工作日午餐');
    expect(first.single.amount, 28);

    final updated = await repository.save(
      id: created.id,
      bookId: 'book-a',
      name: '午餐',
      type: TransactionType.expense,
      amount: 30,
      accountId: 'wechat',
      categoryId: 'food',
    );
    expect(updated.id, created.id);
    expect((await repository.list('book-a')).single.amount, 30);
    expect(await repository.list('book-b'), hasLength(1));

    await repository.delete('book-a', created.id);
    expect(await repository.list('book-a'), isEmpty);
    expect(await repository.list('book-b'), hasLength(1));
  });
}
