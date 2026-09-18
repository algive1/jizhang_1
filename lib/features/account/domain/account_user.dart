/// 统一账户体系里的“服务器用户身份”。
///
/// 它只描述服务器账号，不包含任何本地数据集、会员或共享角色信息：
/// - 会员权益由 MembershipSnapshot / EntitlementKey 判断；
/// - 共享账本角色由 sync_books.role / FamilyMember 判断；
/// - 本地记账数据不依赖这个对象，游客状态下它就是 null。
///
/// [displayName] 可以为空：旧用户的 users 表里没有 display_name，
/// 服务端 migration 允许其为空，展示时回退到 [username]。
class AccountUser {
  const AccountUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarKey,
  });

  /// 服务器 user_id。共享、会员、支付、云同步统一使用这一个 id。
  final String id;

  /// 登录账号（服务端唯一登录凭证，第一阶段只读）。
  final String username;

  /// 昵称。为空时展示层回退 [username]。
  final String? displayName;

  /// 头像标识，第一阶段预留，暂不参与业务判断。
  final String? avatarKey;

  /// 展示优先使用昵称，缺失时回退登录账号。
  String get preferredName {
    final value = displayName?.trim();
    return value == null || value.isEmpty ? username : value;
  }

  /// 服务端返回的字段名同时兼容 id / userId，便于第一阶段渐进迁移。
  static AccountUser? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    final id = _text(json['id'] ?? json['userId']);
    final username = _text(json['username']);
    if (id == null || username == null) return null;
    return AccountUser(
      id: id,
      username: username,
      displayName: _text(json['displayName'] ?? json['display_name']),
      avatarKey: _text(json['avatarKey'] ?? json['avatar_key']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    if (displayName != null) 'displayName': displayName,
    if (avatarKey != null) 'avatarKey': avatarKey,
  };

  AccountUser copyWith({String? displayName, String? avatarKey}) => AccountUser(
    id: id,
    username: username,
    displayName: displayName ?? this.displayName,
    avatarKey: avatarKey ?? this.avatarKey,
  );

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is AccountUser &&
      other.id == id &&
      other.username == username &&
      other.displayName == displayName &&
      other.avatarKey == avatarKey;

  @override
  int get hashCode => Object.hash(id, username, displayName, avatarKey);

  @override
  String toString() => 'AccountUser($id, $username)';
}
