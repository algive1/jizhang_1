import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

typedef DocumentsDirectoryResolver = Future<Directory> Function();

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
