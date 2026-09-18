import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/membership.dart';
import '../../membership/data/membership_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';

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
  });

  final bool exists;
  final String? canonicalDatasetId;
  final bool datasetMatches;
  final bool hasSnapshot;
  final int revision;
  final DateTime? updatedAt;

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
    );
  }
}

class PersonalCloudBootstrapService {
  const PersonalCloudBootstrapService(
    this.database,
    this.session,
    this.api,
    this.membership,
  );

  final AppDatabase database;
  final SessionRepository session;
  final SharedApi api;
  final MembershipRepository membership;

  Future<({String userId, DeviceDataBinding binding})> _context() async {
    await session.initialize();
    final userId = session.userId;
    if (userId == null) throw StateError('请先登录');

    final membershipSnapshot = await membership.getCurrent();
    if (!membershipSnapshot.has(EntitlementKey.cloudSync)) {
      throw const CloudSyncMembershipRequired();
    }

    final binding = await database.getDeviceDataBinding();
    if (binding.boundUserId == null) {
      throw StateError('请先绑定本地数据');
    }
    if (binding.boundUserId != userId) {
      throw const DatasetBindingConflict('other-account');
    }
    return (userId: userId, binding: binding);
  }

  Future<PersonalCloudStatus> status() async {
    final context = await _context();
    final data = await api.request(
      '/sync/status?datasetId=${context.binding.datasetId}',
    );
    return PersonalCloudStatus.fromJson(data);
  }

  Future<PersonalCloudStatus> bootstrap() async {
    final context = await _context();
    final data = await api.request(
      '/sync/bootstrap',
      method: 'POST',
      body: {'datasetId': context.binding.datasetId},
    );
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
      );
    });
