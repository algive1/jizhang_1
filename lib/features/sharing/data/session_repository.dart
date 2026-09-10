import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import 'shared_api.dart';

class SessionUser {
  const SessionUser(this.id, this.username);
  final String id;
  final String username;
}

abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage();
  static const _storage = FlutterSecureStorage();
  static const _name = 'shared_ledger_session_v1';
  @override
  Future<String?> read() => _storage.read(key: _name);
  @override
  Future<void> write(String? value) => value == null
      ? _storage.delete(key: _name)
      : _storage.write(key: _name, value: value);
}

class SessionRepository {
  SessionRepository(this.api, this.database, {SessionStorage? storage})
    : storage = storage ?? const SecureSessionStorage();
  final SharedApi api;
  final AppDatabase database;
  final SessionStorage storage;
  final _changes = StreamController<SessionUser?>.broadcast();
  SessionUser? user;
  Future<void>? _initializing;
  Stream<SessionUser?> watch() async* {
    await initialize();
    yield user;
    yield* _changes.stream;
  }

  Future<void> initialize() => _initializing ??= _restore();
  Future<void> _restore() async {
    final stored = await storage.read();
    if (stored == null) return;
    final data = jsonDecode(stored) as Map<String, dynamic>;
    if (data['baseUrl'] != api.baseUrl) return;
    if ((data['expiresAt'] as int) * 1000 <=
        DateTime.now().millisecondsSinceEpoch) {
      await storage.write(null);
      return;
    }
    api.sessionToken = data['token'] as String;
    user = SessionUser(
      data['user']['id'] as String,
      data['user']['username'] as String,
    );
    await database.setSyncActor(user!.id);
  }

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
    await storage.write(jsonEncode({...data, 'baseUrl': api.baseUrl}));
    api.sessionToken = data['token'] as String;
    user = SessionUser(
      data['user']['id'] as String,
      data['user']['username'] as String,
    );
    await database.setSyncActor(user!.id);
    _changes.add(user);
  }

  Future<void> logout() async {
    try {
      if (api.sessionToken != null)
        await api.request('/auth/logout', method: 'POST', body: {});
    } finally {
      await invalidate();
    }
  }

  Future<void> invalidate() async {
    await storage.write(null);
    api.sessionToken = null;
    user = null;
    await database.setSyncActor('user-local');
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
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
