import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseEncryptionKeyStore {
  DatabaseEncryptionKeyStore({
    FlutterSecureStorage? storage,
    Random? random,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _random = random ?? Random.secure();

  static const storageKey = 'database.encryption.key.v1';

  final FlutterSecureStorage _storage;
  final Random _random;

  Future<String> loadOrCreate() async {
    final existing = (await _storage.read(key: storageKey))?.trim();
    if (existing != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(existing)) {
      return existing;
    }

    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final created = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: storageKey, value: created);
    return created;
  }
}
