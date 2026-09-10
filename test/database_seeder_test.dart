import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';

void main() {
  test('default seed creates a clean account without demo financial data', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);

    await DatabaseSeeder(database).seedIfNeeded();

    final accounts = await database.accountDao.getActive();
    expect(accounts, hasLength(4));
    expect(accounts.every((account) => account.balanceInCents == 0), isTrue);
    expect(await database.transactionDao.getActive(), isEmpty);
    expect(await database.goalDao.getAllGoals(), isEmpty);
    final monthKey =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    expect(await database.budgetDao.getMonth(monthKey), isEmpty);
  });

  test('demo seed is explicit and remains available for previews', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);

    await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);

    expect(await database.transactionDao.getActive(), isNotEmpty);
    expect(await database.goalDao.getAllGoals(), isNotEmpty);
    final monthKey =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    expect(await database.budgetDao.getMonth(monthKey), isNotEmpty);
  });

  test(
    'seed migration removes legacy demo data from existing local databases',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);

      await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);
      await database.appSettingsDao.setValue(
        'seed_version',
        '4',
        DateTime(2026, 8, 31),
      );

      await DatabaseSeeder(database).seedIfNeeded();

      expect(await database.transactionDao.getActive(), isEmpty);
      expect(await database.goalDao.getAllGoals(), isEmpty);
      expect(
        (await database.accountDao.getActive()).every(
          (account) => account.balanceInCents == 0,
        ),
        isTrue,
      );
    },
  );
}
