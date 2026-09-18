part of 'app_database.dart';

class DeviceDataBinding {
  const DeviceDataBinding({
    required this.datasetId,
    required this.boundUserId,
    required this.cloudSyncEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.boundAt,
    this.lastSyncAt,
    this.lastCloudRevision = 0,
  });

  final String datasetId;
  final String? boundUserId;
  final bool cloudSyncEnabled;
  final DateTime? boundAt;
  final DateTime? lastSyncAt;
  final int lastCloudRevision;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isBoundTo(String userId) => boundUserId == userId;
}

class DatasetBindingConflict implements Exception {
  const DatasetBindingConflict(this.boundUserId);
  final String boundUserId;

  @override
  String toString() => '当前本地数据已经绑定其他账号，不能自动改绑';
}

extension DeviceDataBindingStore on AppDatabase {
  Future<void> ensureDataBindingSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS device_data_binding(
        id INTEGER PRIMARY KEY CHECK(id=1),
        dataset_id TEXT NOT NULL UNIQUE,
        bound_user_id TEXT,
        cloud_sync_enabled INTEGER NOT NULL DEFAULT 0,
        bound_at INTEGER,
        last_sync_at INTEGER,
        last_cloud_revision INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    final columns = await customSelect(
      'PRAGMA table_info(device_data_binding)',
    ).get();
    if (!columns.any((row) => row.read<String>('name') == 'last_cloud_revision')) {
      await customStatement(
        'ALTER TABLE device_data_binding '
        'ADD COLUMN last_cloud_revision INTEGER NOT NULL DEFAULT 0',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'INSERT OR IGNORE INTO device_data_binding('
      'id,dataset_id,bound_user_id,cloud_sync_enabled,bound_at,last_sync_at,last_cloud_revision,created_at,updated_at'
      ') VALUES(1,?,NULL,0,NULL,NULL,0,?,?)',
      [newEntityId(), now, now],
    );
  }

  Future<DeviceDataBinding> getDeviceDataBinding() async {
    await ensureDataBindingSchema();
    final row = await customSelect(
      'SELECT dataset_id,bound_user_id,cloud_sync_enabled,bound_at,last_sync_at,last_cloud_revision,created_at,updated_at '
      'FROM device_data_binding WHERE id=1',
    ).getSingle();

    DateTime? date(Object? value) => value is int
        ? DateTime.fromMillisecondsSinceEpoch(value)
        : null;

    return DeviceDataBinding(
      datasetId: row.read<String>('dataset_id'),
      boundUserId: row.data['bound_user_id'] as String?,
      cloudSyncEnabled: row.read<int>('cloud_sync_enabled') == 1,
      boundAt: date(row.data['bound_at']),
      lastSyncAt: date(row.data['last_sync_at']),
      lastCloudRevision: row.read<int>('last_cloud_revision'),
      createdAt: date(row.data['created_at'])!,
      updatedAt: date(row.data['updated_at'])!,
    );
  }

  Future<DeviceDataBinding> bindDatasetToUser(String userId) {
    return transaction(() async {
      final current = await getDeviceDataBinding();
      final existing = current.boundUserId;
      if (existing != null && existing != userId) {
        throw DatasetBindingConflict(existing);
      }
      if (existing == null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await customStatement(
          'UPDATE device_data_binding '
          'SET bound_user_id=?,bound_at=?,updated_at=? WHERE id=1',
          [userId, now, now],
        );
      }
      return getDeviceDataBinding();
    });
  }

  Future<DeviceDataBinding> setDatasetCloudCheckpoint({
    required String userId,
    required int revision,
    DateTime? at,
  }) {
    return transaction(() async {
      final current = await getDeviceDataBinding();
      if (current.boundUserId != userId || !current.cloudSyncEnabled) {
        throw StateError('本地数据尚未启用当前账号的云同步');
      }
      final now = (at ?? DateTime.now()).millisecondsSinceEpoch;
      await customStatement(
        'UPDATE device_data_binding '
        'SET last_sync_at=?,last_cloud_revision=?,updated_at=? WHERE id=1',
        [now, revision, now],
      );
      return getDeviceDataBinding();
    });
  }

  Future<DeviceDataBinding> setDatasetCloudSyncEnabled({
    required String userId,
    required bool enabled,
  }) {
    return transaction(() async {
      final current = await getDeviceDataBinding();
      if (current.boundUserId != userId) {
        throw StateError('本地数据必须先绑定当前账号');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await customStatement(
        'UPDATE device_data_binding '
        'SET cloud_sync_enabled=?,updated_at=? WHERE id=1',
        [enabled ? 1 : 0, now],
      );
      return getDeviceDataBinding();
    });
  }
}
