import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/account.dart';
import '../../books/data/book_repository.dart';
import '../domain/account_management.dart';
import 'account_management_schema.dart';
import 'account_repository.dart';

abstract interface class AccountManagementRepository {
  Stream<List<ManagedAccount>> watchActive();
  Future<List<ManagedAccount>> getActive();
  Future<ManagedAccount?> getById(String id);
  Future<ManagedAccount> create({
    required Account account,
    required AccountFundCategory category,
    String? platform,
    RestrictedFundStatus? restrictedStatus,
    DateTime? expectedReturnAt,
    bool includeInTotal,
    String? note,
  });
  Future<void> updateMeta({
    required String accountId,
    required AccountFundCategory category,
    String? platform,
    RestrictedFundStatus? restrictedStatus,
    DateTime? expectedReturnAt,
    required bool includeInTotal,
    String? note,
  });
}

class DriftAccountManagementRepository implements AccountManagementRepository {
  DriftAccountManagementRepository(
    this._database,
    this._accounts, {
    required this.bookId,
  });

  final AppDatabase _database;
  final AccountRepository _accounts;
  final String bookId;

  @override
  Stream<List<ManagedAccount>> watchActive() async* {
    await ensureAccountManagementSchema(_database);
    yield* _accounts.watchActive().asyncMap(_decorate);
  }

  @override
  Future<List<ManagedAccount>> getActive() async {
    await ensureAccountManagementSchema(_database);
    return _decorate(await _accounts.getActive());
  }

  @override
  Future<ManagedAccount?> getById(String id) async {
    await ensureAccountManagementSchema(_database);
    final accounts = await _accounts.getAll();
    final account = accounts.where((item) => item.id == id).firstOrNull;
    if (account == null) return null;
    return (await _decorate([account])).single;
  }

  @override
  Future<ManagedAccount> create({
    required Account account,
    required AccountFundCategory category,
    String? platform,
    RestrictedFundStatus? restrictedStatus,
    DateTime? expectedReturnAt,
    bool includeInTotal = true,
    String? note,
  }) async {
    await ensureAccountManagementSchema(_database);
    late Account created;
    await _database.transaction(() async {
      created = await _accounts.create(account);
      await _writeMeta(
        accountId: created.id,
        category: category,
        platform: platform,
        restrictedStatus: restrictedStatus,
        expectedReturnAt: expectedReturnAt,
        includeInTotal: includeInTotal,
        note: note,
      );
      await _touch(created.id);
    });
    return (await _decorate([created])).single;
  }

  @override
  Future<void> updateMeta({
    required String accountId,
    required AccountFundCategory category,
    String? platform,
    RestrictedFundStatus? restrictedStatus,
    DateTime? expectedReturnAt,
    required bool includeInTotal,
    String? note,
  }) async {
    await ensureAccountManagementSchema(_database);
    final row = await _database.accountDao.findById(accountId);
    if (row == null || row.bookId != bookId) {
      throw StateError('当前账本中不存在该账户');
    }
    await _database.transaction(() async {
      await _writeMeta(
        accountId: accountId,
        category: category,
        platform: platform,
        restrictedStatus: restrictedStatus,
        expectedReturnAt: expectedReturnAt,
        includeInTotal: includeInTotal,
        note: note,
      );
      await _touch(accountId);
    });
  }

  Future<void> _writeMeta({
    required String accountId,
    required AccountFundCategory category,
    String? platform,
    RestrictedFundStatus? restrictedStatus,
    DateTime? expectedReturnAt,
    required bool includeInTotal,
    String? note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement(
      'INSERT INTO account_management_meta '
      '(id,book_id,account_id,fund_category,platform,restricted_status,expected_return_at,include_in_total,note,updated_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?) '
      'ON CONFLICT(account_id) DO UPDATE SET '
      'fund_category=excluded.fund_category,'
      'platform=excluded.platform,'
      'restricted_status=excluded.restricted_status,'
      'expected_return_at=excluded.expected_return_at,'
      'include_in_total=excluded.include_in_total,'
      'note=excluded.note,'
      'updated_at=excluded.updated_at',
      [
        accountId,
        bookId,
        accountId,
        category.name,
        _clean(platform),
        restrictedStatus?.name,
        expectedReturnAt?.millisecondsSinceEpoch,
        includeInTotal ? 1 : 0,
        _clean(note),
        now,
      ],
    );
  }

  Future<void> _touch(String accountId) {
    return _database.accountDao.writeFields(
      accountId,
      AccountEntriesCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  Future<List<ManagedAccount>> _decorate(List<Account> accounts) async {
    if (accounts.isEmpty) return const [];
    await ensureAccountManagementSchema(_database);
    final placeholders = List.filled(accounts.length, '?').join(',');
    final rows = await _database.customSelect(
      'SELECT account_id,fund_category,platform,restricted_status,'
      'expected_return_at,include_in_total,note '
      'FROM account_management_meta WHERE account_id IN ($placeholders)',
      variables: accounts.map((item) => Variable<String>(item.id)).toList(),
    ).get();
    final byId = {for (final row in rows) row.read<String>('account_id'): row};

    return accounts.map((account) {
      final row = byId[account.id];
      final rawCategory = row?.read<String>('fund_category');
      final category = AccountFundCategory.values.where(
        (item) => item.name == rawCategory,
      ).firstOrNull ?? AccountFundCategory.available;
      final rawRestricted = row?.readNullable<String>('restricted_status');
      final restrictedStatus = RestrictedFundStatus.values.where(
        (item) => item.name == rawRestricted,
      ).firstOrNull;
      final expected = row?.readNullable<int>('expected_return_at');
      return ManagedAccount(
        account: account,
        category: category,
        platform: row?.readNullable<String>('platform'),
        restrictedStatus: restrictedStatus,
        expectedReturnAt: expected == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expected),
        includeInTotal: (row?.readNullable<int>('include_in_total') ?? 1) != 0,
        note: row?.readNullable<String>('note'),
      );
    }).toList(growable: false);
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

final accountManagementRepositoryProvider =
    Provider<AccountManagementRepository>((ref) {
      final database = ref.watch(databaseProvider);
      final String? assetBookCandidate =
          ref.watch(activeBookProvider)?.assetBookId ??
          ref.watch(activeBookIdProvider);
      if (assetBookCandidate == null) {
        throw StateError('当前资产账本不可用');
      }
      final assetBookId = assetBookCandidate;
      return DriftAccountManagementRepository(
        database,
        DriftAccountRepository(database, bookId: assetBookId),
        bookId: assetBookId,
      );
    });

final managedAccountsProvider = StreamProvider<List<ManagedAccount>>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref.watch(accountManagementRepositoryProvider).watchActive();
});

/// Account IDs that remain visible but must be excluded from asset totals.
final excludedAssetAccountIdsProvider = StreamProvider<Set<String>>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  final database = ref.watch(databaseProvider);
  await ensureAccountManagementSchema(database);
  yield* database.accountDao.watchAll().asyncMap((_) async {
    final rows = await database.customSelect(
      'SELECT account_id FROM account_management_meta WHERE include_in_total=0',
    ).get();
    return rows.map((row) => row.read<String>('account_id')).toSet();
  });
});
