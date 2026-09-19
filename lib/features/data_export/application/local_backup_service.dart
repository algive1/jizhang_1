import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/security/database_encryption_key_store.dart';

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

  static const encryptedArchiveFormat = 'haohao-local-backup-v2';
  static const _backupKdfIterations = 310000;
  static const _maxArchiveBytes = 256 * 1024 * 1024;

  /// Returns a plaintext SQLite snapshot for cloud/package compatibility.
  ///
  /// The live database is encrypted at rest. We checkpoint it, copy it to a
  /// temporary file, decrypt only that copy, read the snapshot and immediately
  /// delete the temporary plaintext file.
  Future<Uint8List> exportDatabase() async {
    await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final databaseFile = await _databaseFile();
    if (!await databaseFile.exists()) {
      throw StateError('本地数据库文件不存在');
    }

    final raw = await databaseFile.readAsBytes();
    if (_hasSqliteHeader(raw)) {
      // Test databases and legacy databases may still be plaintext.
      validateBackupBytes(Uint8List.fromList(raw));
      return Uint8List.fromList(raw);
    }

    final key = await DatabaseEncryptionKeyStore().loadOrCreate();
    final temporary = File(
      '${databaseFile.path}.backup-export-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    await databaseFile.copy(temporary.path);
    Database? snapshot;
    try {
      snapshot = sqlite3.open(temporary.path);
      final escaped = key.replaceAll("'", "''");
      snapshot.execute("PRAGMA key = '$escaped'");
      snapshot.select('SELECT count(*) FROM sqlite_master');
      snapshot.execute("PRAGMA rekey = ''");
      snapshot.close();
      snapshot = null;
      final bytes = Uint8List.fromList(await temporary.readAsBytes());
      validateBackupBytes(bytes);
      return bytes;
    } finally {
      snapshot?.close();
      await _deleteIfExists(temporary);
    }
  }

  Future<Uint8List> exportEncryptedArchive({
    required String password,
  }) async {
    final normalizedPassword = password.trim();
    if (normalizedPassword.length < 8) {
      throw const FormatException('备份密码至少需要 8 个字符');
    }
    final databaseBytes = await exportDatabase();
    final attachmentRows = await _database.customSelect(
      'SELECT id,path,name FROM transaction_attachments '
      'WHERE deleted_at IS NULL ORDER BY id',
    ).get();

    final attachments = <Map<String, Object?>>[];
    for (final row in attachmentRows) {
      final id = row.read<String>('id');
      final path = row.read<String>('path');
      final name = row.read<String>('name');
      Uint8List? content;
      if (path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          content = Uint8List.fromList(await file.readAsBytes());
        }
      }
      attachments.add({
        'id': id,
        'name': name,
        'content': content == null ? null : base64Encode(content),
      });
    }

    final clearPackage = utf8.encode(jsonEncode({
      'format': 'haohao-local-package-v2',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'database': base64Encode(databaseBytes),
      'attachments': attachments,
    }));
    final compressed = gzip.encode(clearPackage);
    if (compressed.length > _maxArchiveBytes) {
      throw const FormatException('完整备份过大，请先清理不需要的附件后重试');
    }

    final salt = _secureRandomBytes(16);
    final nonce = _secureRandomBytes(12);
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _backupKdfIterations,
      bits: 256,
    );
    final secretKey = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(normalizedPassword)),
      nonce: salt,
    );
    final secretBox = await AesGcm.with256bits().encrypt(
      compressed,
      secretKey: secretKey,
      nonce: nonce,
    );
    final container = {
      'format': encryptedArchiveFormat,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _backupKdfIterations,
      'cipher': 'aes-256-gcm',
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'payload': base64Encode(secretBox.cipherText),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(container)));
  }

  Future<void> restoreEncryptedArchive(
    Uint8List bytes, {
    required String password,
  }) async {
    if (bytes.length > _maxArchiveBytes * 2) {
      throw const FormatException('备份文件过大');
    }
    try {
      final raw = jsonDecode(utf8.decode(bytes));
      if (raw is! Map) throw const FormatException('备份格式无效');
      final container = raw.cast<String, dynamic>();
      if (container['format'] != encryptedArchiveFormat ||
          container['kdf'] != 'pbkdf2-hmac-sha256' ||
          container['cipher'] != 'aes-256-gcm') {
        throw const FormatException('不是受支持的好好记账加密备份');
      }
      final iterations = container['iterations'];
      if (iterations is! int || iterations < 100000 || iterations > 1000000) {
        throw const FormatException('备份密钥参数无效');
      }
      final salt = base64Decode(container['salt'] as String);
      final nonce = base64Decode(container['nonce'] as String);
      final mac = base64Decode(container['mac'] as String);
      final payload = base64Decode(container['payload'] as String);
      final kdf = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );
      final secretKey = await kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(password.trim())),
        nonce: salt,
      );
      final compressed = await AesGcm.with256bits().decrypt(
        SecretBox(payload, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );
      final unpacked = gzip.decode(compressed);
      if (unpacked.length > _maxArchiveBytes * 4) {
        throw const FormatException('备份解压后过大');
      }
      final packageRaw = jsonDecode(utf8.decode(unpacked));
      if (packageRaw is! Map) throw const FormatException('备份内容无效');
      final package = packageRaw.cast<String, dynamic>();
      if (package['format'] != 'haohao-local-package-v2' ||
          package['database'] is! String ||
          package['attachments'] is! List) {
        throw const FormatException('备份内容不完整');
      }
      final databaseBytes = Uint8List.fromList(
        base64Decode(package['database'] as String),
      );
      validateBackupBytes(databaseBytes);
      final attachments = <PendingRestoreAttachment>[];
      for (final rawAttachment in package['attachments'] as List) {
        if (rawAttachment is! Map) {
          throw const FormatException('附件备份记录无效');
        }
        final item = rawAttachment.cast<String, dynamic>();
        final id = item['id'];
        final name = item['name'];
        final content = item['content'];
        if (id is! String || id.isEmpty || name is! String) {
          throw const FormatException('附件备份记录不完整');
        }
        attachments.add(
          PendingRestoreAttachment(
            id: id,
            name: name,
            bytes: content is String
                ? Uint8List.fromList(base64Decode(content))
                : null,
          ),
        );
      }
      await restoreDatabase(databaseBytes);
      await preparePendingRestoreAttachments(attachments);
    } on SecretBoxAuthenticationError {
      throw const FormatException('备份密码错误或文件已损坏');
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('备份文件无法读取：$error');
    }
  }

  static bool isEncryptedArchive(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxArchiveBytes * 2) return false;
    try {
      final raw = jsonDecode(utf8.decode(bytes));
      return raw is Map && raw['format'] == encryptedArchiveFormat;
    } on Object {
      return false;
    }
  }

  static List<int> _secureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static bool _hasSqliteHeader(List<int> bytes) {
    return bytes.length >= _sqliteHeader.length &&
        String.fromCharCodes(bytes.take(_sqliteHeader.length)) == _sqliteHeader;
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
        final safeId = attachment.id.replaceAll(
          RegExp(r'[^\\w.\\-]'),
          '_',
        );
        final file = File(
          p.join(attachmentDirectory.path, '$safeId-$safeName'),
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
