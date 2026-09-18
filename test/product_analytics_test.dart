import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/analytics/product_analytics.dart';
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

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    calls += 1;
    lastBody = body;
    return {'accepted': 1, 'duplicates': 0};
  }
}

void main() {
  test('analytics is opt-in and does not send before consent', () async {
    final api = _FakeApi();
    final settings = _FakeSettings();
    final analytics = ProductAnalytics(api, settings, autoFlush: false);

    expect(await analytics.isEnabled(), isFalse);
    await analytics.track('app_open');
    await analytics.flush();

    expect(api.calls, 0);
    expect(settings.values[ProductAnalytics.installationIdKey], isNull);
  });

  test('analytics normalizes screens and strips sensitive properties', () async {
    final api = _FakeApi();
    final settings = _FakeSettings();
    final analytics = ProductAnalytics(api, settings, autoFlush: false);

    await analytics.setEnabled(true);
    await analytics.track(
      'screen_view',
      screen: '/transactions/local-secret-id?from=search',
      properties: {
        'source': 'manual',
        'amount': 99.9,
        'merchant': 'private',
        'attachmentPath': '/private/file.jpg',
      },
    );
    await analytics.flush();

    expect(api.calls, 1);
    final body = (api.lastBody as Map).cast<String, dynamic>();
    expect(
      body['installationId'],
      matches(RegExp(r'^[a-f0-9]{32}$')),
    );
    final events = body['events'] as List;
    expect(events.length, 1);
    final event = (events.single as Map).cast<String, dynamic>();
    expect(event['name'], 'screen_view');
    expect(event['screen'], '/transactions/:transactionId');
    expect(event['properties'], {'source': 'manual'});
  });

  test('disabling analytics clears queued events', () async {
    final api = _FakeApi();
    final settings = _FakeSettings();
    final analytics = ProductAnalytics(api, settings, autoFlush: false);

    await analytics.setEnabled(true);
    await analytics.track(
      'bookkeeping_saved',
      properties: {'source': 'manual', 'count': 1},
    );
    await analytics.setEnabled(false);
    await analytics.flush();

    expect(api.calls, 0);
    expect(settings.values[ProductAnalytics.queueKey], '[]');
  });

  test('screen normalization removes other entity identifiers', () {
    expect(
      ProductAnalytics.normalizeScreen('/goals/goal-private'),
      '/goals/:goalId',
    );
    expect(
      ProductAnalytics.normalizeScreen('/profile/accounts/account-private'),
      '/profile/accounts/:accountId',
    );
    expect(
      ProductAnalytics.normalizeScreen('/profile/installments/plan-private'),
      '/profile/installments/:planId',
    );
  });
}
