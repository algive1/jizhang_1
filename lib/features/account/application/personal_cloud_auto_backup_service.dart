import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../sharing/data/session_repository.dart';
import 'personal_cloud_backup_service.dart';

enum PersonalCloudAutoBackupResult {
  skipped,
  backedUp,
  conflict,
  failed,
}

class PersonalCloudAutoBackupService {
  const PersonalCloudAutoBackupService(
    this.ref, {
    this.minimumInterval = const Duration(hours: 6),
  });

  final Ref ref;
  final Duration minimumInterval;

  Future<PersonalCloudAutoBackupResult> backupIfDue() async {
    try {
      final session = ref.read(sessionRepositoryProvider);
      await session.initialize();
      final userId = session.userId;
      if (userId == null) return PersonalCloudAutoBackupResult.skipped;

      await ref.read(databaseBootstrapProvider.future);
      final database = ref.read(databaseProvider);
      final binding = await database.getDeviceDataBinding();
      if (binding.boundUserId != userId ||
          !binding.cloudSyncEnabled ||
          binding.lastSyncAt == null) {
        return PersonalCloudAutoBackupResult.skipped;
      }

      final elapsed = DateTime.now().difference(binding.lastSyncAt!);
      if (elapsed < minimumInterval) {
        return PersonalCloudAutoBackupResult.skipped;
      }

      await ref.read(personalCloudBackupServiceProvider).uploadSnapshot();
      return PersonalCloudAutoBackupResult.backedUp;
    } on PersonalCloudRevisionConflict {
      return PersonalCloudAutoBackupResult.conflict;
    } on Object {
      return PersonalCloudAutoBackupResult.failed;
    }
  }
}

final personalCloudAutoBackupServiceProvider =
    Provider<PersonalCloudAutoBackupService>(
      (ref) => PersonalCloudAutoBackupService(ref),
    );
