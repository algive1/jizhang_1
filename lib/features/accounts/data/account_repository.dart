import '../../../core/utils/entity_id.dart';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../books/data/book_repository.dart';
import '../../../core/models/transaction_record.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../../core/models/account.dart';

abstract interface class AccountRepository {
  Stream<List<Account>> watchActive();
  Stream<List<Account>> watchAll();
  Future<List<Account>> getAll();
  Future<void> restore(String id);
  Future<void> reconcileBalance(String id, double balance);
  Future<List<Account>> getActive();
  Future<Account> create(Account account);
  Future<Account> update(Account account);
  Future<void> archive(String id);
  Future<void> reorder(List<String> accountIds);
}

class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this._database, {this.bookId = 'book-personal'});

  final String bookId;

  final AppDatabase _database;

  @override
  Stream<List<Account>> watchActive() =>
      _database.accountDao.watchActive(bookId: bookId).map(_map);

  @override
  Future<List<Account>> getActive() async {
    return _map(await _database.accountDao.getActive(bookId: bookId));
  }

  @override
  Stream<List<Account>> watchAll() =>
      _database.accountDao.watchAll(bookId: bookId).map(_map);

  @override
  Future<List<Account>> getAll() async =>
      _map(await _database.accountDao.getAll(bookId: bookId));

  @override
  Future<Account> create(Account account) async {
    if (!account.balance.isFinite) throw ArgumentError('请输入有效余额');
    if (account.name.trim().isEmpty) {
      throw ArgumentError('Account name cannot be empty');
    }
    if (await _database.accountDao.findById(account.id) != null) {
      throw StateError('Account ${account.id} already exists');
    }
    await _database.accountDao.insertOne(_toCompanion(account));
    return _map([(await _database.accountDao.findById(account.id))!]).single;
  }

  @override
  Future<Account> update(Account account) async {
    await _requireOwned(account.id);
    if (account.name.trim().isEmpty) throw ArgumentError('账户名称不能为空');
    await _database.accountDao.writeFields(
      account.id,
      AccountEntriesCompanion(
        name: Value(account.name.trim()),
        type: Value(account.type.name),
        icon: Value(account.icon),
        color: Value(account.color),
        assetForm: Value(account.assetForm.name),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return _map([(await _database.accountDao.findById(account.id))!]).single;
  }

  @override
  Future<void> archive(String id) => _setArchived(id, true);

  @override
  Future<void> restore(String id) => _setArchived(id, false);

  Future<void> _setArchived(String id, bool archived) async {
    await _requireOwned(id);
    await _database.accountDao.writeFields(
      id,
      AccountEntriesCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _requireOwned(String id) async {
    final row = await _database.accountDao.findById(id);
    if (row == null || row.bookId != bookId) throw StateError('当前账本中不存在该账户');
  }

  @override
  Future<void> reconcileBalance(String id, double balance) async {
    if (!balance.isFinite) throw ArgumentError('请输入有效余额');
    await _database.transaction(() async {
      final account = await _database.accountDao.findById(id);
      if (account == null || account.bookId != bookId)
        throw StateError('当前账本中不存在该账户');
      if (account.isArchived) throw StateError('请先恢复该账户');
      final targetCents = (balance * 100).round();
      final delta = targetCents - account.balanceInCents;
      if (delta == 0) return;
      final now = DateTime.now();
      await DriftTransactionRepository(_database, bookId: bookId).create(
        TransactionRecord(
          id: 'balance-adjustment-${newEntityId()}',
          bookId: account.bookId,
          userId: _database.currentActor,
          type: TransactionType.adjustment,
          amount: delta / 100,
          currency: account.currency,
          accountId: id,
          merchant: '余额校准',
          note:
              '${account.name}：${(account.balanceInCents / 100).toStringAsFixed(2)} → ${(targetCents / 100).toStringAsFixed(2)}',
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
          createdBy: _database.currentActor,
          updatedBy: _database.currentActor,
        ),
      );
    });
  }

  @override
  Future<void> reorder(List<String> accountIds) {
    return _database.accountDao.reorderActive(accountIds, bookId: bookId);
  }

  List<Account> _map(List<AccountEntity> rows) {
    return rows
        .map(
          (row) => Account(
            id: row.id,
            bookId: row.bookId,
            name: row.name,
            type: AccountType.values.byName(row.type),
            balance: row.balanceInCents / 100,
            openingBalance: row.openingBalanceInCents / 100,
            currency: row.currency,
            assetForm: AssetForm.values.byName(row.assetForm),
            icon: row.icon,
            color: row.color,
            sortOrder: row.sortOrder,
            isArchived: row.isArchived,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        )
        .toList(growable: false);
  }

  AccountEntriesCompanion _toCompanion(Account account) {
    return AccountEntriesCompanion(
      id: Value(account.id),
      bookId: Value(bookId),
      name: Value(account.name.trim()),
      type: Value(account.type.name),
      balanceInCents: Value((account.balance * 100).round()),
      openingBalanceInCents: Value(
        ((account.openingBalance ?? account.balance) * 100).round(),
      ),
      currency: Value(account.currency),
      assetForm: Value(account.assetForm.name),
      icon: Value(account.icon),
      color: Value(account.color),
      sortOrder: Value(account.sortOrder),
      isArchived: Value(account.isArchived),
      createdAt: Value(account.createdAt),
      updatedAt: Value(account.updatedAt),
    );
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return DriftAccountRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});

final accountsProvider = StreamProvider<List<Account>>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref.watch(accountRepositoryProvider).watchActive();
});

final allAccountsProvider = StreamProvider<List<Account>>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref.watch(accountRepositoryProvider).watchAll();
});
