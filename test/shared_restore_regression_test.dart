import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/family/data/shared_family_service.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/sharing/application/shared_book_sync_service.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

class _MemorySessionStorage implements SessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async => this.value = value;
}

void main() {
  test('restored shared backup revalidates membership, preserves remote truth, and isolates users', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final temp = await Directory.systemTemp.createTemp('shared-restore-');
    final server = await Process.start(
      Platform.environment['NODE_BINARY'] ?? 'node',
      ['server/node_modules/tsx/dist/cli.mjs', 'server/src/main.ts'],
      environment: {
        'PORT': '0',
        'LEDGER_DB_PATH': '${temp.path}/server.sqlite',
      },
    );
    final address = Completer<String>();
    final errors = <String>[];
    final stdout = server.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          const prefix = 'Shared ledger listening at ';
          if (line.startsWith(prefix) && !address.isCompleted) {
            address.complete(line.substring(prefix.length));
          }
        });
    final stderr = server.stderr.transform(utf8.decoder).listen(errors.add);
    addTearDown(() async {
      server.kill();
      await server.exitCode;
      await stdout.cancel();
      await stderr.cancel();
      await temp.delete(recursive: true);
    });
    final base = await address.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () =>
          throw StateError('Local server did not start: ${errors.join()}'),
    );

    final ownerFile = File('${temp.path}/owner.sqlite');
    var ownerDb = AppDatabase.forTesting(NativeDatabase(ownerFile));
    await DatabaseSeeder(ownerDb).seedIfNeeded();
    final ownerApi = SharedApi(baseUrl: base);
    final ownerSession = SessionRepository(
      ownerApi,
      ownerDb,
      storage: _MemorySessionStorage(),
    );
    var ownerSync = SharedBookSyncService(ownerDb, ownerSession);
    await ownerSession.authenticate(
      username: 'restore_owner',
      password: 'local-test-password-owner',
      register: true,
    );
    final books = DriftBookRepository(ownerDb, LocalOnlyMembershipRepository());
    final family = await books.create(name: '恢复家庭账本', type: BookType.family);
    final ownerAccounts = DriftAccountRepository(ownerDb, bookId: family.id);
    final accountId = (await ownerAccounts.getActive()).single.id;
    await ownerAccounts.reconcileBalance(accountId, 100);
    await ownerSync.enableSharing(family.id);
    final remoteId = (await books.getForUser('user-local'))
        .firstWhere((book) => book.id == family.id)
        .sharedId!;

    final guestDb = AppDatabase.forTesting(NativeDatabase.memory());
    await DatabaseSeeder(guestDb).seedIfNeeded();
    final guestApi = SharedApi(baseUrl: base);
    final guestSession = SessionRepository(
      guestApi,
      guestDb,
      storage: _MemorySessionStorage(),
    );
    final guestSync = SharedBookSyncService(guestDb, guestSession);
    await guestSession.authenticate(
      username: 'restore_guest',
      password: 'local-test-password-guest',
      register: true,
    );
    final invitation = await SharedFamilyService(ownerSync)
        .createInvitation(familyId: remoteId);
    await SharedFamilyService(guestSync).acceptInvitation(invitation.code);
    final guestBook = (await DriftBookRepository(
      guestDb,
      LocalOnlyMembershipRepository(),
    ).getForUser('user-local')).firstWhere((book) => book.isShared);
    final guestAccountId = (await DriftAccountRepository(
      guestDb,
      bookId: guestBook.id,
    ).getActive()).single.id;

    TransactionRecord expense(
      String id,
      String book,
      String account,
      double amount,
    ) {
      final now = DateTime.now();
      return TransactionRecord(
        id: id,
        bookId: book,
        type: TransactionType.expense,
        amount: amount,
        currency: 'CNY',
        accountId: account,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );
    }

    // This draft and its outbox entry are the contents of the old backup.
    await DriftTransactionRepository(ownerDb)
        .create(expense('restored-idempotent-draft', family.id, accountId, 7));
    expect(await ownerSync.pending(family.id), hasLength(1));
    await ownerDb.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final backup = File('${temp.path}/old-shared-backup.sqlite');
    await ownerFile.copy(backup.path);

    // The server advances after the backup was taken.
    await DriftTransactionRepository(
      guestDb,
    ).create(expense('remote-new-expense', guestBook.id, guestAccountId, 11));
    await guestSync.sync();
    expect(await guestSync.pending(guestBook.id), isEmpty);

    await ownerSync.dispose();
    await ownerSession.dispose();
    ownerApi.close();
    await ownerDb.close();

    // Restore is staged exactly as the application does, then applied on reopen.
    final pending = File(
      '${ownerFile.path}${AppDatabase.pendingRestoreSuffix}',
    );
    await backup.copy(pending.path);
    await AppDatabase.applyPendingRestore(ownerFile);
    ownerDb = AppDatabase.forTesting(NativeDatabase(ownerFile));
    await DatabaseSeeder(ownerDb).seedIfNeeded();
    final restoredState =
        (await ownerDb
                .customSelect(
                  'SELECT access,cursor FROM sync_books WHERE book_id=?',
                  variables: [Variable(family.id)],
                )
                .getSingle())
            .data;
    expect(
      restoredState['access'],
      0,
      reason: 'restored membership must not be trusted',
    );
    expect(
      restoredState['cursor'],
      0,
      reason: 'restore must force server reconciliation',
    );

    final restoredApi = SharedApi(baseUrl: base);
    final restoredSession = SessionRepository(
      restoredApi,
      ownerDb,
      storage: _MemorySessionStorage(),
    );
    final restoredSync = SharedBookSyncService(ownerDb, restoredSession);
    await restoredSession.authenticate(
      username: 'restore_owner',
      password: 'local-test-password-owner',
    );
    await restoredSync.sync();
    expect(restoredSync.lastError, isNull);
    expect(await restoredSync.pending(family.id), isEmpty);
    await restoredSync
        .sync(); // idempotent replay must not duplicate the draft.
    await guestSync.sync();
    final serverSnapshot = await restoredApi.request(
      '/books/$remoteId/snapshot',
    );
    final serverTransactions = (serverSnapshot['entities'] as List)
        .cast<Map<String, dynamic>>()
        .where((row) => row['kind'] == 'transactions')
        .toList();
    final guestTransactions = await DriftTransactionRepository(guestDb)
        .getAll();
    expect(
      guestTransactions.where((row) => row.id == 'remote-new-expense'),
      hasLength(1),
    );
    expect(
      serverTransactions.where(
        (row) => (row['id'] as String).endsWith('restored-idempotent-draft'),
      ),
      hasLength(1),
    );
    expect(
      (await DriftAccountRepository(
        guestDb,
        bookId: guestBook.id,
      ).getActive()).single.balance,
      82,
    );

    // The same physical SQLite database changes identity. The previous user's
    // cache and any later draft must remain hidden and must never be uploaded.
    await DriftTransactionRepository(ownerDb)
        .create(expense('owner-private-draft', family.id, accountId, 13));
    expect(await restoredSync.pending(family.id), hasLength(1));
    await restoredSession.logout();
    await restoredSession.authenticate(
      username: 'restore_guest',
      password: 'local-test-password-guest',
    );
    await restoredSync.sync();
    final visibleAsGuest = await DriftBookRepository(
      ownerDb,
      LocalOnlyMembershipRepository(),
    ).getForUser('user-local');
    expect(visibleAsGuest.where((book) => book.id == family.id), isEmpty);
    expect(visibleAsGuest.where((book) => book.isShared), hasLength(1));
    await guestSync.sync();
    expect(
      (await DriftTransactionRepository(
        guestDb,
      ).getAll()).where((row) => row.id == 'owner-private-draft'),
      isEmpty,
    );
    expect(await restoredSync.pending(family.id), hasLength(1));

    await restoredSync.dispose();
    await restoredSession.dispose();
    restoredApi.close();
    await ownerDb.close();
    await guestSync.dispose();
    await guestSession.dispose();
    guestApi.close();
    await guestDb.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
