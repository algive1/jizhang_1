import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/recurring_bill.dart';
import '../../../core/models/transaction_record.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../books/data/book_repository.dart';

abstract interface class RecurringBillRepository {
  Stream<List<RecurringBill>> watchActive();
  Future<List<RecurringBill>> getAll();
  Future<List<RecurringBill>> getAllForNotification();
  Future<RecurringBill> create(RecurringBill bill);
  Future<RecurringBill> update(RecurringBill bill);
  Future<void> archive(String id);
}

class DriftRecurringBillRepository implements RecurringBillRepository {
  DriftRecurringBillRepository(this._database, {required this.bookId});

  final AppDatabase _database;
  final String bookId;

  @override
  Stream<List<RecurringBill>> watchActive() =>
      _database.recurringBillDao.watchActive(bookId: bookId).map(_map);

  @override
  Future<List<RecurringBill>> getAll() async =>
      _map(await _database.recurringBillDao.getAll(bookId: bookId));

  @override
  Future<List<RecurringBill>> getAllForNotification() async =>
      _map(await _database.recurringBillDao.getAll());

  @override
  Future<RecurringBill> create(RecurringBill bill) async {
    _validate(bill);
    if (bill.bookId != bookId) throw ArgumentError('周期账单必须属于当前账本');
    await _ensureReferences(bill);
    if (await _database.recurringBillDao.findById(bill.id) != null) {
      throw StateError('周期账单已存在');
    }
    await _database.recurringBillDao.insertOne(_toCompanion(bill));
    return bill;
  }

  @override
  Future<RecurringBill> update(RecurringBill bill) async {
    _validate(bill);
    if (bill.bookId != bookId) throw ArgumentError('周期账单必须属于当前账本');
    await _ensureReferences(bill);
    final existing = await _database.recurringBillDao.findById(bill.id);
    if (existing == null || existing.bookId != bookId) {
      throw StateError('周期账单不存在');
    }
    await _database.recurringBillDao.replaceOne(_toCompanion(bill));
    return bill;
  }

  @override
  Future<void> archive(String id) async {
    final existing = await _database.recurringBillDao.findById(id);
    if (existing == null || existing.bookId != bookId) return;
    final now = DateTime.now();
    await _database.recurringBillDao.replaceOne(
      _toCompanion(
        _map([existing]).single
            .copyWith(status: RecurringBillStatus.ended, updatedAt: now),
      ),
    );
  }

  void _validate(RecurringBill bill) {
    if (bill.interval < 1 ||
        bill.interval > 999 ||
        (bill.weekday != null && (bill.weekday! < 1 || bill.weekday! > 7)) ||
        (bill.month != null && (bill.month! < 1 || bill.month! > 12)) ||
        (bill.dayOfMonth != null &&
            bill.dayOfMonth != -1 &&
            (bill.dayOfMonth! < 1 || bill.dayOfMonth! > 31)) ||
        (bill.repeatCount != null && bill.repeatCount! < 1) ||
        bill.reminderDays < 0) {
      throw ArgumentError('周期规则不合法');
    }
    if (bill.name.trim().isEmpty) throw ArgumentError('周期账单名称不能为空');
    if (!bill.amount.isFinite || bill.amount <= 0) {
      throw ArgumentError('周期账单金额必须大于 0');
    }
    if (bill.cycle == RecurringBillCycle.custom &&
        (bill.customIntervalDays == null || bill.customIntervalDays! < 1)) {
      throw ArgumentError('自定义周期至少为 1 天');
    }
    if (bill.endDate != null && bill.endDate!.isBefore(bill.startDate)) {
      throw ArgumentError('结束日期不能早于开始日期');
    }
  }

  Future<void> _ensureReferences(RecurringBill bill) async {
    final book = await _database.familyDao.findBook(bill.bookId);
    if (book == null || book.isArchived) throw ArgumentError('账本不存在或已归档');
    final allowedAccountBooks = <String>{
      bill.bookId,
      if (book.assetSourceBookId != null) book.assetSourceBookId!,
    };
    if (bill.accountId != null) {
      final account = await _database.accountDao.findById(bill.accountId!);
      if (account == null ||
          account.isArchived ||
          !allowedAccountBooks.contains(account.bookId)) {
        throw ArgumentError('周期账单账户不存在或已归档');
      }
    }
    if (bill.categoryId != null) {
      final category = await _database.categoryDao.findById(bill.categoryId!);
      if (category == null ||
          category.isArchived ||
          category.bookId != bill.bookId ||
          category.type != (bill.isIncome ? 'income' : 'expense')) {
        throw ArgumentError('周期账单分类必须属于当前账本');
      }
    }
    if (bill.subcategoryId != null) {
      final child = await _database.categoryDao.findById(bill.subcategoryId!);
      if (child == null ||
          child.isArchived ||
          child.bookId != bill.bookId ||
          child.parentId != bill.categoryId) {
        throw ArgumentError('二级分类不属于所选分类');
      }
    }
  }

  List<RecurringBill> _map(List<RecurringBillEntity> rows) => [
    for (final row in rows)
      RecurringBill(
        interval: (jsonDecode(row.scheduleJson)['interval'] as int?) ?? 1,
        weekday: jsonDecode(row.scheduleJson)['weekday'] as int?,
        dayOfMonth: jsonDecode(row.scheduleJson)['day_of_month'] as int?,
        month: jsonDecode(row.scheduleJson)['month'] as int?,
        repeatCount: jsonDecode(row.scheduleJson)['repeat_count'] as int?,
        completedCount:
            (jsonDecode(row.scheduleJson)['completed_count'] as int?) ?? 0,
        reminderDays:
            (jsonDecode(row.scheduleJson)['reminder_days'] as int?) ?? 1,
        subcategoryId:
            jsonDecode(row.scheduleJson)['subcategory_id'] as String?,
        id: row.id,
        bookId: row.bookId,
        name: row.name,
        type: RecurringBillType.values.byName(row.type),
        amount: row.amountInCents / 100,
        cycle: RecurringBillCycle.values.byName(row.cycle),
        startDate: row.startDate,
        endDate: row.endDate,
        nextDate: row.nextDate,
        accountId: row.accountId,
        categoryId: row.categoryId,
        customIntervalDays: row.customIntervalDays,
        autoRecord: row.autoRecord,
        reminder: row.reminder,
        status: RecurringBillStatus.values.byName(row.status),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      ),
  ];

  RecurringBillEntriesCompanion _toCompanion(RecurringBill bill) =>
      RecurringBillEntriesCompanion(
        scheduleJson: Value(
          jsonEncode({
            'interval': bill.interval,
            'weekday': bill.weekday,
            'day_of_month': bill.dayOfMonth,
            'month': bill.month,
            'end_type': bill.endType,
            'repeat_count': bill.repeatCount,
            'completed_count': bill.completedCount,
            'reminder_days': bill.reminderDays,
            'subcategory_id': bill.subcategoryId,
          }),
        ),
        id: Value(bill.id),
        bookId: Value(bill.bookId),
        name: Value(bill.name.trim()),
        type: Value(bill.type.name),
        amountInCents: Value((bill.amount * 100).round()),
        cycle: Value(bill.cycle.name),
        startDate: Value(bill.startDate),
        endDate: Value(bill.endDate),
        nextDate: Value(bill.nextDate),
        accountId: Value(bill.accountId),
        categoryId: Value(bill.categoryId),
        customIntervalDays: Value(bill.customIntervalDays),
        autoRecord: Value(bill.autoRecord),
        reminder: Value(bill.reminder),
        status: Value(bill.status.name),
        createdAt: Value(bill.createdAt),
        updatedAt: Value(bill.updatedAt),
      );
}

final recurringBillRepositoryProvider = Provider<RecurringBillRepository>((
  ref,
) {
  return DriftRecurringBillRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});

final recurringBillsProvider = StreamProvider<List<RecurringBill>>((
  ref,
) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref.watch(recurringBillRepositoryProvider).watchActive();
});

final recurringBillsAllProvider = FutureProvider<List<RecurringBill>>((
  ref,
) async {
  await ref.watch(databaseBootstrapProvider.future);
  return ref.watch(recurringBillRepositoryProvider).getAll();
});

class RecurringBillExecutionService {
  const RecurringBillExecutionService(
    this._database,
    this._bookkeeping,
    this._transactions,
    this._recurringBills,
  );

  final AppDatabase _database;
  final QuickBookkeepingService _bookkeeping;
  final TransactionRepository _transactions;
  final RecurringBillRepository _recurringBills;

  Future<TransactionRecord> createWithInitial(
    RecurringBill bill,
    QuickBookkeepingRequest request,
  ) => _database.transaction(() async {
    if (request.metadata['recurring_bill_id'] != bill.id ||
        request.bookId != bill.bookId ||
        request.accountId != bill.accountId ||
        request.categoryId != bill.categoryId ||
        request.amount != bill.amount ||
        (request.type != TransactionType.income &&
            request.type != TransactionType.expense) ||
        (request.type == TransactionType.income) != bill.isIncome) {
      throw ArgumentError('当前流水与周期规则不一致');
    }
    await _recurringBills.create(bill);
    try {
      return await _bookkeeping.save(request);
    } on BookkeepingCommittedException catch (error) {
      throw StateError('流水和周期账单均未保存：${error.cause}');
    }
  });

  /// Records every due bill that explicitly opted into automatic recording.
  ///
  /// This is safe to call on app start/resume: each occurrence has a stable
  /// transaction id, so a retry after a process interruption cannot duplicate
  /// a payment. A small per-bill cap keeps a stale daily schedule from
  /// blocking the first frame; the next resume continues the backlog.
  Future<int> processDueAutoRecords({DateTime? now}) async {
    final cutoff = now ?? DateTime.now();
    final bills = await _recurringBills.getAll();
    var processed = 0;
    Object? firstError;

    for (final bill in bills.where(
      (item) => item.status == RecurringBillStatus.active && item.autoRecord,
    )) {
      var current = bill;
      var attempts = 0;
      while (current.status == RecurringBillStatus.active &&
          !current.nextDate.isAfter(cutoff) &&
          attempts < 366) {
        try {
          await recordDue(current, occurrence: current.nextDate);
          processed++;
          final latest = (await _recurringBills.getAll()).where(
            (item) => item.id == current.id,
          );
          if (latest.isEmpty) break;
          current = latest.single;
          attempts++;
        } catch (error) {
          firstError ??= error;
          break;
        }
      }
    }

    if (firstError != null) {
      throw StateError('部分周期账单自动记账失败：$firstError');
    }
    return processed;
  }

  Future<TransactionRecord> recordDue(
    RecurringBill bill, {
    DateTime? occurrence,
  }) => _database.transaction(() async {
    final latest = (await _recurringBills.getAll())
        .where((item) => item.id == bill.id)
        .firstOrNull;
    if (latest == null) throw StateError('周期账单不存在');
    final requestedDue = occurrence ?? bill.nextDate;
    final existingRecord = await _transactions.getById(
      'recurring-entry-${bill.id}-${_dateKey(requestedDue)}',
    );
    if (existingRecord != null) return existingRecord;
    bill = latest;
    if (requestedDue != bill.nextDate) throw StateError('周期账单已更新，请刷新后重试');
    if (bill.status != RecurringBillStatus.active) {
      throw StateError('该周期账单已暂停或结束');
    }
    final accountId = bill.accountId;
    if (accountId == null) throw StateError('请先为周期账单选择扣款账户');
    final account = await _database.accountDao.findById(accountId);
    if (account == null || account.isArchived) {
      throw StateError('周期账单账户不存在或已归档');
    }
    final due = bill.nextDate;
    if (occurrence == null && due.isAfter(DateTime.now())) {
      throw StateError('该周期账单尚未到期');
    }
    if (bill.endDate != null && due.isAfter(bill.endDate!)) {
      throw StateError('该周期账单已超过结束日期');
    }
    final transactionId = 'recurring-entry-${bill.id}-${_dateKey(due)}';
    final existing = await _transactions.getById(transactionId);
    if (existing != null) {
      await _advance(bill, due);
      return existing;
    }
    final saved = await _bookkeeping.save(
      QuickBookkeepingRequest(
        transactionId: transactionId,
        bookId: bill.bookId,
        type: bill.isIncome ? TransactionType.income : TransactionType.expense,
        amount: bill.amount,
        accountId: accountId,
        currency: account.currency,
        categoryId: bill.categoryId,
        subcategoryId: bill.subcategoryId,
        occurredAt: due,
        isRecurring: true,
        isOneTime: false,
        source: TransactionSource.auto,
        metadata: {
          'recurring_bill_id': bill.id,
          'recurring_occurrence': _dateKey(due),
        },
      ),
    );
    await _advance(bill, due);
    return saved;
  });

  Future<void> _advance(RecurringBill bill, DateTime due) async {
    final next = bill.nextOccurrence(due);
    final completed = bill.completedCount + 1;
    final ended =
        (bill.endDate != null && next.isAfter(bill.endDate!)) ||
        (bill.repeatCount != null && completed >= bill.repeatCount!);
    await _recurringBills.update(
      bill.copyWith(
        completedCount: completed,
        nextDate: next,
        status: ended ? RecurringBillStatus.ended : bill.status,
        updatedAt: DateTime.now(),
      ),
    );
  }

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

final recurringBillExecutionServiceProvider =
    Provider<RecurringBillExecutionService>((ref) {
      return RecurringBillExecutionService(
        ref.watch(databaseProvider),
        ref.watch(quickBookkeepingServiceProvider),
        ref.watch(transactionRepositoryProvider),
        ref.watch(recurringBillRepositoryProvider),
      );
    });

class RecurringAutoRecordError extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String? value) => state = value;
}

final recurringAutoRecordErrorProvider =
    NotifierProvider<RecurringAutoRecordError, String?>(
      RecurringAutoRecordError.new,
    );
