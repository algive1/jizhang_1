import 'account_session_status.dart';
import 'account_user.dart';

/// 服务器会话快照。
///
/// [session] 是当前 `SharedApi` 继续使用的 Opaque Random Token
/// （原始 Token 只存在于客户端安全存储，服务端只保存 token_hash）。
class AccountSession {
  const AccountSession({
    required this.user,
    required this.expiresAt,
    required this.baseUrl,
    this.token,
    this.status = AccountSessionStatus.authenticated,
  });

  AccountSession.initializing()
    : user = null,
      token = null,
      expiresAt = null,
      baseUrl = '',
      status = AccountSessionStatus.initializing;

  const AccountSession.guest({this.baseUrl = ''})
    : user = null,
      token = null,
      expiresAt = null,
      status = AccountSessionStatus.guest;

  /// 会话失效：保留上次身份用于展示“需要重新登录”，但不保留可用的 Token。
  const AccountSession.expired({
    required this.user,
    this.baseUrl = '',
    this.expiresAt,
  }) : token = null,
       status = AccountSessionStatus.expired;

  const AccountSession.error({this.baseUrl = ''})
    : user = null,
      token = null,
      expiresAt = null,
      status = AccountSessionStatus.error;

  static const _formatVersion = 1;

  final AccountUser? user;

  /// 原始 Token。仅在内存与安全存储之间传递，禁止写入日志或普通设置表。
  final String? token;

  final DateTime? expiresAt;

  /// 会话绑定的服务端地址。地址变化时旧会话不再复用，避免跨环境串号。
  final String baseUrl;

  final AccountSessionStatus status;

  String? get userId => user?.id;

  bool get isAuthenticated =>
      status == AccountSessionStatus.authenticated && user != null;

  /// Token 仍然可用（已认证、存在、且未过期）。
  bool isUsableAt(DateTime now) {
    if (!isAuthenticated || token == null) return false;
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(now);
  }

  AccountSession copyWith({
    AccountUser? user,
    String? token,
    DateTime? expiresAt,
    String? baseUrl,
    AccountSessionStatus? status,
  }) => AccountSession(
    user: user ?? this.user,
    token: token ?? this.token,
    expiresAt: expiresAt ?? this.expiresAt,
    baseUrl: baseUrl ?? this.baseUrl,
    status: status ?? this.status,
  );

  /// 只序列化到客户端安全存储；Token 为空表示这份快照不可用于服务器请求。
  Map<String, dynamic> toJson() => {
    'version': _formatVersion,
    'status': status.name,
    'token': token,
    'expiresAt': expiresAt?.millisecondsSinceEpoch,
    'baseUrl': baseUrl,
    'user': user?.toJson(),
  };

  /// 解析失败一律返回 null，由调用方按“没有会话”处理，绝不猜测字段。
  static AccountSession? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    final status = AccountSessionStatus.values
        .where((item) => item.name == json['status'])
        .firstOrNull;
    if (status == null) return null;
    final rawExpiry = json['expiresAt'];
    return AccountSession(
      user: AccountUser.fromJson(json['user']),
      token: json['token'] is String && (json['token'] as String).isNotEmpty
          ? json['token'] as String
          : null,
      expiresAt: rawExpiry is int
          ? DateTime.fromMillisecondsSinceEpoch(rawExpiry)
          : null,
      baseUrl: json['baseUrl'] is String ? json['baseUrl'] as String : '',
      status: status,
    );
  }

  /// 由当前时间推导出的实际状态：本地已过期的会话不得用于服务器请求。
  AccountSession refreshedAt(DateTime now) {
    if (!isAuthenticated) return this;
    final expiry = expiresAt;
    if (token == null || (expiry != null && !expiry.isAfter(now))) {
      return AccountSession(
        user: user,
        token: null,
        expiresAt: expiry,
        baseUrl: baseUrl,
        status: AccountSessionStatus.expired,
      );
    }
    return this;
  }

  @override
  String toString() =>
      'AccountSession(${status.name}, ${user?.username ?? '-'})';
}
