import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/features/data_export/application/local_backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('cloud attachment restore rewrites source paths to this device', () async {
    final directory = await Directory.systemTemp.createTemp(
      'haohao-cloud-attachments-',
    );
    final database = createMemoryDatabase();
    final service = LocalBackupService(
      database,
      documentsDirectory: () async => directory,
    );

    addTearDown(() async {
      await database.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final pendingPath = p.join(
      directory.path,
      '${LocalBackupService.databaseFileName}'
      '${LocalBackupService.pendingRestoreSuffix}',
    );
    final pending = sqlite3.open(pendingPath);
    pending.execute('''
      CREATE TABLE transaction_attachments(
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        name TEXT NOT NULL,
        size_in_bytes INTEGER,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    pending.execute(
      'INSERT INTO transaction_attachments '
      '(id,path,name,size_in_bytes,updated_at,deleted_at) '
      'VALUES(?,?,?,?,?,NULL)',
      ['attachment-a', '/old/device/receipt.jpg', 'receipt.jpg', 1, 1],
    );
    pending.execute(
      'INSERT INTO transaction_attachments '
      '(id,path,name,size_in_bytes,updated_at,deleted_at) '
      'VALUES(?,?,?,?,?,NULL)',
      ['attachment-missing', '/old/device/missing.pdf', 'missing.pdf', 1, 1],
    );
    pending.close();

    await service.preparePendingRestoreAttachments([
      PendingRestoreAttachment(
        id: 'attachment-a',
        name: 'receipt.jpg',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
      const PendingRestoreAttachment(
        id: 'attachment-missing',
        name: 'missing.pdf',
        bytes: null,
      ),
    ]);

    final restored = sqlite3.open(pendingPath, mode: OpenMode.readOnly);
    addTearDown(restored.close);
    final rows = restored
        .select('SELECT id,path,size_in_bytes FROM transaction_attachments ORDER BY id')
        .toList();

    final first = rows.firstWhere((row) => row['id'] == 'attachment-a');
    final restoredPath = first['path'] as String;
    expect(restoredPath, startsWith(p.join(directory.path, 'bookkeeping_attachments')));
    expect(restoredPath, isNot(contains('/old/device/')));
    expect(first['size_in_bytes'], 4);
    expect(await File(restoredPath).readAsBytes(), [1, 2, 3, 4]);

    final missing = rows.firstWhere((row) => row['id'] == 'attachment-missing');
    expect(missing['path'], '');
  });
}
