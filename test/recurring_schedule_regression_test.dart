import 'dart:io';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/recurring_bill.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/recurring/data/recurring_bill_repository.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

RecurringBill plan({RecurringBillCycle cycle = RecurringBillCycle.monthly, int? day = 31,
  int interval = 1, int? count, DateTime? end, int? weekday, int? month}) => RecurringBill(
  id: 'schedule-test', bookId: SeedIds.personalBook, name: '房租', amount: 50,
  type: RecurringBillType.rent, cycle: cycle, startDate: DateTime(2024, 1, 1), nextDate: DateTime(2024, 1, 31),
  dayOfMonth: day, interval: interval, repeatCount: count, endDate: end, weekday: weekday, month: month,
  accountId: SeedIds.cashAccount, categoryId: 'expense-food', createdAt: DateTime(2024), updatedAt: DateTime(2024));

class BrokenSettings implements AppSettingsRepository {
  @override Future<String?> get(String key) async => null;
  @override Future<void> set(String key, String value) async => throw StateError('disk failure');
}

void main() {
  test('monthly anchor survives February and explicit last day', () {
    final bill = plan();
    final feb = bill.nextOccurrence(DateTime(2024, 1, 31));
    expect(feb, DateTime(2024, 2, 29));
    expect(bill.nextOccurrence(feb), DateTime(2024, 3, 31));
    expect(plan(day: -1).nextOccurrence(DateTime(2025, 2, 28)), DateTime(2025, 3, 31));
    expect(plan(interval: 3).nextOccurrence(DateTime(2024, 1, 31)), DateTime(2024, 4, 30));
  });
  test('daily weekly yearly execution dates and leap years', () {
    expect(plan(cycle: RecurringBillCycle.daily, interval: 2).nextOccurrence(DateTime(2024, 2, 28)), DateTime(2024, 3, 1));
    expect(plan(cycle: RecurringBillCycle.weekly, weekday: 5).firstOccurrence(), DateTime(2024, 1, 5));
    final leap = plan(cycle: RecurringBillCycle.yearly, day: 29, month: 2);
    expect(leap.firstOccurrence(), DateTime(2024, 2, 29));
    expect(leap.nextOccurrence(DateTime(2024, 2, 29)), DateTime(2025, 2, 28));
    expect(leap.nextOccurrence(DateTime(2027, 2, 28)), DateTime(2028, 2, 29));
  });
  for (final fail in [false, true]) {
    test('initial transaction and plan are atomic, failure=$fail', () async {
      final db = createMemoryDatabase(); addTearDown(db.close); await DatabaseSeeder(db).seedIfNeeded();
      final repo = DriftRecurringBillRepository(db, bookId: SeedIds.personalBook);
      final tx = DriftTransactionRepository(db, bookId: SeedIds.personalBook);
      final service = RecurringBillExecutionService(db, QuickBookkeepingService(tx, fail ? BrokenSettings() : DriftAppSettingsRepository(db)), tx, repo);
      final before = (await db.accountDao.findById(SeedIds.cashAccount))!.balanceInCents;
      final request = QuickBookkeepingRequest(bookId: SeedIds.personalBook, type: TransactionType.expense,
        amount: 50, accountId: SeedIds.cashAccount, categoryId: 'expense-food', occurredAt: DateTime(2024),
        isRecurring: true, isOneTime: false, metadata: const {'recurring_bill_id': 'schedule-test'});
      if (fail) {
        await expectLater(service.createWithInitial(plan(), request), throwsStateError);
        expect(await repo.getAll(), isEmpty); expect(await tx.getAll(), isEmpty);
        expect((await db.accountDao.findById(SeedIds.cashAccount))!.balanceInCents, before);
      } else {
        await service.createWithInitial(plan(), request);
        expect(await repo.getAll(), hasLength(1)); expect(await tx.getAll(), hasLength(1));
        expect((await db.accountDao.findById(SeedIds.cashAccount))!.balanceInCents, before - 5000);
      }
    });
  }
  test('count end and stale retry cannot advance or debit twice', () async {
    final db = createMemoryDatabase(); addTearDown(db.close); await DatabaseSeeder(db).seedIfNeeded();
    final repo = DriftRecurringBillRepository(db, bookId: SeedIds.personalBook);
    final tx = DriftTransactionRepository(db, bookId: SeedIds.personalBook);
    final service = RecurringBillExecutionService(db, QuickBookkeepingService(tx, DriftAppSettingsRepository(db)), tx, repo);
    final bill = plan(count: 1); await repo.create(bill);
    await service.recordDue(bill); await service.recordDue(bill);
    final ended = (await repo.getAll()).single;
    expect(ended.status, RecurringBillStatus.ended); expect(ended.completedCount, 1);
    expect(await tx.getAll(), hasLength(1)); expect(ended.dayOfMonth, 31);
  });
  test('v16 migration preserves existing plan and defaults', () async {
    final dir = await Directory.systemTemp.createTemp('recurring-v16'); addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final original = AppDatabase.forTesting(NativeDatabase(file)); await DatabaseSeeder(original).seedIfNeeded();
    await DriftRecurringBillRepository(original, bookId: SeedIds.personalBook).create(plan()); await original.close();
    final old = sqlite.sqlite3.open(file.path); for (final row in old.select("SELECT name FROM sqlite_master WHERE type='trigger'")) { old.execute('DROP TRIGGER ${row['name']}'); } old.execute('ALTER TABLE recurring_bills DROP COLUMN schedule_json'); old.userVersion = 16; old.close();
    final db = AppDatabase.forTesting(NativeDatabase(file)); addTearDown(db.close);
    final bill = (await DriftRecurringBillRepository(db, bookId: SeedIds.personalBook).getAll()).single;
    expect(bill.name, '房租'); expect(bill.interval, 1); expect(bill.repeatCount, isNull); expect(db.schemaVersion, 18);
  });
}
