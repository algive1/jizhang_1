import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/account_session.dart';
import '../domain/account_user.dart';

/// 安全存储抽象，便于测试替换成内存实现。
abstract interface class SessionEnvelopeStorage {
  /// 读取会话；读取失败或数据损坏时返回 [StorageRead.missing]。
  Future<StorageRead> read();
  Future<void> write(AccountSession session);
  Future<void> clear();
}

/// 读取结果。区分规范和旧版结构，迁移决策留给调用方。
sealed class StorageRead {
  const StorageRead();

  /// 新建 / 无会话 / 数据不可解析（按无会话处理）。
  const factory StorageRead.missing() = MissingSession;

  /// 规范会话，可直接使用。
  const factory StorageRead.canonical({required AccountSession session}) =
      CanonicalSession;

  /// 只找到旧版 `shared_ledger_session_v1` JSON 结构，需要迁移。
  const factory StorageRead.legacy({required LegacySessionPayload payload}) =
      LegacySession;
}

/// 无会话：新建安装、已被清理、或数据不可解析。
class MissingSession extends StorageRead {
  const MissingSession();
}

/// 规范会话。
class CanonicalSession extends StorageRead {
  const CanonicalSession({required this.session});
  final AccountSession session;
}

/// 旧版本会话，需要迁移到规范结构。
class LegacySession extends StorageRead {
  const LegacySession({required this.payload});
  final LegacySessionPayload payload;
}

/// 旧版会话结构：`{token, expiresAt, user:{id,username}, baseUrl}`。
///
/// 解析结果区分“不是旧会话”和“旧会话已过期”，迁移时行为不同：
/// 前者什么都不做，后者清理本地会话（与迁移前的实现一致）。
class LegacySessionPayload {
  const LegacySessionPayload({
    required this.user,
    required this.token,
    required this.expiresAt,
    required this.baseUrl,
  });

  final AccountUser user;
  final String token;
  final DateTime expiresAt;
  final String baseUrl;

  /// 返回解析出的 payload；空值/损坏/字段类型不符时返回 null。
  static LegacySessionPayload? tryParse(Object? value) {
    if (value is LegacySessionPayload) return value;
    final data = switch (value) {
      null => null,
      String() when value.trim().isEmpty => null,
      String() => _decode(value),
      Map() => value.cast<String, dynamic>(),
      _ => null,
    };
    if (data == null) return null;
    final user = AccountUser.fromJson(data['user']);
    final token = data['token'];
    final expiresAt = data['expiresAt'];
    if (user == null || token is! String || token.isEmpty) return null;
    if (expiresAt is! int) return null;
    return LegacySessionPayload(
      user: user,
      token: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
      baseUrl: data['baseUrl'] is String ? data['baseUrl'] as String : '',
    );
  }

  static Map<String, dynamic>? _decode(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } on FormatException {
      return null;
    }
  }
}

/// 生产实现：规范会话写在 `account_session_v1`。
///
/// 兼容策略（第一阶段不强制任何已有用户重新登录）：
/// - 启动时先读规范键，读到旧键内容时就地迁移；
/// - 迁移后仍然同步维护旧键 `shared_ledger_session_v1`，因此覆盖安装、
///   甚至回滚到旧版本都能继续识别同一个 Token；
/// - 只有某一个键损坏时只清那个键，绝不因为解析失败而级联清掉另一个键。
class SecureSessionStorage implements SessionEnvelopeStorage {
  const SecureSessionStorage();

  /// 规范会话键。
  static const canonicalKey = 'account_session_v1';

  /// 旧版共享账本会话键，第一阶段继续写入与清理。
  static const legacyKey = 'shared_ledger_session_v1';

  static const _storage = FlutterSecureStorage();

  @override
  Future<StorageRead> read() async {
    final canonicalSession = AccountSession.fromJson(
      await _readJson(canonicalKey),
    );
    if (canonicalSession != null)
      return StorageRead.canonical(session: canonicalSession);
    if (await _readRaw(canonicalKey) != null) {
      // 规范键存在但不可解析：只清规范键，保留旧键作为回退来源。
      await _deleteCanonical();
    }
    final legacy = LegacySessionPayload.tryParse(await _readRaw(legacyKey));
    if (legacy != null) return StorageRead.legacy(payload: legacy);
    if (await _readRaw(legacyKey) != null) await _deleteLegacy();
    return const StorageRead.missing();
  }

  @override
  Future<void> write(AccountSession session) async {
    // 先写规范键再写旧键：中途中断最坏退化成一次重新迁移。
    await _storage.write(
      key: canonicalKey,
      value: jsonEncode(session.toJson()),
    );
    await _storage.write(
      key: legacyKey,
      value: jsonEncode(legacyJson(session)),
    );
  }

  @override
  Future<void> clear() async {
    await _deleteCanonical();
    await _deleteLegacy();
  }

  /// 旧版本读取的字段结构，与迁移前完全一致。
  static Map<String, dynamic> legacyJson(AccountSession session) => {
    'token': session.token,
    'expiresAt':
        (session.expiresAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
    'user': session.user?.toJson() ?? const <String, dynamic>{},
    'baseUrl': session.baseUrl,
  };

  Future<void> _deleteCanonical() => _storage.delete(key: canonicalKey);

  Future<void> _deleteLegacy() => _storage.delete(key: legacyKey);

  Future<String?> _readRaw(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object {
      // 安全存储不可用时按“读不到会话”处理，由上层记录 error 状态。
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readJson(String key) async {
    final raw = await _readRaw(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } on FormatException {
      return null;
    }
  }
}

/// 测试与自定义注入用的内存实现，字段保持可读以便断言迁移结果。
class InMemorySessionStorage implements SessionEnvelopeStorage {
  InMemorySessionStorage({this.canonical, this.legacy});

  /// 规范键上的原始值（Map 或字符串）。
  Object? canonical;

  /// 旧键上的原始值（Map 或字符串）。
  Object? legacy;

  @override
  Future<StorageRead> read() async {
    // 读取不得产生副作用：清理只在 clear() 或控制器的显式决策中发生。
    final canonicalSession = AccountSession.fromJson(_asMap(canonical));
    if (canonicalSession != null) {
      return StorageRead.canonical(session: canonicalSession);
    }
    final parsed = LegacySessionPayload.tryParse(legacy);
    if (parsed != null) return StorageRead.legacy(payload: parsed);
    return const StorageRead.missing();
  }

  @override
  Future<void> write(AccountSession session) async {
    canonical = session.toJson();
    legacy = SecureSessionStorage.legacyJson(session);
  }

  @override
  Future<void> clear() async {
    canonical = null;
    legacy = null;
  }

  static Map<String, dynamic>? _asMap(Object? value) => switch (value) {
    Map() => value.cast<String, dynamic>(),
    _ => null,
  };
}
