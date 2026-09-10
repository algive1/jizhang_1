import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/features/data_export/application/local_backup_service.dart';

void main() {
  test('exports the current database file as a valid SQLite backup', () async {
    final directory = await Directory.systemTemp.createTemp('jizhang-backup-');
    final database = AppDatabase.forTesting(
      NativeDatabase(
        File('${directory.path}/${LocalBackupService.databaseFileName}'),
      ),
    );
    final service = LocalBackupService(
      database,
      documentsDirectory: () async => directory,
    );

    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    await database.customSelect('SELECT 1').get();
    final bytes = await service.exportDatabase();

    expect(bytes, isNotEmpty);
    expect(
      () => LocalBackupService.validateBackupBytes(bytes),
      returnsNormally,
    );
  });

  test('restores a valid SQLite backup and rejects unrelated files', () async {
    final directory = await Directory.systemTemp.createTemp('jizhang-backup-');
    final sourcePath = '${directory.path}/source.sqlite';
    final source = sqlite3.open(sourcePath);
    source.execute('CREATE TABLE accounts (id TEXT PRIMARY KEY)');
    source.execute('CREATE TABLE transactions (id TEXT PRIMARY KEY)');
    source.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY)');
    source.close();
    final bytes = Uint8List.fromList(await File(sourcePath).readAsBytes());
    final database = createMemoryDatabase();
    final service = LocalBackupService(
      database,
      documentsDirectory: () async => directory,
    );

    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    await service.restoreDatabase(bytes);
    expect(
      File(
        '${directory.path}/${LocalBackupService.databaseFileName}${LocalBackupService.pendingRestoreSuffix}',
      ).existsSync(),
      isTrue,
    );
    await AppDatabase.applyPendingRestore(
      File('${directory.path}/${LocalBackupService.databaseFileName}'),
    );
    final restored = sqlite3.open(
      '${directory.path}/${LocalBackupService.databaseFileName}',
    );
    addTearDown(restored.close);
    expect(
      restored
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'])
          .toSet(),
      containsAll({'accounts', 'transactions', 'app_settings'}),
    );
    expect(
      () => LocalBackupService.validateBackupBytes(
        Uint8List.fromList('not a database'.codeUnits),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('requires the core application tables', () async {
    final directory = await Directory.systemTemp.createTemp('jizhang-backup-');
    final sourcePath = '${directory.path}/invalid.sqlite';
    final source = sqlite3.open(sourcePath);
    source.execute('CREATE TABLE unrelated (id TEXT PRIMARY KEY)');
    source.close();
    final bytes = Uint8List.fromList(await File(sourcePath).readAsBytes());
    final database = createMemoryDatabase();
    final service = LocalBackupService(
      database,
      documentsDirectory: () async => directory,
    );

    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    await expectLater(
      service.restoreDatabase(bytes),
      throwsA(isA<FormatException>()),
    );
  });
}
