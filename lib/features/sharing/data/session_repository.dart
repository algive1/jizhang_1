import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../account/application/account_session_controller.dart';
import '../../account/data/secure_session_storage.dart' as account_storage;
import '../../account/domain/account_session.dart';
import '../../account/domain/account_session_status.dart';
import '../../account/domain/account_user.dart';
import 'shared_api.dart';

/// 共享账本页面历史上直接使用的用户对象。
///
/// 字段保持不变，避免个人中心、共享账本、会员与支付页面为了账户体系改动 UI。
/// 新代码应优先使用 `AccountUser`。
class SessionUser {
  const SessionUser(this.id, this.username);
  final String id;
  final String username;

  AccountUser toAccountUser() => AccountUser(id: id, username: username);

  @override
  bool operator ==(Object other) =>
      other is SessionUser && other.id == id && other.username == username;

  @override
  int get hashCode => Object.hash(id, username);

  @override
  String toString() => 'SessionUser($id, $username)';
}

/// 凭证持久化抽象，签名保持与迁移前一致（测试与自定义注入依赖它）。
abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String? value);
}

/// 让旧 `SessionStorage` 继续可用的适配层。
///
/// 旧实现读写的是 `{token,expiresAt,user,baseUrl}` 单一 JSON 结构；这个适配器
/// 把它翻译成统一账户的 [AccountSession]，因此测试里注入的内存存储、以及
/// 任何外部自定义实现都不用改一行代码。
class LegacySessionStorageAdapter
    implements account_storage.SessionEnvelopeStorage {
  const LegacySessionStorageAdapter(this._storage, this._baseUrl);

  final SessionStorage _storage;
  final String _baseUrl;

  @override
  Future<account_storage.StorageRead> read() async {
    final legacy = account_storage.LegacySessionPayload.tryParse(
      await _storage.read(),
    );
    if (legacy == null) return const account_storage.StorageRead.missing();
    if (!legacy.expiresAt.isAfter(DateTime.now())) {
      await _storage.write(null);
      return const account_storage.StorageRead.missing();
    }
    if (legacy.baseUrl != _baseUrl)
      return const account_storage.StorageRead.missing();
    return account_storage.StorageRead.legacy(payload: legacy);
  }

  @override
  Future<void> write(AccountSession session) => _storage.write(
    jsonEncode(account_storage.SecureSessionStorage.legacyJson(session)),
  );

  @override
  Future<void> clear() => _storage.write(null);
}

/// 共享账本时代的 `SecureSessionStorage`。
///
/// 兼容保留：默认构造仍然使用它；统一账户模块通过 [LegacySessionStorageAdapter]
/// 读取同一个键，并在首次成功读取后就地迁移到 `account_session_v1`。
class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage();
  static const _storage = FlutterSecureStorage();
  static const _name = SecureSessionStorageKeys.legacy;

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String? value) => value == null
      ? _storage.delete(key: _name)
      : _storage.write(key: _name, value: value);
}

/// 旧键名，集中在一处，避免账户模块与共享模块各写一份字面量。
abstract final class SecureSessionStorageKeys {
  static const legacy = 'shared_ledger_session_v1';
}

/// 账户体系的兼容门面：对外 API 与迁移前完全一致。
///
/// 实际状态与安全存储由 [AccountSessionController] 拥有；本类只负责
/// 网络交互（登录/注册/登出）与数据库 actor 同步，因此共享账本、
/// 会员、支付、助手和诊断代码全部无需修改。
class SessionRepository {
  SessionRepository(this.api, this.database, {SessionStorage? storage})
    : storage = storage ?? const SecureSessionStorage();

  final SharedApi api;
  final AppDatabase database;

  /// 凭证存储。迁移前已经公开的字段，测试按旧签名注入内存实现时会用到。
  final SessionStorage storage;

  AccountSessionController? _controller;
  Future<void>? _initializing;

  AccountSessionController _resolveController() =>
      _controller ??= AccountSessionController(
        LegacySessionStorageAdapter(storage, api.baseUrl),
        baseUrl: api.baseUrl,
      );

  /// 当前登录用户；未登录、会话失效、读取失败时都是 null。
  SessionUser? get user {
    final account = _resolveController().user;
    return account == null ? null : SessionUser(account.id, account.username);
  }

  /// 直接注入一个已登录身份。
  ///
  /// 迁移前这个字段就是可写的（测试用它跳过真实登录），因此保留同样的能力，
  /// 但状态统一交给 [AccountSessionController] 管理。
  set user(SessionUser? value) {
    final controller = _resolveController();
    if (value == null) {
      unawaited(controller.clear());
      return;
    }
    unawaited(
      controller.adoptIdentity(
        user: value.toAccountUser(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      ),
    );
  }

  /// 服务器 user_id，供会员、支付、共享与云同步统一使用。
  String? get userId => _resolveController().currentUserId;

  /// 账户会话状态，页面据此区分游客 / 已登录 / 需要重新登录。
  AccountSessionStatus get accountStatus => _resolveController().status;

  /// 先发当前值再发后续变化；未登录时发 null（与迁移前一致）。
  Stream<SessionUser?> watch() async* {
    await initialize();
    yield user;
    yield* _resolveController().watch().map(_asSessionUser);
  }

  /// 只读一次安全存储；重复调用不会重新读取。
  Future<void> initialize() => _initializing ??= _restore();

  Future<void> _restore() async {
    final controller = _resolveController();
    await controller.start();
    // 旧会话可能刚刚从旧键迁移过来；Token 只在内存中，必须回填给 HTTP 层。
    api.sessionToken ??= controller.token;
    // 恢复身份与恢复数据无关：这里同步的是共享账本的可见性 actor，
    // 不触碰任何本地记账表结构或数据。
    await database.setSyncActor(controller.currentUserId ?? 'user-local');
  }

  /// 登录或注册。请求/响应结构与迁移前完全一致。
  Future<void> authenticate({
    required String username,
    required String password,
    bool register = false,
  }) async {
    await initialize();
    final data = await api.request(
      '/auth/${register ? 'register' : 'login'}',
      method: 'POST',
      body: {'username': username, 'password': password},
    );
    final token = data['token'];
    final expiresAt = data['expiresAt'];
    if (token is! String || token.isEmpty || expiresAt is! int) {
      throw const SharedApiException(0, '登录响应缺少会话信息，请稍后重试');
    }
    final account = AccountUser.fromJson(data['user']);
    if (account == null) {
      throw const SharedApiException(0, '登录响应缺少账号信息，请稍后重试');
    }
    await _resolveController().signIn(
      user: account,
      token: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
    );
    api.sessionToken = token;
    await database.setSyncActor(account.id);
  }

  /// 服务端登出，并清理本地会话。
  ///
  /// 本地清理一定会执行；撤销服务端 Session 是尽力而为：网络不可用时不能把
  /// “退出登录”报成失败，否则用户会以为本地还没退出。服务端那条 Session 仍然
  /// 受 30 天有效期约束。
  Future<void> logout() async {
    try {
      if (api.sessionToken != null) {
        await api.request('/auth/logout', method: 'POST', body: {});
      }
    } on Object {
      // 本地会话清理在 finally 中完成，网络错误在此被有意忽略。
    } finally {
      await invalidate();
    }
  }

  /// 清理本地会话，回到游客状态。只清服务器身份，不删除本地记账数据，
  /// 也不改变任何本地账本、流水、预算或目标。
  Future<void> invalidate() async {
    await _resolveController().clear();
    api.sessionToken = null;
    await database.setSyncActor('user-local');
  }

  /// 服务器明确返回 401：标记会话失效但保留身份，供“重新登录后继续”提示使用。
  ///
  /// 注意：只有服务器明确返回 401 才能调用它。网络异常必须走普通错误分支，
  /// 否则会把网络问题误判成登录失效。
  Future<void> markSessionExpired() async {
    await _resolveController().expire();
    api.sessionToken = null;
    await database.setSyncActor('user-local');
  }

  Future<void> dispose() async {
    // 控制器由 Riverpod 持有并统一释放；这里只需丢弃引用。
    _controller = null;
  }

  SessionUser? _asSessionUser(AccountSession session) => session.user == null
      ? null
      : SessionUser(session.user!.id, session.user!.username);
}

final sharedApiProvider = Provider<SharedApi>((ref) {
  final api = SharedApi();
  ref.onDispose(api.close);
  return api;
});
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final repository = SessionRepository(
    ref.watch(sharedApiProvider),
    ref.watch(databaseProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});
final sessionProvider = StreamProvider<SessionUser?>(
  (ref) => ref.watch(sessionRepositoryProvider).watch(),
);
