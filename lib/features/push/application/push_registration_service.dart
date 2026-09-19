import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/entity_id.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';

class PushTokenRegistration {
  const PushTokenRegistration({
    required this.platform,
    required this.provider,
    required this.token,
  });

  final String platform;
  final String provider;
  final String token;
}

abstract interface class PushTokenProvider {
  Future<PushTokenRegistration?> currentToken();
}

class MethodChannelPushTokenProvider implements PushTokenProvider {
  const MethodChannelPushTokenProvider();

  static const _channel = MethodChannel('jizhang/push');

  @override
  Future<PushTokenRegistration?> currentToken() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'currentToken',
      );
      if (raw == null) return null;
      final platform = raw['platform'];
      final provider = raw['provider'];
      final token = raw['token'];
      if (platform is! String ||
          provider is! String ||
          token is! String ||
          token.trim().length < 16) {
        return null;
      }
      return PushTokenRegistration(
        platform: platform,
        provider: provider,
        token: token.trim(),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

enum PushRegistrationResult {
  registered,
  guest,
  unavailable,
  throttled,
  failed,
}

class PushRegistrationService {
  PushRegistrationService({
    required this.api,
    required this.settings,
    required this.tokenProvider,
    required this.authenticatedUserId,
    this.minimumAttemptInterval = const Duration(minutes: 15),
  });

  static const deviceIdKey = 'push.device_id.v1';

  final SharedApi api;
  final AppSettingsRepository settings;
  final PushTokenProvider tokenProvider;
  final Future<String?> Function() authenticatedUserId;
  final Duration minimumAttemptInterval;

  DateTime? _lastAttemptAt;

  Future<PushRegistrationResult> registerIfAvailable({
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < minimumAttemptInterval) {
      return PushRegistrationResult.throttled;
    }
    _lastAttemptAt = now;

    try {
      final userId = await authenticatedUserId();
      if (userId == null) return PushRegistrationResult.guest;

      final pushToken = await tokenProvider.currentToken();
      if (pushToken == null) return PushRegistrationResult.unavailable;
      if (pushToken.platform != 'android' && pushToken.platform != 'ios') {
        return PushRegistrationResult.unavailable;
      }
      if (!const {'fcm', 'apns', 'vendor'}.contains(pushToken.provider)) {
        return PushRegistrationResult.unavailable;
      }

      final deviceId = await _deviceId();
      await api.request(
        '/push/devices',
        method: 'POST',
        body: {
          'deviceId': deviceId,
          'platform': pushToken.platform,
          'provider': pushToken.provider,
          'token': pushToken.token,
        },
      );
      return PushRegistrationResult.registered;
    } on Object {
      return PushRegistrationResult.failed;
    }
  }

  Future<bool> unregisterCurrentDevice() async {
    try {
      final userId = await authenticatedUserId();
      if (userId == null) return false;
      final deviceId = (await settings.get(deviceIdKey))?.trim();
      if (deviceId == null ||
          !RegExp(r'^[a-f0-9]{32}
    final existing = (await settings.get(deviceIdKey))?.trim();
    if (existing != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(existing)) {
      return existing;
    }
    final created = newEntityId();
    await settings.set(deviceIdKey, created);
    return created;
  }
}

final pushTokenProvider = Provider<PushTokenProvider>(
  (ref) => const MethodChannelPushTokenProvider(),
);

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((ref) {
  return PushRegistrationService(
    api: ref.watch(sharedApiProvider),
    settings: ref.watch(appSettingsRepositoryProvider),
    tokenProvider: ref.watch(pushTokenProvider),
    authenticatedUserId: () async {
      final session = ref.read(sessionRepositoryProvider);
      await session.initialize();
      return session.userId;
    },
  );
});
).hasMatch(deviceId)) {
        return true;
      }
      await api.request('/push/devices/$deviceId', method: 'DELETE');
      _lastAttemptAt = null;
      return true;
    } on Object {
      return false;
    }
  }

  Future<String> _deviceId() async {
    final existing = (await settings.get(deviceIdKey))?.trim();
    if (existing != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(existing)) {
      return existing;
    }
    final created = newEntityId();
    await settings.set(deviceIdKey, created);
    return created;
  }
}

final pushTokenProvider = Provider<PushTokenProvider>(
  (ref) => const MethodChannelPushTokenProvider(),
);

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((ref) {
  return PushRegistrationService(
    api: ref.watch(sharedApiProvider),
    settings: ref.watch(appSettingsRepositoryProvider),
    tokenProvider: ref.watch(pushTokenProvider),
    authenticatedUserId: () async {
      final session = ref.read(sessionRepositoryProvider);
      await session.initialize();
      return session.userId;
    },
  );
});
