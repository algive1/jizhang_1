import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/utils/entity_id.dart';
import '../../books/data/book_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/account_management.dart';
import 'account_management_schema.dart';

abstract interface class ReceivableRepository {
  Future<List<Receivable>> getAll();
  Future<Receivable?> getById(String id);
  Future<List<ReceivableEvent>> getEvents(String receivableId);
  Future<double> getCollectedBetween(DateTime start, DateTime end);
  Future<Receivable> create(Receivable receivable);
  Future<Receivable> update(Receivable receivable);
  Future<void> collect({
    required String receivableId,
    required double amount,
    required String destinationAccountId,
  });
  Future<void> writeOff(String receivableId);
  Future<void> setReminder(String receivableId, DateTime? reminderAt);
  Future<void> addEvent({
    required String receivableId,
    required String eventType,
    required String title,
    String? description,
  });
}

class DriftReceivableRepository implements ReceivableRepository {
  DriftReceivableRepository(
    this._database, {
    required this.bookId,
    required this.transactionBookId,
  });

  final AppDatabase _database;
  final String bookId;
  final String transactionBookId;

  @override
  Future<List<Receivable>> getAll() async {
    await ensureAccountManagementSchema(_database);
    final rows = await _database.customSelect(
      'SELECT * FROM receivables WHERE book_id=? ORDER BY created_at DESC',
      variables: [Variable<String>(bookId)],
    ).get();
    return rows.map(_mapReceivable).toList(growable: false);
  }

  @override
  Future<Receivable?> getById(String id) async {
    await ensureAccountManagementSchema(_database);
    final rows = await _database.customSelect(
      'SELECT * FROM receivables WHERE id=? AND book_id=? LIMIT 1',
      variables: [Variable<String>(id), Variable<String>(bookId)],
    ).get();
    return rows.isEmpty ? null : _mapReceivable(rows.single);
  }

  @override
  Future<List<ReceivableEvent>> getEvents(String receivableId) async {
    await ensureAccountManagementSchema(_database);
    final rows = await _database.customSelect(
      'SELECT e.* FROM receivable_events e '
      'INNER JOIN receivables r ON r.id=e.receivable_id '
      'WHERE e.receivable_id=? AND r.book_id=? ORDER BY e.created_at ASC',
      variables: [
        Variable<String>(receivableId),
        Variable<String>(bookId),
      ],
    ).get();
    return rows.map(_mapEvent).toList(growable: false);
  }

  @override
  Future<double> getCollectedBetween(DateTime start, DateTime end) async {
    await ensureAccountManagementSchema(_database);
    final row = await _database.customSelect(
      'SELECT COALESCE(SUM(e.amount_in_cents),0) AS total '
      'FROM receivable_events e '
      'INNER JOIN receivables r ON r.id=e.receivable_id '
      'WHERE r.book_id=? AND e.created_at>=? AND e.created_at<? '
      'AND e.event_type IN ("collected","partial_collected")',
      variables: [
        Variable<String>(bookId),
        Variable<int>(start.millisecondsSinceEpoch),
        Variable<int>(end.millisecondsSinceEpoch),
      ],
    ).getSingle();
    return row.read<int>('total') / 100;
  }

  @override
  Future<Receivable> create(Receivable receivable) async {
    await ensureAccountManagementSchema(_database);
    if (receivable.bookId != bookId) {
      throw ArgumentError('应收必须属于当前资金账本');
    }
    if (!receivable.totalAmount.isFinite || receivable.totalAmount <= 0) {
      throw ArgumentError('应收金额必须大于 0');
    }
    if (receivable.name.trim().isEmpty) throw ArgumentError('请填写应收名称');
    if (receivable.counterparty.trim().isEmpty) {
      throw ArgumentError('请填写往来对象');
    }
    await _database.transaction(() async {
      await _database.customStatement(
        'INSERT INTO receivables '
        '(id,book_id,name,type,counterparty,total_amount_in_cents,received_amount_in_cents,'
        'occurred_at,expected_at,reminder_at,status,business_status,remark,created_at,updated_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          receivable.id,
          receivable.bookId,
          receivable.name.trim(),
          receivable.type.name,
          receivable.counterparty.trim(),
          _toCents(receivable.totalAmount),
          _toCents(receivable.receivedAmount),
          receivable.occurredAt.millisecondsSinceEpoch,
          receivable.expectedAt?.millisecondsSinceEpoch,
          receivable.reminderAt?.millisecondsSinceEpoch,
          receivable.status.name,
          receivable.businessStatus.trim(),
          _clean(receivable.remark),
          receivable.createdAt.millisecondsSinceEpoch,
          receivable.updatedAt.millisecondsSinceEpoch,
        ],
      );
      await _insertEvent(
        receivable.id,
        eventType: 'created',
        title: '创建应收',
        description: '记录应收信息',
      );
    });
    _notifyReceivablesChanged();
    return (await getById(receivable.id))!;
  }

  @override
  Future<Receivable> update(Receivable receivable) async {
    await ensureAccountManagementSchema(_database);
    if (receivable.bookId != bookId) {
      throw ArgumentError('应收必须属于当前资金账本');
    }
    if (receivable.name.trim().isEmpty) throw ArgumentError('请填写应收名称');
    if (receivable.counterparty.trim().isEmpty) {
      throw ArgumentError('请填写往来对象');
    }
    final current = await getById(receivable.id);
    if (current == null) throw StateError('应收记录不存在');
    if (receivable.totalAmount + 0.000001 < current.receivedAmount) {
      throw ArgumentError('应收总额不能小于已收回金额');
    }
    final now = DateTime.now();
    final completed =
        current.receivedAmount + 0.000001 >= receivable.totalAmount;
    final nextStatus = completed
        ? ReceivableStatus.completed
        : current.status == ReceivableStatus.completed
        ? ReceivableStatus.pending
        : current.status;
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE receivables SET name=?,type=?,counterparty=?,total_amount_in_cents=?,'
        'occurred_at=?,expected_at=?,reminder_at=?,status=?,business_status=?,remark=?,updated_at=? '
        'WHERE id=? AND book_id=?',
        [
          receivable.name.trim(),
          receivable.type.name,
          receivable.counterparty.trim(),
          _toCents(receivable.totalAmount),
          receivable.occurredAt.millisecondsSinceEpoch,
          receivable.expectedAt?.millisecondsSinceEpoch,
          receivable.reminderAt?.millisecondsSinceEpoch,
          nextStatus.name,
          completed ? '已完成' : receivable.businessStatus.trim(),
          _clean(receivable.remark),
          now.millisecondsSinceEpoch,
          receivable.id,
          bookId,
        ],
      );
      final statusChanged =
          current.businessStatus.trim() != receivable.businessStatus.trim();
      await _insertEvent(
        receivable.id,
        eventType: statusChanged ? 'status_changed' : 'edited',
        title: statusChanged
            ? receivable.businessStatus.trim()
            : '编辑应收',
        description: statusChanged
            ? '状态由“${current.businessStatus}”更新为“${receivable.businessStatus.trim()}”'
            : '更新应收信息',
      );
    });
    _notifyReceivablesChanged();
    return (await getById(receivable.id))!;
  }

  @override
  Future<void> collect({
    required String receivableId,
    required double amount,
    required String destinationAccountId,
  }) async {
    if (!amount.isFinite || amount <= 0) throw ArgumentError('收回金额必须大于 0');
    await ensureAccountManagementSchema(_database);
    await _database.transaction(() async {
      final current = await getById(receivableId);
      if (current == null) throw StateError('应收记录不存在');
      if (current.status == ReceivableStatus.completed ||
          current.status == ReceivableStatus.writtenOff) {
        throw StateError('该应收已结束');
      }
      if (amount - current.remainingAmount > 0.000001) {
        throw ArgumentError('收回金额不能超过剩余待收金额');
      }

      final now = DateTime.now();
      await DriftTransactionRepository(
        _database,
        bookId: transactionBookId,
        accountBookId: bookId,
      ).create(
        TransactionRecord(
          id: 'receivable-${newEntityId()}',
          bookId: transactionBookId,
          userId: _database.currentActor,
          type: TransactionType.adjustment,
          amount: amount,
          currency: 'CNY',
          accountId: destinationAccountId,
          merchant: current.counterparty,
          note: '应收收回 · ${current.name}',
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
          metadataJson: jsonEncode({
            'receivableId': current.id,
            'receivableCollection': true,
          }),
          createdBy: _database.currentActor,
          updatedBy: _database.currentActor,
        ),
      );

      final received = current.receivedAmount + amount;
      final completed = received + 0.000001 >= current.totalAmount;
      await _database.customStatement(
        'UPDATE receivables SET received_amount_in_cents=?,status=?,business_status=?,updated_at=? '
        'WHERE id=? AND book_id=?',
        [
          _toCents(received),
          completed ? ReceivableStatus.completed.name : ReceivableStatus.partial.name,
          completed ? '已完成' : '部分回收',
          now.millisecondsSinceEpoch,
          current.id,
          bookId,
        ],
      );
      await _insertEvent(
        current.id,
        eventType: completed ? 'collected' : 'partial_collected',
        title: completed ? '已全部收回' : '部分收回',
        description: '到账 ¥${amount.toStringAsFixed(2)}',
        amount: amount,
      );
    });
    _notifyReceivablesChanged();
  }

  @override
  Future<void> writeOff(String receivableId) async {
    await ensureAccountManagementSchema(_database);
    await _database.transaction(() async {
      final current = await getById(receivableId);
      if (current == null) throw StateError('应收记录不存在');
      if (current.status == ReceivableStatus.completed) {
        throw StateError('已完成应收不能核销');
      }
      final now = DateTime.now();
      await _database.customStatement(
        'UPDATE receivables SET status=?,business_status=?,updated_at=? WHERE id=? AND book_id=?',
        [
          ReceivableStatus.writtenOff.name,
          '已核销',
          now.millisecondsSinceEpoch,
          current.id,
          bookId,
        ],
      );
      await _insertEvent(
        current.id,
        eventType: 'written_off',
        title: '核销应收',
        description: current.remainingAmount > 0
            ? '核销剩余 ¥${current.remainingAmount.toStringAsFixed(2)}'
            : null,
      );
    });
    _notifyReceivablesChanged();
  }

  @override
  Future<void> setReminder(String receivableId, DateTime? reminderAt) async {
    await ensureAccountManagementSchema(_database);
    final current = await getById(receivableId);
    if (current == null) throw StateError('应收记录不存在');
    if (current.status == ReceivableStatus.completed ||
        current.status == ReceivableStatus.writtenOff) {
      throw StateError('已结束的应收不能设置提醒');
    }
    final now = DateTime.now();
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE receivables SET reminder_at=?,updated_at=? WHERE id=? AND book_id=?',
        [
          reminderAt?.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
          receivableId,
          bookId,
        ],
      );
      await _insertEvent(
        receivableId,
        eventType: 'reminder',
        title: reminderAt == null ? '取消提醒' : '设置提醒',
        description: reminderAt == null
            ? '已取消提醒'
            : '提醒日期 ${_formatDate(reminderAt)}',
      );
    });
    _notifyReceivablesChanged();
  }

  @override
  Future<void> addEvent({
    required String receivableId,
    required String eventType,
    required String title,
    String? description,
  }) async {
    await ensureAccountManagementSchema(_database);
    final current = await getById(receivableId);
    if (current == null) throw StateError('应收记录不存在');
    await _insertEvent(
      receivableId,
      eventType: eventType,
      title: title,
      description: description,
    );
    _notifyReceivablesChanged();
  }

  void _notifyReceivablesChanged() {
    _database.notifyUpdates({
      TableUpdate.onTable(_database.accountEntries),
    });
  }

  Future<void> _insertEvent(
    String receivableId, {
    required String eventType,
    required String title,
    String? description,
    double? amount,
  }) {
    return _database.customStatement(
      'INSERT INTO receivable_events '
      '(id,book_id,receivable_id,event_type,title,description,amount_in_cents,created_at) '
      'VALUES (?,?,?,?,?,?,?,?)',
      [
        'receivable-event-${newEntityId()}',
        bookId,
        receivableId,
        eventType,
        title,
        _clean(description),
        amount == null ? null : _toCents(amount),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Receivable _mapReceivable(QueryRow row) {
    final rawStatus = row.read<String>('status');
    return Receivable(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      name: row.read<String>('name'),
      type: ReceivableType.values.where(
        (item) => item.name == row.read<String>('type'),
      ).firstOrNull ?? ReceivableType.other,
      counterparty: row.read<String>('counterparty'),
      totalAmount: row.read<int>('total_amount_in_cents') / 100,
      receivedAmount: row.read<int>('received_amount_in_cents') / 100,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('occurred_at'),
      ),
      expectedAt: row.readNullable<int>('expected_at') == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('expected_at'),
            ),
      reminderAt: row.readNullable<int>('reminder_at') == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('reminder_at'),
            ),
      status: ReceivableStatus.values.where(
        (item) => item.name == rawStatus,
      ).firstOrNull ?? ReceivableStatus.pending,
      businessStatus: row.read<String>('business_status'),
      remark: row.readNullable<String>('remark'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
      ),
    );
  }

  ReceivableEvent _mapEvent(QueryRow row) => ReceivableEvent(
    id: row.read<String>('id'),
    receivableId: row.read<String>('receivable_id'),
    eventType: row.read<String>('event_type'),
    title: row.read<String>('title'),
    description: row.readNullable<String>('description'),
    amount: row.readNullable<int>('amount_in_cents') == null
        ? null
        : row.read<int>('amount_in_cents') / 100,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('created_at'),
    ),
  );

  int _toCents(double value) => (value * 100).round();

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

final receivableRepositoryProvider = Provider<ReceivableRepository>((ref) {
  final activeBook = ref.watch(activeBookProvider);
  final assetBookId = activeBook == null
      ? ref.watch(activeBookIdProvider)
      : activeBook.assetBookId;
  return DriftReceivableRepository(
    ref.watch(databaseProvider),
    bookId: assetBookId,
    transactionBookId: ref.watch(activeBookIdProvider),
  );
});

final receivableDataSignalProvider = StreamProvider<int>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  final database = ref.watch(databaseProvider);
  var revision = 0;
  await for (final _ in database.accountDao.watchAll()) {
    yield revision++;
  }
});

final receivablesProvider = FutureProvider<List<Receivable>>((ref) async {
  ref.watch(receivableDataSignalProvider);
  await ref.watch(databaseBootstrapProvider.future);
  final manual = await ref.watch(receivableRepositoryProvider).getAll();
  final transactions =
      ref.watch(transactionsProvider).value ?? const <TransactionRecord>[];
  final projected = transactions
      .where(
        (item) =>
            item.reimbursementStatus != ReimbursementStatus.none &&
            item.type == TransactionType.expense,
      )
      .map((item) {
        final partial =
            item.reimbursementStatus == ReimbursementStatus.partial;
        final completed =
            item.reimbursementStatus == ReimbursementStatus.reimbursed;
        return Receivable(
          id: 'reimbursement-projection-${item.id}',
          bookId: item.bookId,
          name: item.displayTitle,
          type: ReceivableType.reimbursement,
          counterparty: '公司报销',
          totalAmount: item.amount,
          receivedAmount: completed
              ? item.amount
              : partial
              ? (item.reimbursementAmount ?? 0)
              : 0,
          occurredAt: item.occurredAt,
          expectedAt: null,
          reminderAt: null,
          status: completed
              ? ReceivableStatus.completed
              : partial
              ? ReceivableStatus.partial
              : ReceivableStatus.pending,
          businessStatus: completed
              ? '已完成'
              : partial
              ? '部分回收'
              : '待报销',
          remark: item.reimbursementNote,
          sourceTransactionId: item.id,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        );
      })
      .toList(growable: false);
  return [...manual, ...projected];
});

final receivableEventsProvider =
    FutureProvider.family<List<ReceivableEvent>, String>((ref, id) async {
      ref.watch(receivableDataSignalProvider);
      await ref.watch(databaseBootstrapProvider.future);
      return ref.watch(receivableRepositoryProvider).getEvents(id);
    });

final receivableMonthCollectedProvider = FutureProvider<double>((ref) async {
  ref.watch(receivableDataSignalProvider);
  await ref.watch(databaseBootstrapProvider.future);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);
  final manual = await ref
      .watch(receivableRepositoryProvider)
      .getCollectedBetween(start, end);
  final transactions =
      ref.watch(transactionsProvider).value ?? const <TransactionRecord>[];
  final reimbursements = transactions
      .where(
        (item) =>
            item.type == TransactionType.reimbursement &&
            !item.occurredAt.isBefore(start) &&
            item.occurredAt.isBefore(end),
      )
      .fold<double>(0, (sum, item) => sum + item.amount);
  return manual + reimbursements;
});
