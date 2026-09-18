import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/installation/installation_age_repository.dart';
import 'package:jizhang_app/core/models/membership.dart';
import 'package:jizhang_app/core/models/placement.dart';
import 'package:jizhang_app/features/ads/data/placement_repository.dart';
import 'package:jizhang_app/features/ads/domain/ad_provider.dart';
import 'package:jizhang_app/features/ads/domain/placement_policy.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';

class _FakeApi extends SharedApi {
  _FakeApi(this.response) : super(baseUrl: 'http://127.0.0.1:8787');

  Map<String, dynamic> response;
  int calls = 0;
  bool fail = false;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    calls += 1;
    if (fail) throw StateError('offline');
    return response;
  }
}

class _StaticConfigRepository implements PlacementConfigRepository {
  const _StaticConfigRepository(this.items);

  final List<PlacementConfig> items;

  @override
  Future<List<PlacementConfig>> getActiveConfigs() async => items;
}

class _AvailableProvider implements AdProvider {
  const _AvailableProvider({this.providerId = 'vendor'});

  final String providerId;

  @override
  String get id => providerId;

  @override
  Future<bool> isAvailable(AdFormat format) async => true;

  @override
  Future<NativeAdPayload?> loadNative(PlacementConfig placement) async => null;

  @override
  Future<AdDeliveryResult> showRewarded(PlacementConfig placement) async =>
      const AdDeliveryResult(completed: true, providerReference: 'reward-ref');

  @override
  Future<AdDeliveryResult> showSplash(PlacementConfig placement) async =>
      const AdDeliveryResult(completed: true, providerReference: 'splash-ref');
}

MembershipSnapshot _freeMembership(DateTime now) {
  return MembershipSnapshot(
    membership: Membership(
      userId: 'user',
      plan: MembershipPlan.free,
      status: MembershipStatus.active,
      updatedAt: now,
    ),
    entitlements: const [],
    quotas: const [],
  );
}

PlacementConfig _thirdParty({
  required String id,
  required PlacementSurface surface,
  required AdFormat format,
  String provider = 'vendor',
}) {
  return PlacementConfig(
    id: id,
    surface: surface,
    format: format,
    contentType: PlacementContentType.thirdParty,
    title: '测试广告',
    description: '测试',
    enabled: true,
    targetAudience: PlacementAudience.free,
    dailyLimit: 1,
    priority: 100,
    provider: provider,
    contentCategory: AdContentCategory.consumerCampaign,
  );
}

void main() {
  test('installation age stays device-local and is not shared by a restored database', () async {
    final firstDirectory = await Directory.systemTemp.createTemp(
      'haohao-install-a-',
    );
    final secondDirectory = await Directory.systemTemp.createTemp(
      'haohao-install-b-',
    );
    addTearDown(() => firstDirectory.delete(recursive: true));
    addTearDown(() => secondDirectory.delete(recursive: true));

    final firstLaunch = DateTime.utc(2026, 9, 19, 1);
    final later = firstLaunch.add(const Duration(days: 10));

    final firstDevice = InstallationAgeRepository(
      applicationSupportDirectory: () async => firstDirectory,
      clock: () => firstLaunch,
    );
    expect(await firstDevice.createdAt(), firstLaunch);

    final sameDevice = InstallationAgeRepository(
      applicationSupportDirectory: () async => firstDirectory,
      clock: () => later,
    );
    expect(await sameDevice.createdAt(), firstLaunch);

    final restoredOnNewDevice = InstallationAgeRepository(
      applicationSupportDirectory: () async => secondDirectory,
      clock: () => later,
    );
    expect(await restoredOnNewDevice.createdAt(), later);
  });

  test('remote placements are authoritative, cached and allow an empty config', () async {
    var now = DateTime.utc(2026, 9, 19, 1);
    final api = _FakeApi({
      'configured': true,
      'configVersion': 'v1',
      'placements': [
        {
          'id': 'remote-goal',
          'surface': 'goalPromo',
          'format': 'native',
          'contentType': 'feature',
          'title': '远程活动',
          'description': '远程配置',
          'actionLabel': '查看',
          'actionRoute': '/profile/family',
          'enabled': true,
          'targetAudience': 'free',
          'dailyLimit': 2,
          'priority': 10,
          'provider': 'internal',
          'contentCategory': 'productFeature',
        },
      ],
    });
    final repository = RemotePlacementConfigRepository(
      api: api,
      fallback: const BundledPlacementConfigRepository(),
      cacheTtl: const Duration(minutes: 15),
      clock: () => now,
    );

    final first = await repository.getActiveConfigs();
    expect(first.map((item) => item.id), ['remote-goal']);
    expect(api.calls, 1);

    api.response = {
      'configured': true,
      'configVersion': 'v2',
      'placements': [],
    };
    final cached = await repository.getActiveConfigs();
    expect(cached.map((item) => item.id), ['remote-goal']);
    expect(api.calls, 1);

    now = now.add(const Duration(minutes: 16));
    final empty = await repository.getActiveConfigs();
    expect(empty, isEmpty);
    expect(api.calls, 2);
  });

  test('remote placement failure uses last good config, then bundled fallback', () async {
    var now = DateTime.utc(2026, 9, 19, 1);
    final api = _FakeApi({
      'configured': true,
      'placements': [
        {
          'id': 'remote-goal',
          'surface': 'goalPromo',
          'format': 'native',
          'contentType': 'feature',
          'title': '远程活动',
          'description': '远程配置',
          'enabled': true,
          'targetAudience': 'free',
          'dailyLimit': 1,
          'priority': 1,
          'provider': 'internal',
          'contentCategory': 'productFeature',
        },
      ],
    });
    final repository = RemotePlacementConfigRepository(
      api: api,
      fallback: const BundledPlacementConfigRepository(),
      cacheTtl: const Duration(minutes: 1),
      clock: () => now,
    );

    expect(
      (await repository.getActiveConfigs()).single.id,
      'remote-goal',
    );
    now = now.add(const Duration(minutes: 2));
    api.fail = true;
    expect(
      (await repository.getActiveConfigs()).single.id,
      'remote-goal',
    );

    final coldApi = _FakeApi(const {})..fail = true;
    final cold = RemotePlacementConfigRepository(
      api: coldApi,
      fallback: const BundledPlacementConfigRepository(),
      clock: () => now,
    );
    final fallback = await cold.getActiveConfigs();
    expect(fallback.any((item) => item.id == 'home-pro-value'), isTrue);
  });

  test('invalid remote placement fails closed to bundled config', () async {
    final api = _FakeApi({
      'configured': true,
      'placements': [
        {
          'id': 'wrong-format',
          'surface': 'splash',
          'format': 'native',
          'contentType': 'thirdParty',
          'title': '错误',
          'description': '',
          'enabled': true,
          'targetAudience': 'free',
          'dailyLimit': 1,
          'priority': 1,
          'provider': 'vendor',
          'contentCategory': 'consumerCampaign',
        },
      ],
    });
    final repository = RemotePlacementConfigRepository(
      api: api,
      fallback: const BundledPlacementConfigRepository(),
    );

    final result = await repository.getActiveConfigs();
    expect(result.any((item) => item.id == 'wrong-format'), isFalse);
    expect(result.any((item) => item.id == 'home-pro-value'), isTrue);
  });

  test('third-party native is blocked until an official SDK renderer exists', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 9, 19, 12);
    final resolver = PlacementResolver(
      configs: _StaticConfigRepository([
        _thirdParty(
          id: 'native-network',
          surface: PlacementSurface.goalPromo,
          format: AdFormat.native,
        ),
      ]),
      events: AdEventRepository(database),
      policy: const PlacementPolicy(),
      provider: const _AvailableProvider(),
    );

    final placement = await resolver.resolve(
      surface: PlacementSurface.goalPromo,
      membership: _freeMembership(now),
      route: '/goals',
      userCreatedAt: now.subtract(const Duration(days: 3)),
      now: now,
    );
    expect(placement, isNull);
  });

  test('third-party splash still requires matching available provider and 24h age', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 9, 19, 12);
    final splash = _thirdParty(
      id: 'splash-network',
      surface: PlacementSurface.splash,
      format: AdFormat.splash,
    );

    final matched = PlacementResolver(
      configs: _StaticConfigRepository([splash]),
      events: AdEventRepository(database),
      policy: const PlacementPolicy(),
      provider: const _AvailableProvider(),
    );
    expect(
      await matched.resolve(
        surface: PlacementSurface.splash,
        membership: _freeMembership(now),
        route: '/splash',
        userCreatedAt: now.subtract(const Duration(hours: 25)),
        now: now,
      ),
      isNotNull,
    );
    expect(
      await matched.resolve(
        surface: PlacementSurface.splash,
        membership: _freeMembership(now),
        route: '/splash',
        userCreatedAt: now.subtract(const Duration(hours: 23)),
        now: now,
      ),
      isNull,
    );

    final mismatched = PlacementResolver(
      configs: _StaticConfigRepository([splash]),
      events: AdEventRepository(database),
      policy: const PlacementPolicy(),
      provider: const _AvailableProvider(providerId: 'other'),
    );
    expect(
      await mismatched.resolve(
        surface: PlacementSurface.splash,
        membership: _freeMembership(now),
        route: '/splash',
        userCreatedAt: now.subtract(const Duration(days: 2)),
        now: now,
      ),
      isNull,
    );
  });
}
