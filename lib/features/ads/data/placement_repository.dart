import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/membership.dart';
import '../../../core/models/placement.dart';
import '../../membership/data/membership_repository.dart';
import '../domain/ad_provider.dart';
import '../domain/placement_policy.dart';

abstract interface class PlacementConfigRepository {
  Future<List<PlacementConfig>> getActiveConfigs();
}

class BundledPlacementConfigRepository implements PlacementConfigRepository {
  const BundledPlacementConfigRepository();

  @override
  Future<List<PlacementConfig>> getActiveConfigs() async => const [
    PlacementConfig(
      id: 'home-pro-value',
      surface: PlacementSurface.homePromo,
      format: AdFormat.native,
      contentType: PlacementContentType.membership,
      title: '让账本多一份安全感',
      description: 'Pro 将提供自动云备份、多设备同步与无广告体验。',
      actionLabel: '了解 Pro',
      actionRoute: '/profile/membership',
      enabled: true,
      targetAudience: PlacementAudience.free,
      dailyLimit: 3,
      priority: 100,
      provider: 'internal',
      contentCategory: AdContentCategory.productFeature,
    ),
    PlacementConfig(
      id: 'profile-family-value',
      surface: PlacementSurface.profilePromo,
      format: AdFormat.native,
      contentType: PlacementContentType.feature,
      title: '一起完成生活目标',
      description: 'Family 面向共同账本、家庭预算和共同目标。',
      actionLabel: '了解 Family',
      actionRoute: '/profile/family',
      enabled: true,
      targetAudience: PlacementAudience.free,
      dailyLimit: 2,
      priority: 90,
      provider: 'internal',
      contentCategory: AdContentCategory.productFeature,
    ),
    PlacementConfig(
      id: 'goal-family-value',
      surface: PlacementSurface.goalPromo,
      format: AdFormat.native,
      contentType: PlacementContentType.feature,
      title: '共同目标，进度彼此可见',
      description: '不做贡献排行榜，只关注两个人共同完成的节点。',
      actionLabel: '了解共享目标',
      actionRoute: '/profile/family',
      enabled: true,
      targetAudience: PlacementAudience.free,
      dailyLimit: 2,
      priority: 80,
      provider: 'internal',
      contentCategory: AdContentCategory.productFeature,
    ),
  ];
}

class AdEventRepository {
  const AdEventRepository(this._database);

  final AppDatabase _database;

  Future<void> record({
    required PlacementConfig placement,
    required AdEventType type,
    String? sessionId,
    String? metadataJson,
  }) async {
    final now = DateTime.now();
    await _database.adEventDao.insertEvent(
      AdEventEntriesCompanion.insert(
        id: 'ad-event-${now.microsecondsSinceEpoch}',
        placementId: placement.id,
        eventType: type.name,
        provider: placement.provider,
        sessionId: Value(sessionId),
        occurredAt: now,
        metadataJson: Value(metadataJson),
      ),
    );
  }

  Future<int> impressionsToday(String placementId, DateTime now) {
    return _database.adEventDao.countEvents(
      placementId: placementId,
      eventType: AdEventType.impression.name,
      since: DateTime(now.year, now.month, now.day),
    );
  }
}

class PlacementResolver {
  const PlacementResolver({
    required this.configs,
    required this.events,
    required this.policy,
  });

  final PlacementConfigRepository configs;
  final AdEventRepository events;
  final PlacementPolicy policy;

  Future<PlacementConfig?> resolve({
    required PlacementSurface surface,
    required MembershipSnapshot membership,
    required String route,
    required DateTime userCreatedAt,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final candidates =
        (await configs.getActiveConfigs())
            .where((item) => item.surface == surface)
            .toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));
    for (final placement in candidates) {
      final count = await events.impressionsToday(placement.id, clock);
      if (policy.isEligible(
        placement: placement,
        membership: membership,
        route: route,
        now: clock,
        userCreatedAt: userCreatedAt,
        deliveredToday: count,
      )) {
        return placement;
      }
    }
    return null;
  }
}

class RewardedAdService {
  const RewardedAdService(this.provider, this.events);

  final AdProvider provider;
  final AdEventRepository events;

  Future<RewardGrant?> requestExtraAiUse({
    required PlacementConfig placement,
    required bool userConfirmed,
    DateTime? now,
  }) async {
    if (!userConfirmed || placement.format != AdFormat.rewarded) return null;
    if (!await provider.isAvailable(AdFormat.rewarded)) return null;
    final result = await provider.showRewarded(placement);
    await events.record(
      placement: placement,
      type: result.completed ? AdEventType.complete : AdEventType.close,
    );
    if (!result.completed) return null;
    return RewardGrant(
      extraUses: 1,
      expiresAt: (now ?? DateTime.now()).add(const Duration(days: 1)),
    );
  }
}

final placementConfigRepositoryProvider = Provider<PlacementConfigRepository>(
  (ref) => const BundledPlacementConfigRepository(),
);

final adEventRepositoryProvider = Provider((ref) {
  return AdEventRepository(ref.watch(databaseProvider));
});

final placementResolverProvider = Provider((ref) {
  return PlacementResolver(
    configs: ref.watch(placementConfigRepositoryProvider),
    events: ref.watch(adEventRepositoryProvider),
    policy: const PlacementPolicy(),
  );
});

final adProviderProvider = Provider<AdProvider>(
  (ref) => const UnconfiguredAdProvider(),
);

final eligiblePlacementProvider =
    FutureProvider.family<PlacementConfig?, PlacementSurface>((
      ref,
      surface,
    ) async {
      final membership = await ref
          .watch(membershipRepositoryProvider)
          .getCurrent();
      return ref
          .watch(placementResolverProvider)
          .resolve(
            surface: surface,
            membership: membership,
            route: switch (surface) {
              PlacementSurface.homePromo => '/',
              PlacementSurface.profilePromo => '/profile',
              PlacementSurface.goalPromo => '/goals',
              PlacementSurface.splash => '/splash',
              PlacementSurface.aiReward => '/analysis/reward',
            },
            userCreatedAt: DateTime(2020),
          );
    });
