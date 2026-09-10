import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

abstract interface class AppSettingsRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
}

class DriftAppSettingsRepository implements AppSettingsRepository {
  DriftAppSettingsRepository(this._database);

  final AppDatabase _database;

  @override
  Future<String?> get(String key) => _database.appSettingsDao.getValue(key);

  @override
  Future<void> set(String key, String value) {
    return _database.appSettingsDao.setValue(key, value, DateTime.now());
  }
}

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return DriftAppSettingsRepository(ref.watch(databaseProvider));
});
