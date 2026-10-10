import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/installation/installation_identity.dart';
import 'package:jizhang_app/features/app_runtime/data/app_runtime_repository.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';

class _Settings implements AppSettingsRepository {
  final values = <String, String>{};
  @override
  Future<String?> get(String key) async => values[key];
  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}

class _Api extends SharedApi {
  _Api({String base = 'http://127.0.0.1:8787'}) : super(baseUrl: base);
  Map<String, dynamic> response = {'documents': []};
  bool fail = false;
  int calls = 0;
  Completer<void>? delay;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? body,
    String? bearerToken,
  }) async {
    calls++;
    if (delay != null) await delay!.future;
    if (fail) throw const SharedApiException(503, '服务暂不可用');
    return response;
  }
}

Map<String, dynamic> _config(bool enabled, int version) => {
  'documents': [
    {
      'key': 'runtime',
      'version': version,
      'payload': {'cloudBackupEnabled': enabled},
    },
  ],
};

void main() {
  test('concurrent identity requests keep an existing rollout cohort and create one identity', () async {
    final settings = _Settings();
    final values = await Future.wait(
      List.generate(20, (_) => installationIdentity(settings)),
    );
    expect(values.toSet().length, 1);
    expect(await installationIdentity(settings), values.first);
  });
  test('validated config survives failure, supports rollback, and clears offline publications', () async {
    final api = _Api()..response = _config(false, 2), settings = _Settings();
    final repo = AppRuntimeRepository(api, settings);
    addTearDown(repo.dispose);
    addTearDown(api.close);
    expect(
      (await repo.refreshConfiguration()).allows(AppCapability.cloudBackup),
      isFalse,
    );
    api.fail = true;
    expect(
      (await repo.refreshConfiguration(force: true)).versions['runtime'],
      2,
    );
    final restarted = AppRuntimeRepository(api, settings);
    addTearDown(restarted.dispose);
    expect(
      (await restarted.currentConfiguration()).allows(
        AppCapability.cloudBackup,
      ),
      isFalse,
    );
    api.fail = false;
    api.response = _config(true, 1);
    expect(
      (await repo.refreshConfiguration(force: true)).versions['runtime'],
      1,
    );
    api.response = {'documents': []};
    expect((await repo.refreshConfiguration(force: true)).versions, isEmpty);
    final fresh = AppRuntimeRepository(api, settings);
    addTearDown(fresh.dispose);
    expect(
      (await fresh.currentConfiguration()).allows(AppCapability.cloudBackup),
      isTrue,
    );
  });
  test('invalid remote config does not replace a validated cache', () async {
    final api = _Api()..response = _config(false, 1), settings = _Settings();
    final repo = AppRuntimeRepository(api, settings);
    addTearDown(repo.dispose);
    addTearDown(api.close);
    await repo.refreshConfiguration();
    api.response = {
      'documents': [
        {
          'key': 'runtime',
          'version': 2,
          'payload': {'cloudBackupEnabled': 'true'},
        },
      ],
    };
    expect(
      (await repo.refreshConfiguration(force: true)).versions['runtime'],
      1,
    );
    await expectLater(
      repo.require(AppCapability.cloudBackup),
      throwsA(isA<AppCapabilityUnavailable>()),
    );
  });
  test(
    'expired cache and a different backend never reuse old feature switches',
    () async {
      var now = DateTime.utc(2026, 10, 10);
      final api = _Api()..response = _config(false, 1), settings = _Settings();
      final repo = AppRuntimeRepository(api, settings, clock: () => now);
      addTearDown(repo.dispose);
      addTearDown(api.close);
      await repo.refreshConfiguration();
      now = now.add(const Duration(days: 8));
      api.fail = true;
      expect(
        (await repo.currentConfiguration()).allows(AppCapability.cloudBackup),
        isTrue,
      );
      final otherApi = _Api(base: 'http://127.0.0.1:8788')..fail = true;
      addTearDown(otherApi.close);
      final other = AppRuntimeRepository(otherApi, settings, clock: () => now);
      addTearDown(other.dispose);
      expect((await other.currentConfiguration()).versions, isEmpty);
    },
  );
  test('configuration refresh shares one network request', () async {
    final api = _Api()..delay = Completer<void>(),
        repo = AppRuntimeRepository(api, _Settings());
    addTearDown(repo.dispose);
    addTearDown(api.close);
    final futures = List.generate(
      8,
      (_) => repo.refreshConfiguration(force: true),
    );
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, 1);
    api.delay!.complete();
    await Future.wait(futures);
  });
  test('published FAQ falls back offline, removal clears cache, and corrupt cache retries network', () async {
    final api = _Api()
          ..response = {
            'items': [
              {'id': 'faq', 'title': '帮助', 'body': '内容'},
            ],
          },
        settings = _Settings();
    final repo = AppRuntimeRepository(api, settings);
    addTearDown(repo.dispose);
    addTearDown(api.close);
    expect((await repo.operations('faq')).items.single.body, '内容');
    api.fail = true;
    final offline = await repo.operations('faq', force: true);
    expect(offline.cached, isTrue);
    expect(offline.unavailable, isTrue);
    api.fail = false;
    api.response = {'items': []};
    expect((await repo.operations('faq', force: true)).items, isEmpty);
    final key = settings.values.keys.singleWhere((key) => key.endsWith('.faq'));
    settings.values[key] = 'invalid-json';
    api.response = {
      'items': [
        {'id': 'new', 'title': '新帮助', 'body': '新内容'},
      ],
    };
    expect((await repo.operations('faq')).items.single.id, 'new');
    settings.values[key] = jsonEncode({
      'at': DateTime.now().toUtc().toIso8601String(),
      'response': {'items': 'broken'},
    });
    expect((await repo.operations('faq')).items.single.id, 'new');
  });
  test('local-only builds do not request a development backend', () async {
    final api = _Api(),
        repo = AppRuntimeRepository(api, _Settings(), enabled: false);
    addTearDown(repo.dispose);
    addTearDown(api.close);
    await repo.refreshConfiguration();
    await repo.operations('faq');
    await repo.require(AppCapability.voice);
    expect(api.calls, 0);
  });
}
