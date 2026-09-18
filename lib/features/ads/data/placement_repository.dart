import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/membership.dart';
import '../../../core/models/placement.dart';
import '../../membership/data/membership_repository.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../domain/ad_provider.dart';
import '../domain/placement_policy.dart';

abstract interface class PlacementConfigRepository {
  Future<List<PlacementConfig>> getActiveConfigs();
}

class InstallationAgeRepository {
  InstallationAgeRepository(
    this.settings, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const createdAtKey = 'app.installation_created_at.v1';

  final AppSettingsRepository settings;
  final DateTime Function() _clock;

  Future<DateTime> createdAt() async {
    final now = _clock();
    final raw = (await settings.get(createdAtKey))?.trim();
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed != null && !parsed.isAfter(now)) return parsed;

    await settings.set(createdAtKey, now.toIso8601String());
    return now;
  }
}

class RemotePlacementConfigRepository implements PlacementConfigRepository {
  const RemotePlacementConfigRepository({
    required this.api,
    required this.fallback,
  });

  final SharedApi api;
  final PlacementConfigRepository fallback;

  @override
  Future<List<PlacementConfig>> getActiveConfigs() async {
    final bundled = await fallback.getActiveConfigs();
    try {
      final response = await api.request('/ads/placements');
      final raw = response['placements'];
      if (raw is! List || raw.isEmpty) return bundled;

      final remote = raw
          .whereType<Map>()
          .map((item) => _placementFromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
      final merged = <String, PlacementConfig>{
        for (final placement in bundled) placement.id: placement,
        for (final placement in remote) placement.id: placement,
      };
      return merged.values.toList(growable: false);
    } on Object {
      return bundled;
    }
  }

  PlacementConfig _placementFromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw) {
      final name = raw?.toString();
      return values.firstWhere(
        (value) => value.name == name,
        orElse: () => throw const FormatException('广告位枚举配置无效'),
      );
    }

    DateTime? date(Object? raw) {
      if (raw == null) return null;
      if (raw is! num) throw const FormatException('广告位时间配置无效');
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt() * 1000);
    }

    final contentType = enumValue(
      PlacementContentType.values,
      json['contentType'],
    );
    final provider = json['provider'];
    final actionRoute = json['actionRoute'];
    if (provider is! String || provider.trim().isEmpty) {
      throw const FormatException('广告 provider 配置无效');
    }
    if (contentType == PlacementContentType.thirdParty) {
      if (provider == 'internal' || actionRoute != null) {
        throw const FormatException('第三方广告配置不安全');
      }
    } else if (provider != 'internal') {
      throw const FormatException('内部推广位 provider 配置无效');
    }

    final category = enumValue(
      AdContentCategory.values,
      json['contentCategory'],
    );
    if (category == AdContentCategory.highRiskLoan ||
        category == AdContentCategory.gambling ||
        category == AdContentCategory.untrustedInvestment) {
      throw const FormatException('广告内容类别不允许');
    }

    return PlacementConfig(
      id: json['id'] as String,
      surface: enumValue(PlacementSurface.values, json['surface']),
      format: enumValue(AdFormat.values, json['format']),
      contentType: contentType,
      title: json['title'] as String,
      description: json['description'] as String,
      actionLabel: json['actionLabel'] as String?,
      actionRoute: actionRoute as String?,
      enabled: json['enabled'] as bool,
      targetAudience: enumValue(
        PlacementAudience.values,
        json['targetAudience'],
      ),
      startAt: date(json['startAt']),
      endAt: date(json['endAt']),
      dailyLimit: (json['dailyLimit'] as num).toInt(),
      priority: (json['priority'] as num).toInt(),
      provider: provider,
      contentCategory: category,
    );
  }
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
    required this.provider,
  });

  final PlacementConfigRepository configs;
  final AdEventRepository events;
  final PlacementPolicy policy;
  final AdProvider provider;

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
      if (placement.contentType == PlacementContentType.thirdParty) {
        if (placement.provider != provider.id) continue;
        if (!await provider.isAvailable(placement.format)) continue;
      }
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
  (ref) => RemotePlacementConfigRepository(
    api: ref.watch(sharedApiProvider),
    fallback: const BundledPlacementConfigRepository(),
  ),
);

final installationAgeRepositoryProvider = Provider<InstallationAgeRepository>(
  (ref) => InstallationAgeRepository(
    ref.watch(appSettingsRepositoryProvider),
  ),
);

final adEventRepositoryProvider = Provider((ref) {
  return AdEventRepository(ref.watch(databaseProvider));
});

final placementResolverProvider = Provider((ref) {
  return PlacementResolver(
    configs: ref.watch(placementConfigRepositoryProvider),
    events: ref.watch(adEventRepositoryProvider),
    policy: const PlacementPolicy(),
    provider: ref.watch(adProviderProvider),
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
      final installedAt = await ref
          .watch(installationAgeRepositoryProvider)
          .createdAt();
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
            userCreatedAt: installedAt,
          );
    });
