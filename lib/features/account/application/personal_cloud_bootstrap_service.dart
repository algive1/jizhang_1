import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/membership.dart';
import '../../membership/data/membership_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../../app_runtime/data/app_runtime_repository.dart';

class CloudSyncMembershipRequired implements Exception {
  const CloudSyncMembershipRequired();

  @override
  String toString() => '云同步需要有效会员';
}

class PersonalCloudDatasetConflict implements Exception {
  const PersonalCloudDatasetConflict();

  @override
  String toString() => '云端已有另一份个人数据，需要先恢复或合并';
}

class PersonalCloudStatus {
  const PersonalCloudStatus({
    required this.exists,
    required this.canonicalDatasetId,
    required this.datasetMatches,
    required this.hasSnapshot,
    required this.revision,
    required this.updatedAt,
    required this.snapshotSize,
    required this.snapshotSha256,
  });

  final bool exists;
  final String? canonicalDatasetId;
  final bool datasetMatches;
  final bool hasSnapshot;
  final int revision;
  final DateTime? updatedAt;
  final int? snapshotSize;
  final String? snapshotSha256;

  static PersonalCloudStatus fromJson(Map<String, dynamic> json) {
    final rawUpdated = json['updatedAt'];
    return PersonalCloudStatus(
      exists: json['exists'] == true,
      canonicalDatasetId: json['canonicalDatasetId'] as String?,
      datasetMatches: json['datasetMatches'] == true,
      hasSnapshot: json['hasSnapshot'] == true,
      revision: json['revision'] as int? ?? 0,
      updatedAt: rawUpdated is int
          ? DateTime.fromMillisecondsSinceEpoch(rawUpdated * 1000)
          : null,
      snapshotSize: json['snapshotSize'] as int?,
      snapshotSha256: json['snapshotSha256'] as String?,
    );
  }
}

class PersonalCloudBootstrapService {
  const PersonalCloudBootstrapService(
    this.database,
    this.session,
    this.api,
    this.membership, {
    this.beforeCloudOperation,
  });

  final AppDatabase database;
  final SessionRepository session;
  final SharedApi api;
  final MembershipRepository membership;
  final Future<void> Function()? beforeCloudOperation;

  void _assertSession(String userId, String? token) {
    if (session.userId != userId || api.sessionToken != token) {
      throw StateError('账号已切换，请重试');
    }
  }

  Future<({String userId, String? token, DeviceDataBinding binding})>
  _context() async {
    await session.initialize();
    final userId = session.userId;
    final token = api.sessionToken;
    if (userId == null) throw StateError('请先登录');
    await beforeCloudOperation?.call();
    _assertSession(userId, token);

    final membershipSnapshot = await membership.getCurrent();
    if (!membershipSnapshot.has(EntitlementKey.cloudSync) ||
        !membershipSnapshot.canUseFeature(MembershipFeature.ledgerSync)) {
      throw const CloudSyncMembershipRequired();
    }

    final binding = await database.getDeviceDataBinding();
    _assertSession(userId, token);
    if (binding.boundUserId == null) {
      throw StateError('请先绑定本地数据');
    }
    if (binding.boundUserId != userId) {
      throw const DatasetBindingConflict('other-account');
    }
    return (userId: userId, token: token, binding: binding);
  }

  Future<PersonalCloudStatus> status() async {
    final context = await _context();
    final data = await api.request(
      '/sync/status?datasetId=${context.binding.datasetId}',
      bearerToken: context.token,
    );
    _assertSession(context.userId, context.token);
    return PersonalCloudStatus.fromJson(data);
  }

  Future<PersonalCloudStatus> bootstrap() async {
    final context = await _context();
    final data = await api.request(
      '/sync/bootstrap',
      method: 'POST',
      bearerToken: context.token,
      body: {'datasetId': context.binding.datasetId},
    );
    _assertSession(context.userId, context.token);
    final result = PersonalCloudStatus.fromJson(data);
    if (result.datasetMatches) {
      await database.setDatasetCloudSyncEnabled(
        userId: context.userId,
        enabled: true,
      );
    }
    return result;
  }
}

final personalCloudBootstrapServiceProvider =
    Provider<PersonalCloudBootstrapService>((ref) {
      return PersonalCloudBootstrapService(
        ref.watch(databaseProvider),
        ref.watch(sessionRepositoryProvider),
        ref.watch(sharedApiProvider),
        ref.watch(membershipRepositoryProvider),
        beforeCloudOperation: () => ref
            .read(appRuntimeRepositoryProvider)
            .require(AppCapability.cloudBackup),
      );
    });
