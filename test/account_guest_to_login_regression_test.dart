// 游客 → 服务器账号登录 的账务数据回归测试（账户体系 Phase 1）。
//
// 这组测试守护的是 Phase 1 最重要的一条产品承诺：
// **登录只是获得服务器身份，不会重写、迁移或绑定本地账务数据。**
//
// 因此断言全部落在真实 SQLite 行上（books / accounts / transactions /
// sync_* 表），而不是落在内存对象上；本地账本可见性走的是仓库自己的
// visibleBooksSql ACL，而不是测试自造的查询。
import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/account/domain/account_session_status.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

import 'support/account_http_stub.dart';

const serverUserId = 'server-user-id';

/// 只把凭证持久化换成内存实现；登录、HTTP、SQLite 与 Repository 全部是真的。
class VolatileSessionStorage implements SessionStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

/// 游客自己记的一笔支出。
TransactionRecord guestExpense(String id, double amount) {
  final now = DateTime(2026, 9, 18, 10);
  return TransactionRecord(
    id: id,
    bookId: SeedIds.personalBook,
    type: TransactionType.expense,
    amount: amount,
    accountId: SeedIds.cashAccount,
    occurredAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

Future<String?> syncActor(AppDatabase database) async {
  final rows = await database
      .customSelect('SELECT actor_id FROM sync_control WHERE id=1')
      .get();
  return rows.isEmpty ? null : rows.first.data['actor_id'] as String?;
}

Future<int> rowCount(AppDatabase database, String table) async =>
    (await database.customSelect('SELECT COUNT(*) AS c FROM $table').get())
        .first
        .read<int>('c');

Future<Map<String, Object?>> rawRow(
  AppDatabase database,
  String table,
  String id,
) async => (await database
        .customSelect(
          'SELECT * FROM $table WHERE id=?',
          variables: [Variable(id)],
        )
        .getSingle())
    .data;

/// 仓库自己的账本可见性 ACL，不依赖 currentActor 判断本地个人账本。
Future<List<String>> visibleBookIds(AppDatabase database) async =>
    (await database
            .customSelect(
              'SELECT id FROM books WHERE ${SharedSyncSchema.visibleBooksSql('id')}',
            )
            .get())
        .map((row) => row.read<String>('id'))
        .toList();

void main() {
  setUp(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('游客本地账本/账户/流水在服务器登录后完整保留：可见、可读、可继续记账，不绑定不同步', () async {
    final stub = await AccountHttpStub.start();
    addTearDown(stub.stop);
    // /books 只会被云同步调用；这个测试不允许它被调用，所以故意让它 401。
    stub.respond = accountRoutes();

    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final storage = VolatileSessionStorage();
    final api = SharedApi(baseUrl: stub.baseUrl);
    addTearDown(api.close);
    final session = SessionRepository(api, database, storage: storage);
    addTearDown(session.dispose);
    final transactions = DriftTransactionRepository(database);

    // ── 1. 游客状态：currentActor = user-local ──────────────────────────────
    await session.initialize();

    expect(session.user, isNull);
    expect(session.accountStatus, AccountSessionStatus.guest);
    expect(await syncActor(database), SeedIds.localUser);
    expect(database.currentActor, SeedIds.localUser);

    // ── 2. 游客创建：本地个人账本 + 本地账户 + 本地流水 ──────────────────────
    final book = await database.familyDao.findBook(SeedIds.personalBook);
    expect(book, isNotNull, reason: '本地个人账本必须存在');
    expect(book!.ownerUserId, SeedIds.localUser);
    expect(book.familyId, isNull, reason: '游客账本不属于任何服务器家庭');
    expect(book.isArchived, isFalse);

    final account = await database.accountDao.findById(SeedIds.cashAccount);
    expect(account, isNotNull, reason: '本地账户必须存在');
    expect(account!.bookId, SeedIds.personalBook);

    await transactions.create(guestExpense('guest-record-1', 38.5));
    expect(await rowCount(database, 'transactions'), 1);
    expect(
      (await rawRow(database, 'transactions', 'guest-record-1'))['user_id'],
      SeedIds.localUser,
      reason: '游客期记账的归属就是 user-local',
    );

    // ── 3. 模拟服务器账号登录：currentActor = server-user-id ────────────────
    await session.authenticate(username: 'lu_2026', password: 'secret');

    expect(session.user?.id, serverUserId);
    expect(session.userId, serverUserId);
    expect(session.accountStatus, AccountSessionStatus.authenticated);
    expect(await syncActor(database), serverUserId);
    expect(database.currentActor, serverUserId);

    // ── 4. 原本地个人账本仍然可见 ──────────────────────────────────────────
    expect(await database.canAccessBook(SeedIds.personalBook), isTrue);
    expect(await visibleBookIds(database), contains(SeedIds.personalBook));

    // ── 5. 原账户仍然可读 ─────────────────────────────────────────────────
    expect((await database.accountDao.findById(SeedIds.cashAccount))?.name, '现金');

    // ── 6. 原流水仍然可读 ─────────────────────────────────────────────────
    final visible = await transactions.getAll();
    expect(visible.map((item) => item.id), contains('guest-record-1'));
    expect((await transactions.getById('guest-record-1'))?.amount, 38.5);

    // ── 7. owner_user_id 仍然是 user-local ────────────────────────────────
    final afterLogin = await database.familyDao.findBook(SeedIds.personalBook);
    expect(afterLogin!.ownerUserId, SeedIds.localUser);

    // ── 8. 没有把账务记录批量改成 server user_id ──────────────────────────
    final raw = await rawRow(database, 'transactions', 'guest-record-1');
    expect(raw['user_id'], SeedIds.localUser);
    expect(raw['amount_in_cents'], 3850);
    expect(raw['book_id'], SeedIds.personalBook);
    expect(raw['account_id'], SeedIds.cashAccount);
    expect(raw['sync_status'], 'localOnly');

    // ── 9. 可以继续向原个人账本新增流水 ────────────────────────────────────
    await transactions.create(guestExpense('guest-record-2', 12));
    final added = await transactions.getById('guest-record-2');
    expect(added, isNotNull);
    expect(added!.bookId, SeedIds.personalBook);
    expect(await rowCount(database, 'transactions'), 2);

    // ── 10. 没有触发云同步 ────────────────────────────────────────────────
    expect(await rowCount(database, 'sync_outbox'), 0, reason: '本地账本不得产生待同步操作');
    expect(await rowCount(database, 'sync_books'), 0, reason: '本地账本不得被登记为共享账本');
    expect(await rowCount(database, 'sync_promotions'), 0);
    expect(await rowCount(database, 'sync_id_map'), 0);
    expect(
      stub.paths,
      ['/api/v1/auth/login'],
      reason: '登录之外不得发出任何同步请求',
    );

    // ── 11. 没有自动做数据绑定 ────────────────────────────────────────────
    expect(
      (await database.familyDao.findBook(SeedIds.personalBook))!.familyId,
      isNull,
      reason: '登录不得把本地账本绑定到服务器家庭/数据集',
    );
    expect(await rowCount(database, 'families'), 0);
  });

  test('登录后登出：actor 回到 user-local，本地账本与流水一字不动', () async {
    final stub = await AccountHttpStub.start();
    addTearDown(stub.stop);
    stub.respond = accountRoutes();

    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final storage = VolatileSessionStorage();
    final api = SharedApi(baseUrl: stub.baseUrl);
    addTearDown(api.close);
    final session = SessionRepository(api, database, storage: storage);
    addTearDown(session.dispose);
    final transactions = DriftTransactionRepository(database);

    await session.initialize();
    await transactions.create(guestExpense('guest-record-1', 38.5));
    await session.authenticate(username: 'lu_2026', password: 'secret');
    expect(await syncActor(database), serverUserId);

    await session.logout();

    expect(session.user, isNull);
    expect(session.accountStatus, AccountSessionStatus.guest);
    expect(await syncActor(database), SeedIds.localUser);
    expect((await database.familyDao.findBook(SeedIds.personalBook))!.ownerUserId, SeedIds.localUser);
    expect(await visibleBookIds(database), contains(SeedIds.personalBook));
    expect((await transactions.getAll()).map((item) => item.id), ['guest-record-1']);
    expect(
      (await rawRow(database, 'transactions', 'guest-record-1'))['user_id'],
      SeedIds.localUser,
      reason: '登出同样不得重写本地流水的归属',
    );
    expect(await rowCount(database, 'sync_outbox'), 0);
    expect(
      stub.paths,
      ['/api/v1/auth/login', '/api/v1/auth/logout'],
      reason: '登出只调用服务端登出接口，不触发同步',
    );
  });
}
