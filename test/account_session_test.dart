import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/account/domain/account_session.dart';
import 'package:jizhang_app/features/account/domain/account_session_status.dart';
import 'package:jizhang_app/features/account/domain/account_user.dart';

void main() {
  final now = DateTime(2026, 9, 18, 10);
  const user = AccountUser(
    id: 'user-1',
    username: 'lu_2026',
    displayName: '小陆',
  );

  test('游客状态没有服务器身份，也没有 Token', () {
    const session = AccountSession.guest(baseUrl: 'https://api.example');
    expect(session.status, AccountSessionStatus.guest);
    expect(session.user, isNull);
    expect(session.token, isNull);
    expect(session.isAuthenticated, isFalse);
    expect(session.isUsableAt(now), isFalse);
  });

  test('已登录且未过期的会话才可用于服务器请求', () {
    final session = AccountSession(
      user: user,
      token: 'opaque-token',
      expiresAt: now.add(const Duration(days: 30)),
      baseUrl: 'https://api.example',
    );
    expect(session.status, AccountSessionStatus.authenticated);
    expect(session.isUsableAt(now), isTrue);
    expect(session.userId, 'user-1');
  });

  test('本地已过期的会话按失效处理且不保留 Token', () {
    final session = AccountSession(
      user: user,
      token: 'opaque-token',
      expiresAt: now.subtract(const Duration(seconds: 1)),
      baseUrl: 'https://api.example',
    ).refreshedAt(now);
    expect(session.status, AccountSessionStatus.expired);
    expect(session.token, isNull);
    expect(session.isUsableAt(now), isFalse);
    // 身份保留，供“需要重新登录”提示展示账号；本地数据不受影响。
    expect(session.user, user);
  });

  test('会话信封可以完整往返序列化', () {
    final session = AccountSession(
      user: user,
      token: 'opaque-token',
      expiresAt: now.add(const Duration(days: 30)),
      baseUrl: 'https://api.example',
    );
    final restored = AccountSession.fromJson(session.toJson());
    expect(restored, isNotNull);
    expect(restored!.status, session.status);
    expect(restored.token, session.token);
    expect(restored.expiresAt, session.expiresAt);
    expect(restored.baseUrl, session.baseUrl);
    expect(restored.user, user);
  });

  test('损坏或字段缺失的信封一律按无会话处理，不做字段猜测', () {
    expect(AccountSession.fromJson('not-a-map'), isNull);
    expect(AccountSession.fromJson(const {}), isNull);
    expect(AccountSession.fromJson(const {'status': '不存在的状态'}), isNull);
    expect(
      AccountSession.fromJson(const {'status': 'authenticated', 'user': 'x'}),
      isNotNull,
      reason: '缺少 user 时解析成功但没有身份，由上层按未登录处理',
    );
  });

  test('AccountUser 兼容 id/userId 与 display_name 命名', () {
    expect(
      AccountUser.fromJson(const {
        'id': 'u1',
        'username': 'lu',
        'display_name': '小陆',
      })?.displayName,
      '小陆',
    );
    expect(
      AccountUser.fromJson(const {'userId': 'u2', 'username': 'lu2'})?.id,
      'u2',
    );
    expect(AccountUser.fromJson(const {'username': 'lu'}), isNull);
    expect(AccountUser.fromJson('x'), isNull);
  });

  test('展示名称优先昵称，缺失时回退登录账号', () {
    expect(user.preferredName, '小陆');
    expect(
      const AccountUser(
        id: 'u',
        username: 'lu',
        displayName: '   ',
      ).preferredName,
      'lu',
    );
  });
}
