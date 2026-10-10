import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/installation/installation_identity.dart';
import '../../account/application/cloud_backup_preferences.dart';
import '../../autobookkeeping/auto_bookkeeping_settings.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../../update/application/app_update_service.dart';
import '../data/app_runtime_repository.dart';

enum DeviceHeartbeatResult { sent, skipped, failed }

class DeviceHeartbeatState {
  const DeviceHeartbeatState({
    this.automaticBookkeeping,
    required this.autoBackup,
  });
  final bool? automaticBookkeeping;
  final bool autoBackup;
}

/// Authenticated operational metadata only. No amounts, account names, payment
/// text, brand/model, advertising IDs or product-analytics events are collected.
class DeviceHeartbeatService {
  DeviceHeartbeatService(
    this.api,
    this.session,
    this.settings,
    this.platform, {
    required this.readState,
    this.enabled = true,
    this.minimumInterval = const Duration(hours: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SharedApi api;
  final SessionRepository session;
  final AppSettingsRepository settings;
  final AppUpdatePlatform platform;
  final Future<DeviceHeartbeatState> Function(String userId, String platform)
  readState;
  final bool enabled;
  final Duration minimumInterval;
  final DateTime Function() _clock;
  bool _running = false;
  String? _attemptedUserId;
  DateTime? _attemptedAt;

  Future<DeviceHeartbeatResult> sendIfDue({bool force = false}) async {
    if (!enabled || _running) return DeviceHeartbeatResult.skipped;
    _running = true;
    try {
      await session.initialize();
      final userId = session.userId, token = api.sessionToken;
      if (userId == null || token == null) return DeviceHeartbeatResult.skipped;
      if (!force &&
          _attemptedUserId == userId &&
          _attemptedAt != null &&
          _clock().difference(_attemptedAt!) < const Duration(minutes: 1)) {
        return DeviceHeartbeatResult.skipped;
      }
      final key =
          'app.heartbeat.v1.${Uri.encodeComponent(api.baseUrl)}.$userId';
      final last = DateTime.tryParse(await settings.get(key) ?? '');
      if (!force &&
          last != null &&
          !last.isAfter(_clock()) &&
          _clock().difference(last) < minimumInterval)
        return DeviceHeartbeatResult.skipped;
      final info = await platform.appInfo();
      _attemptedUserId = userId;
      _attemptedAt = _clock();
      if (!{'android', 'ios'}.contains(info.platform) ||
          !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(info.version))
        return DeviceHeartbeatResult.skipped;
      final id = await installationIdentity(settings);
      api.installationId = id;
      final state = await readState(userId, info.platform);
      if (session.userId != userId || api.sessionToken != token)
        return DeviceHeartbeatResult.skipped;
      final response = await api.request(
        '/app/heartbeat',
        method: 'POST',
        bearerToken: token,
        body: {
          'installationId': id,
          'platform': info.platform,
          'appVersion': info.version,
          if (state.automaticBookkeeping != null)
            'autoEnabled': state.automaticBookkeeping,
          'backupEnabled': state.autoBackup,
        },
      );
      if (response['ok'] != true) return DeviceHeartbeatResult.failed;
      if (session.userId == userId && api.sessionToken == token) {
        await settings.set(key, _clock().toUtc().toIso8601String());
      }
      return DeviceHeartbeatResult.sent;
    } on Object {
      return DeviceHeartbeatResult.failed;
    } finally {
      _running = false;
    }
  }
}

final deviceHeartbeatServiceProvider = Provider<DeviceHeartbeatService>((ref) {
  final settings = ref.watch(appSettingsRepositoryProvider);
  return DeviceHeartbeatService(
    ref.watch(sharedApiProvider),
    ref.watch(sessionRepositoryProvider),
    settings,
    ref.watch(appUpdatePlatformProvider),
    enabled: const String.fromEnvironment('SHARED_API_BASE_URL').isNotEmpty,
    readState: (userId, platform) async {
      bool? autoEnabled;
      if (platform == 'android') {
        final status = await ref
            .read(autoBookkeepingSettingsProvider)
            .runtimeStatus();
        if (status.available) autoEnabled = status.enabled;
      }
      await ref.read(databaseBootstrapProvider.future);
      final binding = await ref.read(databaseProvider).getDeviceDataBinding();
      final config = await ref
          .read(appRuntimeRepositoryProvider)
          .currentConfiguration();
      final backup =
          binding.boundUserId == userId &&
          binding.cloudSyncEnabled &&
          config.allows(AppCapability.cloudBackup) &&
          await settings.get(cloudAutoBackupKey(userId, binding.datasetId)) ==
              'true';
      return DeviceHeartbeatState(
        automaticBookkeeping: autoEnabled,
        autoBackup: backup,
      );
    },
  );
});
