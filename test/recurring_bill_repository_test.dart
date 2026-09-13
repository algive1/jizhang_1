import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/recurring_bill.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'package:jizhang_app/features/recurring/data/recurring_bill_repository.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test(
    'recurring bills persist, validate custom cycles, and can be ended',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftRecurringBillRepository(
        database,
        bookId: SeedIds.personalBook,
      );
      final now = DateTime(2026, 9, 12);
      final bill = RecurringBill(
        id: 'recurring-rent',
        bookId: SeedIds.personalBook,
        name: '房租',
        type: RecurringBillType.rent,
        amount: 3000,
        cycle: RecurringBillCycle.monthly,
        startDate: now,
        nextDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await repository.create(bill);
      expect((await repository.getAll()).single.name, '房租');
      expect(bill.nextOccurrence(now), DateTime(2026, 10, 12));
      await repository.archive(bill.id);
      expect(await repository.watchActive().first, isEmpty);

      final invalid = RecurringBill(
        id: 'recurring-invalid',
        bookId: SeedIds.personalBook,
        name: '自定义',
        type: RecurringBillType.other,
        amount: 1,
        cycle: RecurringBillCycle.custom,
        startDate: now,
        nextDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await expectLater(repository.create(invalid), throwsArgumentError);
    },
  );

  test(
    'due auto record is idempotent and advances the next occurrence',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftRecurringBillRepository(
        database,
        bookId: SeedIds.personalBook,
      );
      final transactions = DriftTransactionRepository(
        database,
        bookId: SeedIds.personalBook,
      );
      final bill = RecurringBill(
        id: 'recurring-subscription',
        bookId: SeedIds.personalBook,
        name: '订阅',
        type: RecurringBillType.subscription,
        amount: 15,
        cycle: RecurringBillCycle.monthly,
        startDate: DateTime(2026, 9, 1),
        nextDate: DateTime(2026, 9, 1),
        accountId: SeedIds.bankAccount,
        categoryId: 'expense-food',
        autoRecord: true,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      await repository.create(bill);
      final service = RecurringBillExecutionService(
        database,
        QuickBookkeepingService(
          transactions,
          DriftAppSettingsRepository(database),
        ),
        transactions,
        repository,
      );
      final first = await service.recordDue(bill);
      final second = await service.recordDue(bill);
      expect(first.id, second.id);
      expect(
        (await transactions.getAll()).where((item) => item.id == first.id),
        hasLength(1),
      );
      expect(
        (await repository.getAll()).single.nextDate,
        DateTime(2026, 10, 1),
      );
    },
  );

  test('foreground scheduler catches up opted-in due occurrences', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftRecurringBillRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final transactions = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final bill = RecurringBill(
      id: 'recurring-catch-up',
      bookId: SeedIds.personalBook,
      name: '云盘',
      type: RecurringBillType.subscription,
      amount: 10,
      cycle: RecurringBillCycle.monthly,
      startDate: DateTime(2026, 9, 1),
      nextDate: DateTime(2026, 9, 1),
      accountId: SeedIds.bankAccount,
      categoryId: 'expense-food',
      autoRecord: true,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
    await repository.create(bill);
    final service = RecurringBillExecutionService(
      database,
      QuickBookkeepingService(
        transactions,
        DriftAppSettingsRepository(database),
      ),
      transactions,
      repository,
    );

    expect(await service.processDueAutoRecords(now: DateTime(2026, 11, 5)), 3);
    expect(
      (await transactions.getAll()).where((item) => item.isRecurring),
      hasLength(3),
    );
    expect((await repository.getAll()).single.nextDate, DateTime(2026, 12, 1));
  });
}
