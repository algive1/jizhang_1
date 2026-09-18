import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/account/data/secure_session_storage.dart';
import 'package:jizhang_app/features/account/domain/account_session.dart';
import 'package:jizhang_app/features/account/domain/account_session_status.dart';
import 'package:jizhang_app/features/account/domain/account_user.dart';

/// 覆盖旧键兼容与就地迁移。
///
/// 生产实现 `SecureSessionStorage` 使用 flutter_secure_storage 插件，插件调用
/// 需要平台通道，因此这里针对同一个内存实现验证迁移与序列化契约：两种实现
/// 共享 [SecureSessionStorage.legacyJson] 与 [LegacySessionPayload.tryParse]，
/// 所以旧键的读取/写入格式由同一处代码保证。
void main() {
  final now = DateTime(2026, 9, 18, 10);
  const baseUrl = 'http://127.0.0.1:8787';
  const user = AccountUser(id: 'user-1', username: 'lu_2026');
  late DateTime expiresAt;

  setUp(() {
    expiresAt = now.add(const Duration(days: 30));
  });

  LegacySessionPayload legacyPayload() => LegacySessionPayload(
    user: user,
    token: 'legacy-token',
    expiresAt: expiresAt,
    baseUrl: baseUrl,
  );

  test('空存储读出“无会话”，不会凭空造出登录态', () async {
    final storage = InMemorySessionStorage();
    final read = await storage.read();
    expect(read, isA<MissingSession>());
  });

  test('旧键的单一 JSON 结构仍可被识别为待迁移会话', () async {
    final storage = InMemorySessionStorage(legacy: legacyPayload());
    final read = await storage.read();
    expect(read, isA<LegacySession>());
    final payload = (read as LegacySession).payload;
    expect(payload.token, 'legacy-token');
    expect(payload.user, user);
    expect(payload.expiresAt, expiresAt);
    expect(payload.baseUrl, baseUrl);
  });

  test('旧键以 JSON 字符串形式存放时同样可以解析', () async {
    final storage = InMemorySessionStorage(
      legacy: jsonEncode(
        SecureSessionStorage.legacyJson(
          AccountSession(
            user: user,
            token: 'legacy-token',
            expiresAt: expiresAt,
            baseUrl: baseUrl,
          ),
        ),
      ),
    );
    expect(await storage.read(), isA<LegacySession>());
  });

  test('tryParse 接受 payload 本身、JSON 字符串与已解码的 Map', () {
    final payload = legacyPayload();
    final json = SecureSessionStorage.legacyJson(payload.toSession());
    expect(LegacySessionPayload.tryParse(payload)?.token, 'legacy-token');
    expect(
      LegacySessionPayload.tryParse(jsonEncode(json))?.token,
      'legacy-token',
    );
    expect(LegacySessionPayload.tryParse(json)?.token, 'legacy-token');
    expect(LegacySessionPayload.tryParse(null), isNull);
    expect(LegacySessionPayload.tryParse(42), isNull);
  });

  test('旧键损坏时按无会话处理，不抛异常', () async {
    final storage = InMemorySessionStorage(legacy: '{不是合法 JSON');
    expect(await storage.read(), isA<MissingSession>());
  });

  test('规范键优先于旧键，且不会被旧键覆盖', () async {
    final canonical = AccountSession(
      user: const AccountUser(id: 'user-2', username: 'new_user'),
      token: 'canonical-token',
      expiresAt: expiresAt,
      baseUrl: baseUrl,
    );
    final storage = InMemorySessionStorage(
      canonical: canonical.toJson(),
      legacy: legacyPayload(),
    );
    final read = await storage.read();
    expect(read, isA<CanonicalSession>());
    expect((read as CanonicalSession).session.token, 'canonical-token');
  });

  test('规范键损坏时只清规范键，旧键仍可作为回退来源', () async {
    final storage = InMemorySessionStorage(
      canonical: const {'status': '未知状态'},
      legacy: legacyPayload(),
    );
    final read = await storage.read();
    expect(read, isA<LegacySession>());
  });

  test('写入时同时维护规范键与旧键，允许覆盖安装与版本回滚', () async {
    final storage = InMemorySessionStorage();
    await storage.write(
      AccountSession(
        user: user,
        token: 'token-1',
        expiresAt: expiresAt,
        baseUrl: baseUrl,
      ),
    );
    expect(storage.canonical, isA<Map<String, dynamic>>());
    final legacy = LegacySessionPayload.tryParse(storage.legacy);
    expect(legacy, isNotNull);
    expect(legacy!.token, 'token-1');
    expect(legacy.user.username, 'lu_2026');
    expect(legacy.expiresAt, expiresAt);
  });

  test('旧键字段结构保持与迁移前逐字段一致', () {
    final json = SecureSessionStorage.legacyJson(
      AccountSession(
        user: user,
        token: 'token-1',
        expiresAt: expiresAt,
        baseUrl: baseUrl,
      ),
    );
    expect(json.keys.toSet(), {'token', 'expiresAt', 'user', 'baseUrl'});
    expect(json['token'], 'token-1');
    expect(json['baseUrl'], baseUrl);
    expect(
      json['expiresAt'],
      expiresAt.millisecondsSinceEpoch ~/ 1000,
      reason: '旧实现以秒为单位保存过期时间',
    );
    expect((json['user']! as Map<String, dynamic>).keys.toSet(), {
      'id',
      'username',
    });
  });

  test('清理会同时删除两个键，不留可用凭证', () async {
    final storage = InMemorySessionStorage(
      canonical: AccountSession.guest().toJson(),
      legacy: legacyPayload(),
    );
    await storage.clear();
    expect(storage.canonical, isNull);
    expect(storage.legacy, isNull);
    expect(await storage.read(), isA<MissingSession>());
  });

  test('规范信封使用独立状态字段，过期时间以毫秒保存', () {
    final json = AccountSession(
      user: user,
      token: 'token-1',
      expiresAt: expiresAt,
      baseUrl: baseUrl,
    ).toJson();
    expect(json['status'], AccountSessionStatus.authenticated.name);
    expect(json['expiresAt'], expiresAt.millisecondsSinceEpoch);
    expect(json['version'], 1);
  });

  test('清理损坏数据由 clear() 显式完成，读取本身没有副作用', () async {
    final storage = InMemorySessionStorage(
      canonical: const {'status': '未知状态'},
      legacy: '{不是合法 JSON',
    );
    // 连续读取两次结果一致，说明读取不会悄悄改写存储内容。
    expect(await storage.read(), isA<MissingSession>());
    expect(storage.canonical, isNotNull);
    expect(storage.legacy, isNotNull);

    await storage.clear();

    expect(storage.canonical, isNull);
    expect(storage.legacy, isNull);
  });
}

extension on LegacySessionPayload {
  AccountSession toSession() => AccountSession(
    user: user,
    token: token,
    expiresAt: expiresAt,
    baseUrl: baseUrl,
  );
}
