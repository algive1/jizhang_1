import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/membership.dart';
import '../../data_export/application/local_backup_service.dart';
import '../../membership/data/membership_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import 'personal_cloud_bootstrap_service.dart';

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

  Future<({String userId, DeviceDataBinding binding})> _context() async {
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
    if (!binding.cloudSyncEnabled) {
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

    final databaseBytes = await localBackup.exportDatabase();
    final compressed = gzip.encode(databaseBytes);
    if (compressed.length > 10 * 1024 * 1024) {
      throw StateError('当前账务备份压缩后超过 10MB，暂时无法上传');
    }

    final response = await api.request(
      '/sync/snapshot',
      method: 'POST',
      body: {
        'datasetId': context.binding.datasetId,
        'baseRevision': current.revision,
        'encoding': 'gzip+base64',
        'snapshot': base64Encode(compressed),
      },
    );
    final result = PersonalCloudStatus.fromJson(response);
    if (!result.datasetMatches || !result.hasSnapshot) {
      throw StateError('云端备份状态异常，请稍后重试');
    }

    await database.setDatasetLastSyncAt(
      userId: context.userId,
      at: result.updatedAt ?? DateTime.now(),
    );
    return result;
  }
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
