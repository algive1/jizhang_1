import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/secure_session_storage.dart';
import '../domain/account_session.dart';
import '../domain/account_session_status.dart';
import '../domain/account_user.dart';

/// 统一账户会话的唯一写入者与广播源。
///
/// 职责边界（第一阶段刻意保持很窄）：
/// - 负责读取/写入安全存储里的会话信封；
/// - 负责把会话状态广播给上层（旧的 SessionRepository、后续新增的账户页面）；
/// - **不**负责网络请求、**不**负责 `setSyncActor`、**不**负责会员与共享权限。
///
/// 数据库 actor（user-local / 服务器 user_id）仍由 SessionRepository 在同一个
/// 动作里设置，因此共享账本可见性与迁移前逐字节一致。
class AccountSessionController {
  AccountSessionController(
    this._storage, {
    this.baseUrl = '',
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SessionEnvelopeStorage _storage;

  /// 当前构建绑定的服务端地址，用于拒绝跨环境的旧会话。
  final String baseUrl;

  final DateTime Function() _clock;
  final _changes = StreamController<AccountSession>.broadcast();

  AccountSession _state = AccountSession.initializing();
  Future<void>? _starting;

  AccountSession get state => _state;

  AccountUser? get user => _state.user;

  String? get token => _state.token;

  AccountSessionStatus get status => _state.status;

  /// 当前可用的服务器 user_id；未登录或会话失效时为 null。
  String? get currentUserId => _state.isAuthenticated ? _state.userId : null;

  /// 是否已登录且 Token 仍然可用。
  bool get hasUsableSession => _state.isUsableAt(_clock());

  /// 先发当前值再发后续变化，与旧 SessionRepository.watch() 语义一致。
  Stream<AccountSession> watch() async* {
    await start();
    yield _state;
    yield* _changes.stream;
  }

  Future<void> start() => _starting ??= _restore();

  Future<void> _restore() async {
    // 上层（例如测试或 Phase 2 的会话接管）可能已经注入身份，不要覆盖它。
    if (_state.status != AccountSessionStatus.initializing) return;
    final StorageRead read;
    try {
      read = await _storage.read();
    } on Object {
      // 安全存储不可用不等于退出登录：保持 error 状态，不清任何数据。
      _emit(const AccountSession.error());
      return;
    }
    switch (read) {
      case MissingSession():
        _emit(AccountSession.guest(baseUrl: baseUrl));
      case CanonicalSession(:final session):
        final refreshed = session.refreshedAt(_clock());
        if (refreshed.status == AccountSessionStatus.expired) {
          // 本地已过期：清理存储，但保留内存身份用于一次提示。
          await _storage.clear();
        }
        _emit(refreshed);
      case LegacySession(:final payload):
        // 旧版本已经本地过期：与迁移前一致，直接清理且不恢复身份。
        if (!payload.expiresAt.isAfter(_clock())) {
          await _storage.clear();
          _emit(AccountSession.guest(baseUrl: baseUrl));
          return;
        }
        // 地址变化时绝不复用旧会话，避免跨环境串号。
        if (payload.baseUrl != baseUrl) {
          _emit(AccountSession.guest(baseUrl: baseUrl));
          return;
        }
        final migrated = AccountSession(
          user: payload.user,
          token: payload.token,
          expiresAt: payload.expiresAt,
          baseUrl: payload.baseUrl,
        );
        // 写回规范键，同时继续维护旧键，允许覆盖安装与版本回滚。
        await _storage.write(migrated);
        _emit(migrated);
    }
  }

  /// 直接接管一个已经存在的身份。
  ///
  /// 用于两种场景：
  /// - 覆盖安装后由旧会话迁移过来的用户，不需要重新注册；
  /// - 测试里把已登录状态注入到仓库。
  ///
  /// [token] 为 null 时不会写入安全存储，避免落一个不可用的“已登录”凭证。
  Future<void> adoptIdentity({
    required AccountUser user,
    required DateTime expiresAt,
    String? token,
  }) async {
    final session = AccountSession(
      user: user,
      token: token,
      expiresAt: expiresAt,
      baseUrl: baseUrl,
    );
    if (token != null) await _storage.write(session);
    _emit(session);
  }

  /// 登录/注册成功后写入会话并广播。
  Future<void> signIn({
    required AccountUser user,
    required String token,
    required DateTime expiresAt,
    String? baseUrl,
  }) async {
    final session = AccountSession(
      user: user,
      token: token,
      expiresAt: expiresAt,
      baseUrl: baseUrl ?? this.baseUrl,
    );
    await _storage.write(session);
    _emit(session);
  }

  /// 服务器明确返回 401：标记失效，但保留身份信息用于展示“需要重新登录”。
  ///
  /// **被拒绝的 Token 必须同时从安全存储中删除**，只让 `expired` 存活在内存里：
  /// 服务端 401 与本地 `expiresAt` 无关，若继续把这份“本地还没过期”的信封留在
  /// 磁盘上，App 重启会重新读回它，把服务器已经拒绝的 Token 再拿去请求，
  /// 形成一次注定失败的登录态复活。删除凭证后重启退化为 guest，用户重新登录即可。
  ///
  /// 保留的 [user] 只在内存中存在，用于当次会话的“登录已失效”提示，不写入安全
  /// 存储（Phase 2 若要跨重启提示，需改为只持久化身份、不持久化 Token）。
  Future<void> expire() async {
    final current = _state;
    final user = current.user;
    // 先落盘删除再广播 expired：任何观察者读到 expired 时，存储里都已经没有
    // 可复用的 Token，不存在“状态已失效但磁盘仍有凭证”的中间窗口。
    await _storage.clear();
    _emit(
      user == null
          ? AccountSession.guest(baseUrl: baseUrl)
          : AccountSession.expired(user: user, baseUrl: current.baseUrl),
    );
  }

  /// 主动退出登录 / 清理失效会话。只清服务器身份，不触碰任何本地记账数据。
  Future<void> clear() async {
    await _storage.clear();
    _emit(AccountSession.guest(baseUrl: baseUrl));
  }

  void _emit(AccountSession session) {
    _state = session;
    if (!_changes.isClosed) _changes.add(session);
  }

  Future<void> dispose() => _changes.close();
}

final accountSessionControllerProvider = Provider<AccountSessionController>((
  ref,
) {
  const configured = String.fromEnvironment('SHARED_API_BASE_URL');
  final controller = AccountSessionController(
    const SecureSessionStorage(),
    // 必须与 SharedApi 的默认地址一致，否则首次迁移会拒绝旧会话。
    baseUrl: configured.isEmpty ? 'http://127.0.0.1:8787' : configured,
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// 账户状态流；页面通过它读取 AccountSessionStatus，而不是自己判断 token。
final accountSessionProvider = StreamProvider<AccountSession>(
  (ref) => ref.watch(accountSessionControllerProvider).watch(),
);
