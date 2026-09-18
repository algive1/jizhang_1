import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/push/application/push_registration_service.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';

class _FakeSettings implements AppSettingsRepository {
  final values = <String, String>{};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}

class _FakeApi extends SharedApi {
  _FakeApi() : super(baseUrl: 'http://127.0.0.1:8787');

  int calls = 0;
  Object? lastBody;
  bool fail = false;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    calls += 1;
    lastBody = body;
    if (fail) throw StateError('offline');
    return {'registered': true};
  }
}

class _FakeTokenProvider implements PushTokenProvider {
  _FakeTokenProvider(this.value);

  PushTokenRegistration? value;
  int calls = 0;

  @override
  Future<PushTokenRegistration?> currentToken() async {
    calls += 1;
    return value;
  }
}

void main() {
  test('push registration stays inactive for guest users', () async {
    final api = _FakeApi();
    final token = _FakeTokenProvider(
      const PushTokenRegistration(
        platform: 'android',
        provider: 'fcm',
        token: 'provider-token-1234567890',
      ),
    );
    final service = PushRegistrationService(
      api: api,
      settings: _FakeSettings(),
      tokenProvider: token,
      authenticatedUserId: () async => null,
      minimumAttemptInterval: Duration.zero,
    );

    expect(
      await service.registerIfAvailable(),
      PushRegistrationResult.guest,
    );
    expect(token.calls, 0);
    expect(api.calls, 0);
  });

  test('push registration is a no-op until a provider token exists', () async {
    final api = _FakeApi();
    final settings = _FakeSettings();
    final service = PushRegistrationService(
      api: api,
      settings: settings,
      tokenProvider: _FakeTokenProvider(null),
      authenticatedUserId: () async => 'user-a',
      minimumAttemptInterval: Duration.zero,
    );

    expect(
      await service.registerIfAvailable(),
      PushRegistrationResult.unavailable,
    );
    expect(api.calls, 0);
    expect(settings.values[PushRegistrationService.deviceIdKey], isNull);
  });

  test('push registration sends provider token with a stable random device id', () async {
    final api = _FakeApi();
    final settings = _FakeSettings();
    final token = _FakeTokenProvider(
      const PushTokenRegistration(
        platform: 'ios',
        provider: 'apns',
        token: 'apns-token-1234567890123456',
      ),
    );
    final service = PushRegistrationService(
      api: api,
      settings: settings,
      tokenProvider: token,
      authenticatedUserId: () async => 'user-a',
      minimumAttemptInterval: Duration.zero,
    );

    expect(
      await service.registerIfAvailable(),
      PushRegistrationResult.registered,
    );
    final first = (api.lastBody as Map).cast<String, dynamic>();
    expect(first['platform'], 'ios');
    expect(first['provider'], 'apns');
    expect(first['token'], 'apns-token-1234567890123456');
    expect(first['deviceId'], matches(RegExp(r'^[a-f0-9]{32}$')));

    expect(
      await service.registerIfAvailable(force: true),
      PushRegistrationResult.registered,
    );
    final second = (api.lastBody as Map).cast<String, dynamic>();
    expect(second['deviceId'], first['deviceId']);
    expect(
      settings.values.values,
      isNot(contains('apns-token-1234567890123456')),
    );
  });

  test('push registration failures never throw into app startup', () async {
    final api = _FakeApi()..fail = true;
    final service = PushRegistrationService(
      api: api,
      settings: _FakeSettings(),
      tokenProvider: _FakeTokenProvider(
        const PushTokenRegistration(
          platform: 'android',
          provider: 'fcm',
          token: 'provider-token-1234567890',
        ),
      ),
      authenticatedUserId: () async => 'user-a',
      minimumAttemptInterval: Duration.zero,
    );

    expect(
      await service.registerIfAvailable(),
      PushRegistrationResult.failed,
    );
  });
}
