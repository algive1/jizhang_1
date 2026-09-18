import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/account/domain/account_session_status.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

/// 迁移前测试里使用的注入式凭证存储，签名与行为都与当时一致。
class MemorySessionStorage implements SessionStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

const baseUrl = 'http://127.0.0.1:8787';

String legacyEnvelope({
  String id = 'user-1',
  String username = 'lu_2026',
  String token = 'legacy-token',
  int daysValid = 30,
  String url = baseUrl,
}) => jsonEncode({
  'token': token,
  'expiresAt':
      DateTime.now().add(Duration(days: daysValid)).millisecondsSinceEpoch ~/
      1000,
  'user': {'id': id, 'username': username},
  'baseUrl': url,
});

/// 写一条最普通的本地支出流水，用来证明账户状态变化不会碰本地数据。
Future<void> writeLocalExpense(AppDatabase database) async {
  final now = DateTime(2026, 9, 18, 12);
  await DriftTransactionRepository(database).create(
    TransactionRecord(
      id: 'local-record-1',
      bookId: SeedIds.personalBook,
      type: TransactionType.expense,
      amount: 12,
      accountId: SeedIds.cashAccount,
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<String?> syncActor(AppDatabase database) async {
  final rows = await database
      .customSelect('SELECT actor_id FROM sync_control WHERE id=1')
      .get();
  return rows.isEmpty ? null : rows.first.data['actor_id'] as String?;
}

Future<(AppDatabase, SessionRepository, SharedApi, MemorySessionStorage)>
createSession(String? stored) async {
  final database = createMemoryDatabase();
  await DatabaseSeeder(database).seedIfNeeded();
  final storage = MemorySessionStorage()..value = stored;
  final api = SharedApi(baseUrl: baseUrl);
  final session = SessionRepository(api, database, storage: storage);
  return (database, session, api, storage);
}

void main() {
  setUp(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('覆盖安装的旧 Token 继续可用，并被接管为统一账户会话', () async {
    final (database, session, api, _) = await createSession(legacyEnvelope());
    addTearDown(database.close);
    addTearDown(session.dispose);
    addTearDown(api.close);

    await session.initialize();

    expect(session.user?.id, 'user-1');
    expect(session.user?.username, 'lu_2026');
    expect(session.userId, 'user-1');
    expect(session.accountStatus, AccountSessionStatus.authenticated);
    expect(api.sessionToken, 'legacy-token', reason: 'Token 必须回填给 HTTP 层');
    expect(await syncActor(database), 'user-1');
  });

  test('旧会话本地已过期时按游客处理并清空凭证', () async {
    final (database, session, api, storage) = await createSession(
      legacyEnvelope(daysValid: -1),
    );
    addTearDown(database.close);
    addTearDown(session.dispose);
    addTearDown(api.close);

    await session.initialize();

    expect(session.user, isNull);
    expect(api.sessionToken, isNull);
    expect(await syncActor(database), 'user-local');
    expect(storage.value, isNull);
  });

  test('服务端地址不同的旧会话不会被复用', () async {
    final (database, session, api, storage) = await createSession(
      legacyEnvelope(url: 'https://other.example'),
    );
    addTearDown(database.close);
    addTearDown(session.dispose);
    addTearDown(api.close);

    await session.initialize();

    expect(session.user, isNull);
    expect(api.sessionToken, isNull);
    expect(storage.value, isNotNull, reason: '地址不匹配时保留原凭证，回到正确环境仍可恢复');
  });

  test('损坏的旧凭证按游客处理，且绝不动本地记账数据', () async {
    final (database, session, api, _) = await createSession('{损坏的 JSON');
    addTearDown(database.close);
    addTearDown(session.dispose);
    addTearDown(api.close);
    await writeLocalExpense(database);

    await session.initialize();

    expect(session.user, isNull);
    expect(
      (await DriftTransactionRepository(database).getAll()).length,
      1,
      reason: '登录态异常不能删除本地数据',
    );
  });

  test('可写的 user 字段仍能注入已登录身份（旧测试依赖）', () async {
    final (database, session, api, _) = await createSession(null);
    addTearDown(database.close);
    addTearDown(session.dispose);
    addTearDown(api.close);

    session.user = const SessionUser('test-user', '测试用户');
    await pumpEventQueue();

    expect(session.user?.id, 'test-user');
    expect(session.accountStatus, AccountSessionStatus.authenticated);
  });

  test('logout 清凭证、actor 回到 user-local，本地流水完整保留', () async {
    final (database, session, api, storage) = await createSession(
      legacyEnvelope(),
    );
    addTearDown(database.close);
    addTearDown(session.dispose);
    addTearDown(api.close);
    await writeLocalExpense(database);
    await session.initialize();
    expect(session.userId, 'user-1');

    await session.logout();

    expect(session.user, isNull);
    expect(session.userId, isNull);
    expect(session.accountStatus, AccountSessionStatus.guest);
    expect(api.sessionToken, isNull);
    expect(storage.value, isNull);
    expect(await syncActor(database), 'user-local');
    expect(
      (await DriftTransactionRepository(database).getAll()).length,
      1,
      reason: '退出登录不等于清空数据',
    );
  });

  test('markSessionExpired 标记失效并清 Token，本地数据仍可用', () async {
    final (database, session, api, _) = await createSession(legacyEnvelope());
    addTearDown(database.close);
    addTearDown(session.dispose);
    addTearDown(api.close);
    await session.initialize();

    await session.markSessionExpired();

    expect(session.accountStatus, AccountSessionStatus.expired);
    expect(session.user?.username, 'lu_2026', reason: '保留身份用于重新登录提示');
    expect(session.userId, isNull, reason: '失效会话不再代表服务器身份');
    expect(api.sessionToken, isNull);
    expect(await syncActor(database), 'user-local');
  });
}
