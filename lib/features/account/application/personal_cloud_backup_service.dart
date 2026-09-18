import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/membership.dart';
import '../../data_export/application/local_backup_service.dart';
import '../../membership/data/membership_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import 'personal_cloud_bootstrap_service.dart';

class PersonalCloudRevisionConflict implements Exception {
  const PersonalCloudRevisionConflict({
    required this.localRevision,
    required this.remoteRevision,
  });

  final int localRevision;
  final int remoteRevision;

  @override
  String toString() => '云端已有更新，请先恢复或处理冲突后再备份';
}

class PersonalCloudBackupService {
  const PersonalCloudBackupService(
    this.database,
    this.session,
    this.api,
    this.membership,
    this.localBackup,
  );

  final AppDatabase database;
  final SessionRepository session;
  final SharedApi api;
  final MembershipRepository membership;
  final LocalBackupService localBackup;

  Future<({String userId, DeviceDataBinding binding})> _context({
    bool requireEnabled = true,
  }) async {
    await session.initialize();
    final userId = session.userId;
    if (userId == null) throw StateError('请先登录');

    final membershipSnapshot = await membership.getCurrent();
    if (!membershipSnapshot.has(EntitlementKey.cloudSync)) {
      throw const CloudSyncMembershipRequired();
    }

    final binding = await database.getDeviceDataBinding();
    if (binding.boundUserId != userId) {
      throw StateError('本地数据尚未绑定当前账号');
    }
    if (requireEnabled && !binding.cloudSyncEnabled) {
      throw StateError('请先启用云同步通道');
    }
    return (userId: userId, binding: binding);
  }

  Future<PersonalCloudStatus> uploadSnapshot() async {
    final context = await _context();
    final statusJson = await api.request(
      '/sync/status?datasetId=${context.binding.datasetId}',
    );
    final current = PersonalCloudStatus.fromJson(statusJson);
    if (!current.exists || !current.datasetMatches) {
      throw const PersonalCloudDatasetConflict();
    }

    var localRevision = context.binding.lastCloudRevision;
    if (current.hasSnapshot && localRevision != current.revision) {
      final localTime = context.binding.lastSyncAt;
      final remoteTime = current.updatedAt;
      final legacyCheckpointMatches =
          localRevision == 0 &&
          localTime != null &&
          remoteTime != null &&
          localTime.difference(remoteTime).abs() <= const Duration(seconds: 1);
      if (legacyCheckpointMatches) {
        await database.setDatasetCloudCheckpoint(
          userId: context.userId,
          revision: current.revision,
          at: remoteTime,
        );
        localRevision = current.revision;
      }
    }
    if (current.hasSnapshot && localRevision != current.revision) {
      throw PersonalCloudRevisionConflict(
        localRevision: localRevision,
        remoteRevision: current.revision,
      );
    }

    final databaseBytes = await localBackup.exportDatabase();
    final attachmentRows = await database.customSelect(
      'SELECT id,path,name FROM transaction_attachments '
      'WHERE deleted_at IS NULL ORDER BY id',
    ).get();
    final attachments = <Map<String, Object?>>[];
    for (final row in attachmentRows) {
      final id = row.read<String>('id');
      final path = row.read<String>('path');
      final name = row.read<String>('name');
      final file = File(path);
      String? content;
      if (path.isNotEmpty && await file.exists()) {
        content = base64Encode(await file.readAsBytes());
      }
      attachments.add({
        'id': id,
        'name': name,
        'content': content,
      });
    }

    final package = utf8.encode(
      jsonEncode({
        'format': 'haohao-cloud-v2',
        'database': base64Encode(databaseBytes),
        'attachments': attachments,
      }),
    );
    final compressed = gzip.encode(package);
    if (compressed.length > 10 * 1024 * 1024) {
      throw StateError('账务与附件备份压缩后超过 10MB，暂时无法上传');
    }

    final response = await api.request(
      '/sync/snapshot',
      method: 'POST',
      body: {
        'datasetId': context.binding.datasetId,
        'baseRevision': current.revision,
        'encoding': 'gzip+base64+json-v2',
        'snapshot': base64Encode(compressed),
      },
    );
    final result = PersonalCloudStatus.fromJson(response);
    if (!result.datasetMatches || !result.hasSnapshot) {
      throw StateError('云端备份状态异常，请稍后重试');
    }

    await database.setDatasetCloudCheckpoint(
      userId: context.userId,
      revision: result.revision,
      at: result.updatedAt ?? DateTime.now(),
    );
    return result;
  }
  Future<PersonalCloudRestoreResult> downloadAndPrepareRestore() async {
    final context = await _context(requireEnabled: false);
    final response = await api.request('/sync/snapshot/download');
    final encoding = response['encoding'] as String?;
    if (encoding != 'gzip+base64' &&
        encoding != 'gzip+base64+json-v2') {
      throw const FormatException('云端备份编码不受支持');
    }

    final encoded = response['snapshot'] as String?;
    final canonicalDatasetId = response['datasetId'] as String?;
    final revision = response['revision'] as int? ?? 0;
    if (encoded == null || canonicalDatasetId == null || revision <= 0) {
      throw const FormatException('云端备份信息不完整');
    }

    late Uint8List databaseBytes;
    var restoredAttachments = const <PendingRestoreAttachment>[];
    try {
      final compressed = base64Decode(encoded);
      final uncompressed = Uint8List.fromList(gzip.decode(compressed));
      if (encoding == 'gzip+base64') {
        databaseBytes = uncompressed;
      } else {
        final package = jsonDecode(utf8.decode(uncompressed));
        if (package is! Map<String, dynamic> ||
            package['format'] != 'haohao-cloud-v2' ||
            package['database'] is! String ||
            package['attachments'] is! List) {
          throw const FormatException('云端附件备份格式无效');
        }
        databaseBytes = base64Decode(package['database'] as String);
        restoredAttachments = (package['attachments'] as List)
            .map((raw) {
              if (raw is! Map) {
                throw const FormatException('云端附件记录无效');
              }
              final value = raw.cast<String, dynamic>();
              final id = value['id'];
              final name = value['name'];
              final content = value['content'];
              if (id is! String || name is! String) {
                throw const FormatException('云端附件记录不完整');
              }
              return PendingRestoreAttachment(
                id: id,
                name: name,
                bytes: content is String ? base64Decode(content) : null,
              );
            })
            .toList(growable: false);
      }
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('云端备份无法解压：$error');
    }

    LocalBackupService.validateBackupBytes(databaseBytes);
    await localBackup.restoreDatabase(databaseBytes);
    if (encoding == 'gzip+base64+json-v2') {
      await localBackup.preparePendingRestoreAttachments(restoredAttachments);
    }
    await localBackup.stampPendingCloudRestore(
      datasetId: canonicalDatasetId,
      userId: context.userId,
      revision: revision,
      syncedAt: response['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(
              (response['updatedAt'] as int) * 1000,
            )
          : DateTime.now(),
    );

    return PersonalCloudRestoreResult(
      datasetId: canonicalDatasetId,
      revision: revision,
      snapshotSize: response['snapshotSize'] as int?,
      updatedAt: response['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(
              (response['updatedAt'] as int) * 1000,
            )
          : null,
    );
  }

}


class PersonalCloudRestoreResult {
  const PersonalCloudRestoreResult({
    required this.datasetId,
    required this.revision,
    required this.snapshotSize,
    required this.updatedAt,
  });

  final String datasetId;
  final int revision;
  final int? snapshotSize;
  final DateTime? updatedAt;
}

final personalCloudBackupServiceProvider = Provider<PersonalCloudBackupService>(
  (ref) => PersonalCloudBackupService(
    ref.watch(databaseProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(sharedApiProvider),
    ref.watch(membershipRepositoryProvider),
    ref.watch(localBackupServiceProvider),
  ),
);
