import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/features/data_export/application/local_backup_service.dart';

void main() {
  for (final existingDevice in [true, false]) {
    test(
      'restore keeps device identity and consent ${existingDevice ? 'on this device' : 'off on a new device'}',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'restore-device-settings-',
        );
        final sourceDirectory = await Directory('${root.path}/source').create();
        final targetDirectory = await Directory('${root.path}/target').create();
        final source = AppDatabase.forTesting(
          NativeDatabase(
            File(
              '${sourceDirectory.path}/${LocalBackupService.databaseFileName}',
            ),
          ),
        );
        final target = AppDatabase.forTesting(
          NativeDatabase(
            File(
              '${targetDirectory.path}/${LocalBackupService.databaseFileName}',
            ),
          ),
        );
        addTearDown(() async {
          await source.close();
          await target.close();
          await root.delete(recursive: true);
        });
        final now = DateTime.now();
        final importedDeviceSettings = {
          'analytics.installation_id.v1': 'a' * 32,
          'push.device_id.v1': 'source-push',
          'analytics.enabled.v1': 'true',
          'analytics.queue.v1': '[{"eventId":"source-event"}]',
          'app.heartbeat.v1.origin.user': 'source-checkpoint',
          'app.runtime.v1.origin.config': 'source-cache',
          'cloud.backup.auto.user.dataset': 'true',
        };
        for (final entry in importedDeviceSettings.entries) {
          await source.appSettingsDao.setValue(entry.key, entry.value, now);
        }
        await source.appSettingsDao.setValue(
          'theme.selected',
          'fresh_green',
          now,
        );
        if (existingDevice) {
          await target.appSettingsDao.setValue(
            'analytics.installation_id.v1',
            'b' * 32,
            now,
          );
          await target.appSettingsDao.setValue(
            'push.device_id.v1',
            'target-push',
            now,
          );
          await target.appSettingsDao.setValue(
            'analytics.enabled.v1',
            'false',
            now,
          );
          await target.appSettingsDao.setValue(
            'cloud.backup.auto.user.dataset',
            'false',
            now,
          );
          await target.appSettingsDao.setValue(
            'app.runtime.v1.origin.config',
            'target-cache',
            now,
          );
        }
        final sourceBackup = LocalBackupService(
          source,
          documentsDirectory: () async => sourceDirectory,
        );
        final targetBackup = LocalBackupService(
          target,
          documentsDirectory: () async => targetDirectory,
        );
        await targetBackup.restoreDatabase(await sourceBackup.exportDatabase());
        final pending = sqlite3.open(
          '${targetDirectory.path}/${LocalBackupService.databaseFileName}${LocalBackupService.pendingRestoreSuffix}',
        );
        try {
          final settings = {
            for (final row in pending.select(
              'SELECT key,value FROM app_settings',
            ))
              row['key'] as String: row['value'],
          };
          expect(settings['theme.selected'], 'fresh_green');
          expect(
            settings['analytics.installation_id.v1'],
            existingDevice ? 'b' * 32 : isNull,
          );
          expect(
            settings['push.device_id.v1'],
            existingDevice ? 'target-push' : isNull,
          );
          expect(
            settings['analytics.enabled.v1'],
            existingDevice ? 'false' : isNull,
          );
          expect(
            settings['cloud.backup.auto.user.dataset'],
            existingDevice ? 'false' : isNull,
          );
          expect(
            settings['app.runtime.v1.origin.config'],
            existingDevice ? 'target-cache' : isNull,
          );
          expect(settings['analytics.queue.v1'], isNull);
          expect(settings['app.heartbeat.v1.origin.user'], isNull);
        } finally {
          pending.close();
        }
      },
    );
  }
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

  test('encrypted archive protects SQLite contents and restores attachments', () async {
    final sourceDirectory = await Directory.systemTemp.createTemp(
      'jizhang-encrypted-backup-source-',
    );
    final targetDirectory = await Directory.systemTemp.createTemp(
      'jizhang-encrypted-backup-target-',
    );
    final sourceDatabase = AppDatabase.forTesting(
      NativeDatabase(
        File('${sourceDirectory.path}/${LocalBackupService.databaseFileName}'),
      ),
    );
    final targetDatabase = createMemoryDatabase();
    final sourceService = LocalBackupService(
      sourceDatabase,
      documentsDirectory: () async => sourceDirectory,
    );
    final targetService = LocalBackupService(
      targetDatabase,
      documentsDirectory: () async => targetDirectory,
    );

    addTearDown(() async {
      await sourceDatabase.close();
      await targetDatabase.close();
      await sourceDirectory.delete(recursive: true);
      await targetDirectory.delete(recursive: true);
    });

    await sourceDatabase.customSelect('SELECT 1').get();
    final attachment = File('${sourceDirectory.path}/invoice.txt');
    await attachment.writeAsString('receipt-content', flush: true);
    await sourceDatabase.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    await sourceDatabase.customStatement(
      'INSERT INTO transaction_attachments('
      'id,book_id,transaction_id,path,name,mime_type,sort_order,size_in_bytes,checksum,created_at,updated_at,deleted_at'
      ') VALUES(?,?,?,?,?,?,?,?,?,?,?,NULL)',
      [
        'attachment-test',
        'book-personal',
        'transaction-test',
        attachment.path,
        'invoice.txt',
        'text/plain',
        0,
        await attachment.length(),
        null,
        now,
        now,
      ],
    );

    final archive = await sourceService.exportEncryptedArchive(
      password: 'correct horse battery staple',
    );
    expect(LocalBackupService.isEncryptedArchive(archive), isTrue);
    expect(
      String.fromCharCodes(archive.take(16)),
      isNot('SQLite format 3\u0000'),
    );

    await expectLater(
      targetService.restoreEncryptedArchive(
        archive,
        password: 'wrong-password',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      File(
        '${targetDirectory.path}/${LocalBackupService.databaseFileName}${LocalBackupService.pendingRestoreSuffix}',
      ).existsSync(),
      isFalse,
    );

    await targetService.restoreEncryptedArchive(
      archive,
      password: 'correct horse battery staple',
    );
    final pending = File(
      '${targetDirectory.path}/${LocalBackupService.databaseFileName}${LocalBackupService.pendingRestoreSuffix}',
    );
    expect(pending.existsSync(), isTrue);

    final restored = sqlite3.open(pending.path);
    addTearDown(restored.close);
    final row = restored.select(
      'SELECT path,size_in_bytes FROM transaction_attachments WHERE id=?',
      ['attachment-test'],
    ).single;
    final restoredPath = row['path'] as String;
    expect(restoredPath, isNot(attachment.path));
    expect(await File(restoredPath).readAsString(), 'receipt-content');
    expect(row['size_in_bytes'], 'receipt-content'.length);
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
