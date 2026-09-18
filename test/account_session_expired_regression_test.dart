// 会话失效（401）与网络异常 的回归测试（账户体系 Phase 1）。
//
// 这组测试守护两条互相独立、绝不能混为一谈的边界：
//   1. **服务器明确 401 = 登录真的失效**：Token 必须不可再用（包括重启后），
//      actor 安全回到 user-local，状态可区分 expired，本地账务数据一字不动。
//   2. **网络异常 / 服务器 5xx ≠ 退出登录**：不得清 Token、不得清账号、不得改 actor。
//
// 401 由真实 HTTP 桩返回，客户端一侧是真实 SharedApi + 真实 HttpClient +
// 真实 SessionRepository + 真实 SharedBookSyncService，走的是生产代码路径。
import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/account/domain/account_session_status.dart';
import 'package:jizhang_app/features/sharing/application/shared_book_sync_service.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

import 'support/account_http_stub.dart';

const serverUserId = 'server-user-id';
const serverToken = 'server-token-1';

/// 只把凭证持久化换成内存实现；登录、HTTP、SQLite 与 Repository 全部是真的。
class VolatileSessionStorage implements SessionStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

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

/// 一整套真实客户端：真实 SQLite、真实 HTTP、真实会话门面与真实同步服务。
class Harness {
  Harness._({
    required this.stub,
    required this.database,
    required this.storage,
    required this.api,
    required this.session,
    required this.transactions,
    required this.sync,
  });

  final AccountHttpStub stub;
  final AppDatabase database;
  final VolatileSessionStorage storage;
  final SharedApi api;
  final SessionRepository session;
  final DriftTransactionRepository transactions;
  final SharedBookSyncService sync;

  static Future<Harness> start({
    StubResponse books = StubResponse.unauthorized,
  }) async {
    final stub = await AccountHttpStub.start();
    stub.respond = accountRoutes(books: books);
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded();
    final storage = VolatileSessionStorage();
    final api = SharedApi(baseUrl: stub.baseUrl);
    final session = SessionRepository(api, database, storage: storage);
    return Harness._(
      stub: stub,
      database: database,
      storage: storage,
      api: api,
      session: session,
      transactions: DriftTransactionRepository(database),
      sync: SharedBookSyncService(database, session),
    );
  }

  /// 游客先记一笔本地流水，再登录服务器账号。
  Future<void> signIn() async {
    await session.initialize();
    await transactions.create(guestExpense('guest-record-1', 38.5));
    await session.authenticate(username: 'lu_2026', password: 'secret');
    expect(session.accountStatus, AccountSessionStatus.authenticated);
    expect(await syncActor(database), serverUserId);
  }

  /// 模拟 App 重启：数据库与安全存储保留，HTTP 与会话对象全部重建。
  Future<(SharedApi, SessionRepository, SharedBookSyncService)> restart() async {
    final restartedApi = SharedApi(baseUrl: stub.baseUrl);
    final restartedSession = SessionRepository(
      restartedApi,
      database,
      storage: storage,
    );
    await restartedSession.initialize();
    return (
      restartedApi,
      restartedSession,
      SharedBookSyncService(database, restartedSession),
    );
  }

  Future<void> dispose() async {
    await sync.dispose();
    await session.dispose();
    api.close();
    await database.close();
    await stub.stop();
  }
}

void main() {
  setUp(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('服务器明确 401：标记 expired、Token 不可再用、actor 回 user-local，本地账务不动', () async {
    final harness = await Harness.start(books: StubResponse.unauthorized);
    addTearDown(harness.dispose);
    await harness.signIn();
    expect(harness.api.sessionToken, serverToken);

    await harness.sync.sync();

    // Token 清理且不可再次使用
    expect(harness.session.accountStatus, AccountSessionStatus.expired);
    expect(harness.api.sessionToken, isNull);
    expect(harness.storage.value, isNull, reason: '被拒绝的凭证不得留在安全存储里');
    // actor 安全回到 user-local
    expect(await syncActor(harness.database), SeedIds.localUser);
    expect(harness.database.currentActor, SeedIds.localUser);
    // Account 状态能够区分 expired
    expect(
      harness.session.accountStatus,
      isNot(AccountSessionStatus.guest),
      reason: 'expired 必须与“从未登录”区分开',
    );
    expect(harness.session.accountStatus, isNot(AccountSessionStatus.authenticated));
    expect(harness.session.user?.username, 'lu_2026', reason: '保留上一次身份用于提示重新登录');
    expect(harness.session.userId, isNull, reason: 'expired 不再代表可用的服务器身份');
    expect(harness.sync.lastError, '登录状态已失效');
    // 本地账务数据保持不变
    expect((await harness.transactions.getAll()).map((t) => t.id), ['guest-record-1']);
    expect(
      (await rawRow(harness.database, 'transactions', 'guest-record-1'))['user_id'],
      SeedIds.localUser,
    );
    expect(await rowCount(harness.database, 'sync_outbox'), 0);
    expect(await harness.database.canAccessBook(SeedIds.personalBook), isTrue);
  });

  test('401 之后重启 App：绝不重新使用已经被拒绝的 Token', () async {
    final harness = await Harness.start(books: StubResponse.unauthorized);
    addTearDown(harness.dispose);
    await harness.signIn();

    await harness.sync.sync();
    expect(harness.session.accountStatus, AccountSessionStatus.expired);
    expect(
      harness.stub.requestsWithToken(serverToken).map((r) => r.path),
      ['/api/v1/books'],
      reason: '被 401 拒绝的 Token 只出现在那次被拒绝的请求里',
    );

    final (restartedApi, restartedSession, restartedSync) = await harness.restart();
    addTearDown(() async {
      await restartedSync.dispose();
      await restartedSession.dispose();
      restartedApi.close();
    });

    // 重启后不带任何可用凭证
    expect(restartedApi.sessionToken, isNull, reason: '重启绝不能再使用被 401 拒绝的 Token');
    expect(restartedSession.user, isNull);
    expect(restartedSession.userId, isNull);
    expect(restartedSession.accountStatus, AccountSessionStatus.guest);
    expect(restartedSession.accountStatus, isNot(AccountSessionStatus.authenticated));
    expect(harness.storage.value, isNull);

    // 即使主动尝试同步，也不会再带着被拒绝的 Token 发请求
    await restartedSync.sync();
    expect(harness.stub.requestsWithToken(serverToken).length, 1);
    expect(
      harness.stub.paths.where((path) => path == '/api/v1/books').length,
      1,
      reason: '重启后不得再发起共享同步请求',
    );

    // 本地账务数据跨重启完好
    expect((await harness.transactions.getAll()).map((t) => t.id), ['guest-record-1']);
    expect(await harness.database.canAccessBook(SeedIds.personalBook), isTrue);
    expect(await syncActor(harness.database), SeedIds.localUser);
  });

  test('服务器 503：不得退出登录、不得清凭证', () async {
    final harness = await Harness.start(books: StubResponse.unavailable);
    addTearDown(harness.dispose);
    await harness.signIn();

    await harness.sync.sync();

    expect(harness.sync.lastError, '服务暂时不可用');
    expect(harness.session.accountStatus, AccountSessionStatus.authenticated);
    expect(harness.session.userId, serverUserId);
    expect(harness.api.sessionToken, serverToken);
    expect(harness.storage.value, isNotNull, reason: '非 401 不得清除本地凭证');
    expect(await syncActor(harness.database), serverUserId);
    expect((await harness.transactions.getAll()).map((t) => t.id), ['guest-record-1']);
  });

  test('网络不通：不得退出登录、不得清凭证', () async {
    final harness = await Harness.start();
    addTearDown(harness.dispose);
    await harness.signIn();

    // 服务器下线：之后的请求以连接失败告终，这是纯网络异常。
    await harness.stub.stop();
    await harness.sync.sync();

    expect(harness.sync.lastError, isNotNull);
    expect(harness.sync.lastError, contains('同步未完成'));
    expect(harness.session.accountStatus, AccountSessionStatus.authenticated);
    expect(harness.session.userId, serverUserId);
    expect(harness.api.sessionToken, serverToken);
    expect(harness.storage.value, isNotNull);
    expect(await syncActor(harness.database), serverUserId);
    expect(await harness.database.canAccessBook(SeedIds.personalBook), isTrue);
  });

  test('离线退出登录：SocketException 不得让本地登录态残留', () async {
    final harness = await Harness.start();
    addTearDown(harness.dispose);
    await harness.signIn();
    expect(harness.api.sessionToken, serverToken);

    // 服务端不可达，登出必须 best effort：本地清理一定完成，且不抛异常。
    await harness.stub.stop();
    await harness.session.logout();

    expect(harness.session.user, isNull);
    expect(harness.session.userId, isNull);
    expect(harness.session.accountStatus, AccountSessionStatus.guest);
    expect(harness.api.sessionToken, isNull);
    expect(harness.storage.value, isNull);
    expect(await syncActor(harness.database), SeedIds.localUser);
    expect(
      (await harness.transactions.getAll()).map((t) => t.id),
      ['guest-record-1'],
      reason: '退出登录不等于清空本地数据',
    );
    expect(await rowCount(harness.database, 'sync_outbox'), 0);

    // 重启后仍然是游客，离线登出不会复活登录态。
    final (restartedApi, restartedSession, restartedSync) = await harness.restart();
    addTearDown(() async {
      await restartedSync.dispose();
      await restartedSession.dispose();
      restartedApi.close();
    });
    expect(restartedSession.accountStatus, AccountSessionStatus.guest);
    expect(restartedSession.user, isNull);
    expect(restartedApi.sessionToken, isNull);
  });
}
