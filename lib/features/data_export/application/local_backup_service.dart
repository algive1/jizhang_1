import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

typedef DocumentsDirectoryResolver = Future<Directory> Function();

class PendingRestoreAttachment {
  const PendingRestoreAttachment({
    required this.id,
    required this.name,
    required this.bytes,
  });

  final String id;
  final String name;
  final Uint8List? bytes;
}

class LocalBackupService {
  LocalBackupService(
    this._database, {
    DocumentsDirectoryResolver? documentsDirectory,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static const databaseFileName = AppDatabase.databaseFileName;
  static const pendingRestoreSuffix = AppDatabase.pendingRestoreSuffix;
  static const _sqliteHeader = 'SQLite format 3\u0000';

  final AppDatabase _database;
  final DocumentsDirectoryResolver _documentsDirectory;

  Future<Uint8List> exportDatabase() async {
    await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final databaseFile = await _databaseFile();
    if (!await databaseFile.exists()) {
      throw StateError('本地数据库文件不存在');
    }
    final bytes = await databaseFile.readAsBytes();
    validateBackupBytes(bytes);
    return Uint8List.fromList(bytes);
  }

  Future<void> restoreDatabase(Uint8List bytes) async {
    validateBackupBytes(bytes);
    final databaseFile = await _databaseFile();
    final temporaryFile = File(
      '${databaseFile.path}.restore-${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporaryFile.writeAsBytes(bytes, flush: true);
    try {
      _validateDatabaseFile(temporaryFile);
      await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      if (await databaseFile.exists()) {
        final safetyCopy = File(
          '${databaseFile.path}.pre-restore-${DateTime.now().microsecondsSinceEpoch}',
        );
        await databaseFile.copy(safetyCopy.path);
      }
      final pendingFile = File('${databaseFile.path}$pendingRestoreSuffix');
      await _deleteIfExists(pendingFile);
      await temporaryFile.rename(pendingFile.path);
    } catch (_) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      rethrow;
    }
  }

  Future<void> preparePendingRestoreAttachments(
    List<PendingRestoreAttachment> attachments,
  ) async {
    final databaseFile = await _databaseFile();
    final pendingFile = File('${databaseFile.path}$pendingRestoreSuffix');
    if (!await pendingFile.exists()) {
      throw StateError('待恢复数据库不存在');
    }

    final documents = await _documentsDirectory();
    final attachmentDirectory = Directory(
      p.join(documents.path, 'bookkeeping_attachments'),
    );
    await attachmentDirectory.create(recursive: true);

    Database? pending;
    try {
      pending = sqlite3.open(pendingFile.path);
      final tables = pending
          .select(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name='transaction_attachments'",
          );
      if (tables.isEmpty) return;

      // Cloud package v2 owns the active attachment paths. Clear source-device
      // absolute paths first so a restored database never points at another
      // device's documents directory.
      pending.execute(
        "UPDATE transaction_attachments SET path='' WHERE deleted_at IS NULL",
      );

      for (final attachment in attachments) {
        final bytes = attachment.bytes;
        if (bytes == null) continue;
        final baseName = p.basename(attachment.name).trim();
        final safeName = (baseName.isEmpty ? 'attachment' : baseName).replaceAll(
          RegExp(r'[^\w.\-\u4e00-\u9fa5]'),
          '_',
        );
        final file = File(
          p.join(attachmentDirectory.path, '${attachment.id}-$safeName'),
        );
        await file.writeAsBytes(bytes, flush: true);
        pending.execute(
          'UPDATE transaction_attachments '
          'SET path=?,size_in_bytes=?,updated_at=? '
          'WHERE id=? AND deleted_at IS NULL',
          [
            file.path,
            bytes.length,
            DateTime.now().millisecondsSinceEpoch,
            attachment.id,
          ],
        );
      }
    } finally {
      pending?.close();
    }
  }

  Future<void> stampPendingCloudRestore({
    required String datasetId,
    required String userId,
    required int revision,
    required DateTime syncedAt,
  }) async {
    final databaseFile = await _databaseFile();
    final pendingFile = File('${databaseFile.path}$pendingRestoreSuffix');
    if (!await pendingFile.exists()) {
      throw StateError('待恢复数据库不存在');
    }

    Database? pending;
    try {
      pending = sqlite3.open(pendingFile.path);
      final tables = pending
          .select("SELECT name FROM sqlite_master WHERE type='table' AND name='device_data_binding'");
      if (tables.isEmpty) {
        pending.execute('''
          CREATE TABLE device_data_binding(
            id INTEGER PRIMARY KEY CHECK(id=1),
            dataset_id TEXT NOT NULL UNIQUE,
            bound_user_id TEXT,
            cloud_sync_enabled INTEGER NOT NULL DEFAULT 0,
            bound_at INTEGER,
            last_sync_at INTEGER,
            last_cloud_revision INTEGER NOT NULL DEFAULT 0,
            last_seen_remote_revision INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      } else {
        final columns = pending
            .select('PRAGMA table_info(device_data_binding)')
            .map((row) => row['name'] as String)
            .toSet();
        if (!columns.contains('last_cloud_revision')) {
          pending.execute(
            'ALTER TABLE device_data_binding '
            'ADD COLUMN last_cloud_revision INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (!columns.contains('last_seen_remote_revision')) {
          pending.execute(
            'ALTER TABLE device_data_binding '
            'ADD COLUMN last_seen_remote_revision INTEGER NOT NULL DEFAULT 0',
          );
        }
      }

      final synced = syncedAt.millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      pending.execute(
        'INSERT INTO device_data_binding('
        'id,dataset_id,bound_user_id,cloud_sync_enabled,bound_at,last_sync_at,last_cloud_revision,last_seen_remote_revision,created_at,updated_at'
        ') VALUES(1,?,?,1,?,?,?,?, ?,?) '
        'ON CONFLICT(id) DO UPDATE SET '
        'dataset_id=excluded.dataset_id,'
        'bound_user_id=excluded.bound_user_id,'
        'cloud_sync_enabled=1,'
        'last_sync_at=excluded.last_sync_at,'
        'last_cloud_revision=excluded.last_cloud_revision,'
        'last_seen_remote_revision=excluded.last_seen_remote_revision,'
        'updated_at=excluded.updated_at',
        [datasetId, userId, now, synced, revision, revision, now, now],
      );
    } finally {
      pending?.close();
    }
  }

  static void validateBackupBytes(Uint8List bytes) {
    if (bytes.length < _sqliteHeader.length ||
        String.fromCharCodes(bytes.take(_sqliteHeader.length)) !=
            _sqliteHeader) {
      throw const FormatException('备份文件不是有效的 SQLite 数据库');
    }
  }

  Future<File> _databaseFile() async {
    final directory = await _documentsDirectory();
    return File(p.join(directory.path, databaseFileName));
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  void _validateDatabaseFile(File file) {
    Database? database;
    try {
      database = sqlite3.open(file.path);
      final tables = database
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      const requiredTables = {'accounts', 'transactions', 'app_settings'};
      if (!requiredTables.every(tables.contains)) {
        throw const FormatException('备份文件缺少好好记账核心数据表');
      }
      final schemaVersion =
          database.select('PRAGMA user_version').single.values.single as int;
      if (schemaVersion > _database.schemaVersion) {
        throw FormatException(
          '备份文件来自更新版本（$schemaVersion），当前应用仅支持 ${_database.schemaVersion}',
        );
      }
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('备份文件无法读取：$error');
    } finally {
      database?.close();
    }
  }
}

final localBackupServiceProvider = Provider<LocalBackupService>((ref) {
  return LocalBackupService(ref.watch(databaseProvider));
});
