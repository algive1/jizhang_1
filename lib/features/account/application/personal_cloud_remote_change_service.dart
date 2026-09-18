import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../sharing/data/session_repository.dart';
import 'personal_cloud_bootstrap_service.dart';

enum PersonalCloudRemoteCheckResult {
  skipped,
  upToDate,
  updateAvailable,
  datasetConflict,
  failed,
}

class PersonalCloudRemoteChangeService {
  PersonalCloudRemoteChangeService(
    this.ref, {
    this.minimumInterval = const Duration(minutes: 15),
  });

  final Ref ref;
  final Duration minimumInterval;
  DateTime? _lastCheckedAt;

  Future<PersonalCloudRemoteCheckResult> checkIfDue({
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < minimumInterval) {
      return PersonalCloudRemoteCheckResult.skipped;
    }
    _lastCheckedAt = now;

    try {
      final session = ref.read(sessionRepositoryProvider);
      await session.initialize();
      final userId = session.userId;
      if (userId == null) return PersonalCloudRemoteCheckResult.skipped;

      await ref.read(databaseBootstrapProvider.future);
      final database = ref.read(databaseProvider);
      final binding = await database.getDeviceDataBinding();
      if (binding.boundUserId != userId || !binding.cloudSyncEnabled) {
        return PersonalCloudRemoteCheckResult.skipped;
      }

      final status = await ref.read(personalCloudBootstrapServiceProvider).status();
      if (!status.exists || !status.datasetMatches) {
        return PersonalCloudRemoteCheckResult.datasetConflict;
      }

      await database.setDatasetRemoteRevision(
        userId: userId,
        revision: status.hasSnapshot ? status.revision : 0,
      );

      if (status.hasSnapshot && status.revision > binding.lastCloudRevision) {
        return PersonalCloudRemoteCheckResult.updateAvailable;
      }
      return PersonalCloudRemoteCheckResult.upToDate;
    } on Object {
      return PersonalCloudRemoteCheckResult.failed;
    }
  }
}

final personalCloudRemoteChangeServiceProvider =
    Provider<PersonalCloudRemoteChangeService>(
      (ref) => PersonalCloudRemoteChangeService(ref),
    );
