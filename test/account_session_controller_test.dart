import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/account/application/account_session_controller.dart';
import 'package:jizhang_app/features/account/data/secure_session_storage.dart';
import 'package:jizhang_app/features/account/domain/account_session.dart';
import 'package:jizhang_app/features/account/domain/account_session_status.dart';
import 'package:jizhang_app/features/account/domain/account_user.dart';

void main() {
  const baseUrl = 'http://127.0.0.1:8787';
  const user = AccountUser(id: 'user-1', username: 'lu_2026');
  final now = DateTime(2026, 9, 18, 10);

  AccountSessionController controllerFor(
    InMemorySessionStorage storage, {
    DateTime? clock,
  }) => AccountSessionController(
    storage,
    baseUrl: baseUrl,
    clock: clock == null ? null : () => clock,
  );

  test('空存储启动后是游客状态', () async {
    final storage = InMemorySessionStorage();
    final controller = controllerFor(storage);
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.status, AccountSessionStatus.guest);
    expect(controller.user, isNull);
    expect(controller.currentUserId, isNull);
    expect(controller.hasUsableSession, isFalse);
  });

  test('旧会话在启动时迁移到规范键，用户不需要重新登录', () async {
    final storage = InMemorySessionStorage(
      legacy: LegacySessionPayload(
        user: user,
        token: 'legacy-token',
        expiresAt: now.add(const Duration(days: 30)),
        baseUrl: baseUrl,
      ),
    );
    final controller = controllerFor(storage, clock: now);
    addTearDown(controller.dispose);

    await controller.start();

    expect(controller.status, AccountSessionStatus.authenticated);
    expect(controller.user, user);
    expect(controller.token, 'legacy-token');
    expect(controller.currentUserId, 'user-1');
    expect(controller.hasUsableSession, isTrue);
    // 迁移结果同时写回规范键和旧键。
    expect(storage.canonical, isA<Map<String, dynamic>>());
    expect(
      LegacySessionPayload.tryParse(storage.legacy)?.token,
      'legacy-token',
    );
  });

  test('旧会话本地已过期时清理存储且不恢复身份', () async {
    final storage = InMemorySessionStorage(
      legacy: LegacySessionPayload(
        user: user,
        token: 'legacy-token',
        expiresAt: now.subtract(const Duration(days: 1)),
        baseUrl: baseUrl,
      ),
    );
    final controller = controllerFor(storage, clock: now);
    addTearDown(controller.dispose);

    await controller.start();

    expect(controller.status, AccountSessionStatus.guest);
    expect(storage.canonical, isNull);
    expect(storage.legacy, isNull);
  });

  test('服务端地址变化时绝不复用旧会话', () async {
    final storage = InMemorySessionStorage(
      legacy: LegacySessionPayload(
        user: user,
        token: 'legacy-token',
        expiresAt: now.add(const Duration(days: 30)),
        baseUrl: 'https://other.example',
      ),
    );
    final controller = controllerFor(storage, clock: now);
    addTearDown(controller.dispose);

    await controller.start();

    expect(controller.status, AccountSessionStatus.guest);
    expect(
      LegacySessionPayload.tryParse(storage.legacy)?.token,
      'legacy-token',
      reason: '地址不匹配时保留原会话，只拒绝当前构建使用它',
    );
  });

  test('规范会话本地过期时标记失效并清理存储', () async {
    final storage = InMemorySessionStorage(
      canonical: AccountSession(
        user: user,
        token: 'token-1',
        expiresAt: now.subtract(const Duration(minutes: 1)),
        baseUrl: baseUrl,
      ).toJson(),
    );
    final controller = controllerFor(storage, clock: now);
    addTearDown(controller.dispose);

    await controller.start();

    expect(controller.status, AccountSessionStatus.expired);
    expect(controller.token, isNull);
    expect(controller.user, user);
    expect(storage.canonical, isNull);
  });

  test('安全存储读取失败时为 error 状态，不误判为已退出', () async {
    final controller = AccountSessionController(
      _ThrowingStorage(),
      baseUrl: baseUrl,
    );
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.status, AccountSessionStatus.error);
    expect(controller.user, isNull);
  });

  test('signIn 写入存储并广播新会话', () async {
    final storage = InMemorySessionStorage();
    final controller = controllerFor(storage);
    addTearDown(controller.dispose);
    final seen = <AccountSessionStatus>[];
    final subscription = controller.watch().listen(
      (session) => seen.add(session.status),
    );
    addTearDown(subscription.cancel);

    // 等待 watch() 先发出当前值（游客），再验证登录后的广播。
    await pumpEventQueue();
    expect(seen, [AccountSessionStatus.guest]);

    await controller.signIn(
      user: user,
      token: 'token-1',
      expiresAt: now.add(const Duration(days: 30)),
    );
    await pumpEventQueue();

    expect(seen, [
      AccountSessionStatus.guest,
      AccountSessionStatus.authenticated,
    ]);
    expect(
      LegacySessionPayload.tryParse(storage.legacy)?.token,
      'token-1',
      reason: '旧版本仍能读取同一个 Token',
    );
  });

  test('expire 保留内存身份、删除持久化凭证，重启后绝不复活被拒绝的 Token', () async {
    final storage = InMemorySessionStorage();
    final controller = controllerFor(storage);
    addTearDown(controller.dispose);
    await controller.signIn(
      user: user,
      token: 'token-1',
      expiresAt: now.add(const Duration(days: 30)),
    );

    await controller.expire();

    expect(controller.status, AccountSessionStatus.expired);
    expect(controller.user, user);
    expect(controller.token, isNull);
    expect(controller.currentUserId, isNull);
    expect(controller.hasUsableSession, isFalse);
    // 服务端 401 与本地 expiresAt 无关，凭证必须从磁盘删除，
    // 否则重启会读回一份“本地还没过期”的信封并复活被拒绝的 Token。
    expect(storage.canonical, isNull, reason: '规范键不能留下被拒绝的 Token');
    expect(storage.legacy, isNull, reason: '旧键同样不能留下被拒绝的 Token');

    final restarted = controllerFor(storage);
    addTearDown(restarted.dispose);
    await restarted.start();
    expect(restarted.status, AccountSessionStatus.guest);
    expect(restarted.token, isNull, reason: '重启后绝不能再使用被 401 拒绝的 Token');
    expect(restarted.user, isNull);
    expect(restarted.hasUsableSession, isFalse);
  });

  test('clear 回到游客状态并清空两个键', () async {
    final storage = InMemorySessionStorage();
    final controller = controllerFor(storage);
    addTearDown(controller.dispose);
    await controller.signIn(
      user: user,
      token: 'token-1',
      expiresAt: now.add(const Duration(days: 30)),
    );

    await controller.clear();

    expect(controller.status, AccountSessionStatus.guest);
    expect(controller.user, isNull);
    expect(controller.token, isNull);
    expect(storage.canonical, isNull);
    expect(storage.legacy, isNull);
  });

  test('adoptIdentity 注入的身份不会被后续 start 覆盖', () async {
    final storage = InMemorySessionStorage();
    final controller = controllerFor(storage);
    addTearDown(controller.dispose);

    await controller.adoptIdentity(
      user: user,
      expiresAt: now.add(const Duration(days: 30)),
    );
    await controller.start();

    expect(controller.status, AccountSessionStatus.authenticated);
    expect(controller.user, user);
    expect(storage.canonical, isNull, reason: '没有 Token 时不写入不可用的“已登录”凭证');
  });

  test('watch 先发当前值再发变化，与旧 SessionRepository 语义一致', () async {
    final storage = InMemorySessionStorage();
    final controller = controllerFor(storage);
    addTearDown(controller.dispose);
    final events = <AccountSessionStatus>[];
    final subscription = controller.watch().listen(
      (session) => events.add(session.status),
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(events, [AccountSessionStatus.guest]);

    await controller.signIn(
      user: user,
      token: 'token-1',
      expiresAt: now.add(const Duration(days: 30)),
    );
    await pumpEventQueue();
    await controller.clear();
    await pumpEventQueue();

    expect(events, [
      AccountSessionStatus.guest,
      AccountSessionStatus.authenticated,
      AccountSessionStatus.guest,
    ]);
  });
}

class _ThrowingStorage implements SessionEnvelopeStorage {
  @override
  Future<StorageRead> read() async => throw StateError('安全存储不可用');

  @override
  Future<void> write(AccountSession session) async {}

  @override
  Future<void> clear() async {}
}
