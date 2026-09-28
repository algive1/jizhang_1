import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  late AppDatabase database;
  late DriftTransactionRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTransactionRepository(database);
    await _insertAccount(database, 'cash', 100);
    await _insertAccount(database, 'bank', 100);
  });

  tearDown(() => database.close());

  test('scoped transaction range index is installed', () async {
    expect(database.schemaVersion, 25);
    final indexes = await database
        .customSelect("PRAGMA index_list('transactions')")
        .get();
    final names = indexes.map((row) => row.read<String>('name')).toSet();
    expect(names, contains('idx_transactions_book_deleted_occurred'));
    expect(names, contains('idx_transactions_related_type'));
    expect(names, contains('idx_transactions_reimbursement_status'));
    expect(names, contains('idx_transactions_type_occurred'));
    final attachmentIndexes = await database
        .customSelect("PRAGMA index_list('transaction_attachments')")
        .get();
    final attachmentNames = attachmentIndexes
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(
      attachmentNames,
      contains('idx_transaction_attachments_photo_gallery'),
    );
  });

  test(
    'create, update and soft-delete keep account balances correct',
    () async {
      final expense = _transaction(
        id: 'expense',
        type: TransactionType.expense,
        amount: 10,
        accountId: 'cash',
      );
      final income = _transaction(
        id: 'income',
        type: TransactionType.income,
        amount: 20,
        accountId: 'bank',
      );
      final transfer = _transaction(
        id: 'transfer',
        type: TransactionType.transfer,
        amount: 30,
        accountId: 'bank',
        destinationAccountId: 'cash',
      );

      await repository.create(expense);
      await repository.create(income);
      await repository.create(transfer);

      expect(await _balance(database, 'cash'), 120);
      expect(await _balance(database, 'bank'), 90);

      await repository.update(
        expense.copyWith(amount: 15, updatedAt: DateTime(2026, 8, 31, 13)),
      );
      expect(await _balance(database, 'cash'), 115);

      await repository.softDelete('income');
      expect(await _balance(database, 'bank'), 70);
      expect(
        (await repository.getAll()).map((item) => item.id),
        isNot(contains('income')),
      );

      await repository.softDelete('expense');
      expect(await _balance(database, 'cash'), 130);
      await repository.softDelete('transfer');
      expect(await _balance(database, 'bank'), 100);
      expect(await _balance(database, 'cash'), 100);

      // A repeated request must not roll the same balance back a second time.
      await repository.softDelete('income');
      await repository.softDelete('transfer');
      expect(await _balance(database, 'bank'), 100);

      final deleted = await database.transactionDao.findById('income');
      expect(deleted, isNotNull);
      expect(deleted!.deletedAt, isNotNull);
    },
  );

  test('transfer preserves total assets', () async {
    final before = await _totalBalance(database);
    await repository.create(
      _transaction(
        id: 'transfer',
        type: TransactionType.transfer,
        amount: 35.5,
        accountId: 'cash',
        destinationAccountId: 'bank',
      ),
    );
    expect(await _totalBalance(database), before);
  });

  test('import dedupe candidates are scoped to relevant identities', () async {
    final matchTime = DateTime(2026, 8, 31, 12);
    final oldTime = DateTime(2024, 1, 2, 8);

    for (final item in [
      _transaction(
        id: 'dedupe-time',
        type: TransactionType.expense,
        amount: 10,
        accountId: 'cash',
        occurredAt: matchTime,
        source: TransactionSource.import,
        metadataJson:
            '{"importFingerprint":"fp-time","importNaturalFingerprint":"natural-time"}',
      ),
      _transaction(
        id: 'dedupe-external',
        type: TransactionType.expense,
        amount: 11,
        accountId: 'cash',
        occurredAt: oldTime,
        source: TransactionSource.import,
        metadataJson:
            '{"importProvider":"wechat","externalId":"ORDER-42"}',
      ),
      _transaction(
        id: 'dedupe-auto-external',
        type: TransactionType.expense,
        amount: 12,
        accountId: 'cash',
        occurredAt: oldTime,
        source: TransactionSource.auto,
        metadataJson:
            '{"notificationOrderId":"AUTO-7","paymentPackageName":"com.tencent.mm"}',
      ),
      _transaction(
        id: 'dedupe-unrelated',
        type: TransactionType.expense,
        amount: 13,
        accountId: 'cash',
        occurredAt: DateTime(2023, 1, 1),
        source: TransactionSource.import,
        metadataJson:
            '{"importProvider":"wechat","externalId":"OTHER"}',
      ),
      _transaction(
        id: 'dedupe-manual-same-time',
        type: TransactionType.expense,
        amount: 14,
        accountId: 'cash',
        occurredAt: matchTime,
      ),
    ]) {
      await repository.create(item);
    }

    final candidates = await repository.getImportDedupCandidates(
      occurredAt: [matchTime],
      externalIds: const ['order-42', 'auto-7'],
      importFingerprints: const ['fp-time'],
      naturalFingerprints: const ['natural-time'],
    );

    expect(
      candidates.map((item) => item.id).toSet(),
      {
        'dedupe-time',
        'dedupe-external',
        'dedupe-auto-external',
      },
    );
  });

  test('expense candidates are filtered in SQLite', () async {
    for (final item in [
      _transaction(
        id: 'candidate-expense',
        type: TransactionType.expense,
        amount: 10,
        accountId: 'cash',
      ),
      _transaction(
        id: 'candidate-lend',
        type: TransactionType.lend,
        amount: 11,
        accountId: 'cash',
      ),
      _transaction(
        id: 'candidate-asset-purchase',
        type: TransactionType.assetPurchase,
        amount: 12,
        accountId: 'cash',
      ),
      _transaction(
        id: 'candidate-income',
        type: TransactionType.income,
        amount: 13,
        accountId: 'bank',
      ),
      _transaction(
        id: 'candidate-transfer',
        type: TransactionType.transfer,
        amount: 14,
        accountId: 'bank',
        destinationAccountId: 'cash',
      ),
    ]) {
      await repository.create(item);
    }

    final candidates = await repository.getExpenseCandidates();

    expect(
      candidates.map((item) => item.id).toSet(),
      {
        'candidate-expense',
        'candidate-lend',
        'candidate-asset-purchase',
      },
    );
  });

  test('soft-delete is scoped to the current book', () async {
    await repository.create(
      _transaction(
        id: 'scoped-expense',
        type: TransactionType.expense,
        amount: 10,
        accountId: 'cash',
      ),
    );
    final otherBook = DriftTransactionRepository(
      database,
      bookId: 'book-other',
    );

    await otherBook.softDelete('scoped-expense');

    expect(await repository.getById('scoped-expense'), isNotNull);
    expect(await _balance(database, 'cash'), 90);
  });

  test('transaction currency survives create and update', () async {
    await database.accountDao.writeFields(
      'cash',
      const AccountEntriesCompanion(currency: Value('USD')),
    );
    final transaction = _transaction(
      id: 'foreign-currency',
      type: TransactionType.expense,
      amount: 12.5,
      accountId: 'cash',
    ).copyWith(currency: 'USD');

    await repository.create(transaction);
    expect((await repository.getAll()).single.currency, 'USD');

    await repository.update(transaction.copyWith(amount: 15));
    expect((await repository.getAll()).single.currency, 'USD');
    await expectLater(
      repository.update(transaction.copyWith(currency: 'EUR')),
      throwsArgumentError,
    );
    expect((await repository.getAll()).single.currency, 'USD');
  });

  test('reimbursement and refund relations persist without duplicating the source row', () async {
    final original =
        _transaction(
          id: 'reimbursement-original',
          type: TransactionType.expense,
          amount: 500,
          accountId: 'cash',
        ).copyWith(
          reimbursementStatus: ReimbursementStatus.pending,
          reimbursementAmount: 500,
          reimbursementNote: '出差报销',
          refundStatus: RefundStatus.none,
        );
    await repository.create(original);

    final reimbursement = _transaction(
      id: 'reimbursement-payment',
      type: TransactionType.reimbursement,
      amount: 500,
      accountId: 'cash',
    ).copyWith(relatedTransactionId: original.id);
    await repository.create(reimbursement);

    final restored = await repository.getById(original.id);
    final related = await repository.getById(reimbursement.id);
    expect(restored?.reimbursementStatus, ReimbursementStatus.pending);
    expect(restored?.reimbursementAmount, 500);
    expect(related?.relatedTransactionId, original.id);
    expect(await _balance(database, 'cash'), 100);
    await expectLater(repository.softDelete(original.id), throwsStateError);
    expect(await repository.getById(original.id), isNotNull);
  });

  test('records survive closing and reopening the SQLite file', () async {
    await database.close();
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'jizhang-drift-test-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final file = File('${temporaryDirectory.path}/persistent.sqlite');

    final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
    database = firstDatabase;
    await _insertAccount(firstDatabase, 'wallet', 50);
    final firstRepository = DriftTransactionRepository(firstDatabase);
    await firstRepository.create(
      _transaction(
        id: 'persistent-expense',
        type: TransactionType.expense,
        amount: 12.34,
        accountId: 'wallet',
      ),
    );
    await firstDatabase.close();

    final reopenedDatabase = AppDatabase.forTesting(NativeDatabase(file));
    database = reopenedDatabase;
    final reopenedRepository = DriftTransactionRepository(reopenedDatabase);
    final records = await reopenedRepository.getAll();

    expect(records.single.id, 'persistent-expense');
    expect(records.single.amount, 12.34);
    expect(await _balance(reopenedDatabase, 'wallet'), 37.66);
  });
}

Future<void> _insertAccount(
  AppDatabase database,
  String id,
  double balance,
) async {
  final now = DateTime(2026, 8, 31, 12);
  await database.accountDao.insertOne(
    AccountEntriesCompanion.insert(
      id: id,
      name: id,
      type: 'cash',
      balanceInCents: Value((balance * 100).round()),
      icon: 'wallet',
      color: 0,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

TransactionRecord _transaction({
  required String id,
  required TransactionType type,
  required double amount,
  required String accountId,
  String? destinationAccountId,
  DateTime? occurredAt,
  TransactionSource source = TransactionSource.manual,
  String? metadataJson,
}) {
  final now = occurredAt ?? DateTime(2026, 8, 31, 12);
  return TransactionRecord(
    id: id,
    bookId: 'book-personal',
    type: type,
    amount: amount,
    accountId: accountId,
    destinationAccountId: destinationAccountId,
    occurredAt: now,
    createdAt: now,
    updatedAt: now,
    source: source,
    metadataJson: metadataJson,
  );
}

Future<double> _balance(AppDatabase database, String id) async {
  final account = await database.accountDao.findById(id);
  return account!.balanceInCents / 100;
}

Future<double> _totalBalance(AppDatabase database) async {
  final accounts = await database.accountDao.getActive();
  return accounts.fold<double>(
    0,
    (total, account) => total + account.balanceInCents / 100,
  );
}
