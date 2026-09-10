import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/models/membership.dart';
import 'package:jizhang_app/core/models/placement.dart';
import 'package:jizhang_app/features/ads/data/placement_repository.dart';
import 'package:jizhang_app/features/ads/domain/ad_provider.dart';
import 'package:jizhang_app/features/ads/domain/placement_policy.dart';

void main() {
  const policy = PlacementPolicy();
  final now = DateTime(2026, 8, 31, 12);
  const native = PlacementConfig(
    id: 'native',
    surface: PlacementSurface.homePromo,
    format: AdFormat.native,
    contentType: PlacementContentType.thirdParty,
    title: '测试',
    description: '测试',
    enabled: true,
    targetAudience: PlacementAudience.free,
    dailyLimit: 2,
    priority: 1,
    provider: 'fake',
    contentCategory: AdContentCategory.financialEducation,
  );

  test('ad_free entitlement and protected routes suppress placements', () {
    expect(
      policy.isEligible(
        placement: native,
        membership: _membership(adFree: true, now: now),
        route: '/',
        now: now,
        userCreatedAt: DateTime(2020),
        deliveredToday: 0,
      ),
      isFalse,
    );
    expect(
      policy.isEligible(
        placement: native,
        membership: _membership(now: now),
        route: '/transactions/edit/1',
        now: now,
        userCreatedAt: DateTime(2020),
        deliveredToday: 0,
      ),
      isFalse,
    );
  });

  test('splash is blocked for first 24 hours and after daily limit', () {
    const splash = PlacementConfig(
      id: 'splash',
      surface: PlacementSurface.splash,
      format: AdFormat.splash,
      contentType: PlacementContentType.thirdParty,
      title: '测试',
      description: '测试',
      enabled: true,
      targetAudience: PlacementAudience.free,
      dailyLimit: 1,
      priority: 1,
      provider: 'fake',
      contentCategory: AdContentCategory.financialEducation,
    );
    expect(
      policy.isEligible(
        placement: splash,
        membership: _membership(now: now),
        route: '/splash',
        now: now,
        userCreatedAt: now.subtract(const Duration(hours: 23)),
        deliveredToday: 0,
      ),
      isFalse,
    );
    expect(
      policy.isEligible(
        placement: splash,
        membership: _membership(now: now),
        route: '/splash',
        now: now,
        userCreatedAt: DateTime(2020),
        deliveredToday: 1,
      ),
      isFalse,
    );
  });

  test('unsafe financial categories are always rejected', () {
    final unsafe = PlacementConfig(
      id: native.id,
      surface: native.surface,
      format: native.format,
      contentType: native.contentType,
      title: native.title,
      description: native.description,
      enabled: native.enabled,
      targetAudience: native.targetAudience,
      dailyLimit: native.dailyLimit,
      priority: native.priority,
      provider: native.provider,
      contentCategory: AdContentCategory.gambling,
    );
    expect(
      policy.isEligible(
        placement: unsafe,
        membership: _membership(now: now),
        route: '/',
        now: now,
        userCreatedAt: DateTime(2020),
        deliveredToday: 0,
      ),
      isFalse,
    );
  });

  test('impression, click and post-ad exit events persist', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    final events = AdEventRepository(database);
    await events.record(placement: native, type: AdEventType.impression);
    await events.record(placement: native, type: AdEventType.click);
    await events.record(placement: native, type: AdEventType.postAdExit);

    expect(await events.impressionsToday(native.id, DateTime.now()), 1);
    expect(await database.select(database.adEventEntries).get(), hasLength(3));
  });

  test(
    'reward requires explicit choice and completed provider result',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      final service = RewardedAdService(
        const _CompletedAdProvider(),
        AdEventRepository(database),
      );
      const placement = PlacementConfig(
        id: 'reward',
        surface: PlacementSurface.aiReward,
        format: AdFormat.rewarded,
        contentType: PlacementContentType.thirdParty,
        title: '额外一次',
        description: '主动观看后获得一次',
        enabled: true,
        targetAudience: PlacementAudience.free,
        dailyLimit: 1,
        priority: 1,
        provider: 'fake',
        contentCategory: AdContentCategory.financialEducation,
      );
      expect(
        await service.requestExtraAiUse(
          placement: placement,
          userConfirmed: false,
        ),
        isNull,
      );
      final reward = await service.requestExtraAiUse(
        placement: placement,
        userConfirmed: true,
        now: now,
      );
      expect(reward?.extraUses, 1);
      expect(reward?.expiresAt, now.add(const Duration(days: 1)));
    },
  );
}

MembershipSnapshot _membership({required DateTime now, bool adFree = false}) {
  return MembershipSnapshot(
    membership: Membership(
      userId: 'user',
      plan: adFree ? MembershipPlan.pro : MembershipPlan.free,
      status: MembershipStatus.active,
      updatedAt: now,
    ),
    entitlements: [
      if (adFree)
        EntitlementGrant(
          key: EntitlementKey.adFree,
          source: 'server',
          grantedAt: now.subtract(const Duration(days: 1)),
        ),
    ],
    quotas: const [],
  );
}

class _CompletedAdProvider implements AdProvider {
  const _CompletedAdProvider();

  @override
  String get id => 'fake';

  @override
  Future<bool> isAvailable(AdFormat format) async => true;

  @override
  Future<NativeAdPayload?> loadNative(PlacementConfig placement) async =>
      const NativeAdPayload(
        headline: '测试',
        body: '测试',
        callToAction: '查看',
        providerReference: 'native-ref',
      );

  @override
  Future<AdDeliveryResult> showRewarded(PlacementConfig placement) async =>
      const AdDeliveryResult(completed: true);

  @override
  Future<AdDeliveryResult> showSplash(PlacementConfig placement) async =>
      const AdDeliveryResult(completed: false);
}
