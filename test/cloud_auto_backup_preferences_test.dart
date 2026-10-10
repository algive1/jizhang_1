import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/features/account/application/cloud_backup_preferences.dart';
import 'package:jizhang_app/features/account/application/personal_cloud_auto_backup_service.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';

class TestSession extends SessionRepository {
  TestSession(super.api, super.database);
  @override
  Future<void> initialize() async {}
  @override
  String? get userId => 'owner';
}

void main() {
  test('prior manual backups do not opt in; another account cannot enable this dataset', () async {
    final db = createMemoryDatabase();
    final api = SharedApi();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        databaseBootstrapProvider.overrideWith((ref) async {}),
        sessionRepositoryProvider.overrideWithValue(TestSession(api, db)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      api.close();
      await db.close();
    });
    final binding = await db.bindDatasetToUser('owner');
    await db.setDatasetCloudSyncEnabled(userId: 'owner', enabled: true);
    await db.setDatasetCloudCheckpoint(
      userId: 'owner',
      revision: 1,
      at: DateTime.now().subtract(const Duration(days: 2)),
    );
    await db.setDatasetRemoteRevision(userId: 'owner', revision: 2);
    final service = container.read(personalCloudAutoBackupServiceProvider);
    final settings = container.read(appSettingsRepositoryProvider);
    expect(await service.backupIfDue(), PersonalCloudAutoBackupResult.skipped);
    await settings.set(
      cloudAutoBackupKey('someone-else', binding.datasetId),
      'true',
    );
    expect(await service.backupIfDue(), PersonalCloudAutoBackupResult.skipped);
    await settings.set(cloudAutoBackupKey('owner', binding.datasetId), 'true');
    expect(await service.backupIfDue(), PersonalCloudAutoBackupResult.conflict);
    await settings.set(cloudAutoBackupKey('owner', binding.datasetId), 'false');
    expect(await service.backupIfDue(), PersonalCloudAutoBackupResult.skipped);
  });
}
