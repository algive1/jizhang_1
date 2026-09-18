import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';
import 'package:jizhang_app/features/update/application/app_update_service.dart';

class _FakeApi extends SharedApi {
  _FakeApi(this.response) : super(baseUrl: 'http://127.0.0.1:8787');

  Map<String, dynamic> response;
  String? lastPath;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    calls += 1;
    lastPath = path;
    return response;
  }
}

class _FakeSettings implements AppSettingsRepository {
  final values = <String, String>{};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}

class _FakePlatform implements AppUpdatePlatform {
  _FakePlatform(this.info);

  final AppBuildInfo info;
  String? openedUrl;

  @override
  Future<AppBuildInfo> appInfo() async => info;

  @override
  Future<bool> openStore(String url) async {
    openedUrl = url;
    return true;
  }
}

void main() {
  test('app update parses optional update and respects check interval', () async {
    final api = _FakeApi({
      'status': 'optional',
      'latestVersion': '1.2.0',
      'minimumVersion': '1.0.0',
      'storeUrl': 'https://example.com/app',
      'message': '更新说明',
    });
    final settings = _FakeSettings();
    final platform = _FakePlatform(
      const AppBuildInfo(platform: 'android', version: '1.1.0', build: 11),
    );
    final service = AppUpdateService(
      api,
      settings,
      platform,
      minimumCheckInterval: const Duration(days: 1),
    );

    final decision = await service.checkIfDue();
    expect(decision, isNotNull);
    expect(decision!.kind, AppUpdateKind.optional);
    expect(decision.currentVersion, '1.1.0');
    expect(decision.latestVersion, '1.2.0');
    expect(api.lastPath, contains('platform=android'));
    expect(api.lastPath, contains('version=1.1.0'));

    expect(await service.openStore(decision), isTrue);
    expect(platform.openedUrl, 'https://example.com/app');

    final skipped = await service.checkIfDue();
    expect(skipped, isNull);
    expect(api.calls, 1);
  });

  test('app update parses required update and supports forced recheck', () async {
    final api = _FakeApi({
      'status': 'required',
      'latestVersion': '2.0.0',
      'minimumVersion': '1.5.0',
      'storeUrl': 'https://example.com/app',
      'message': null,
    });
    final settings = _FakeSettings();
    final service = AppUpdateService(
      api,
      settings,
      _FakePlatform(
        const AppBuildInfo(platform: 'ios', version: '1.0.0', build: 1),
      ),
    );

    final first = await service.checkIfDue();
    expect(first!.kind, AppUpdateKind.required);
    final second = await service.checkIfDue(force: true);
    expect(second!.kind, AppUpdateKind.required);
    expect(api.calls, 2);
  });

  test('no update returns null after a successful check', () async {
    final api = _FakeApi({
      'status': 'none',
      'latestVersion': '1.0.0',
      'minimumVersion': '1.0.0',
      'storeUrl': null,
      'message': null,
    });
    final service = AppUpdateService(
      api,
      _FakeSettings(),
      _FakePlatform(
        const AppBuildInfo(platform: 'android', version: '1.0.0', build: 1),
      ),
    );

    expect(await service.checkIfDue(), isNull);
    expect(api.calls, 1);
  });
}
