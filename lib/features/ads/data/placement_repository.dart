import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/installation/installation_age_repository.dart';
import '../../../core/models/membership.dart';
import '../../../core/models/placement.dart';
import '../../membership/data/membership_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../domain/ad_provider.dart';
import '../domain/placement_policy.dart';

abstract interface class PlacementConfigRepository {
  Future<List<PlacementConfig>> getActiveConfigs();
}

class RemotePlacementConfigRepository implements PlacementConfigRepository {
  RemotePlacementConfigRepository({
    required this.api,
    required this.fallback,
    this.cacheTtl = const Duration(minutes: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SharedApi api;
  final PlacementConfigRepository fallback;
  final Duration cacheTtl;
  final DateTime Function() _clock;

  List<PlacementConfig>? _cachedRemote;
  DateTime? _cacheExpiresAt;

  @override
  Future<List<PlacementConfig>> getActiveConfigs() async {
    final now = _clock();
    final cached = _cachedRemote;
    final expiresAt = _cacheExpiresAt;
    if (cached != null && expiresAt != null && now.isBefore(expiresAt)) {
      return cached;
    }

    try {
      final response = await api.request('/ads/placements');
      final configured = response['configured'];
      final raw = response['placements'];
      if (configured != true) {
        return await fallback.getActiveConfigs();
      }
      if (raw is! List) {
        throw const FormatException('广告位配置格式无效');
      }

      final remote = raw
          .map((item) {
            if (item is! Map) {
              throw const FormatException('广告位配置项无效');
            }
            return _placementFromJson(item.cast<String, dynamic>());
          })
          .toList(growable: false);
      _cachedRemote = remote;
      _cacheExpiresAt = now.add(cacheTtl);
      return remote;
    } on Object {
      if (cached != null) return cached;
      return fallback.getActiveConfigs();
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

    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final enabled = json['enabled'];
    final dailyLimit = json['dailyLimit'];
    final priority = json['priority'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        description is! String ||
        enabled is! bool ||
        dailyLimit is! num ||
        priority is! num) {
      throw const FormatException('广告位基础配置无效');
    }

    final surface = enumValue(PlacementSurface.values, json['surface']);
    final format = enumValue(AdFormat.values, json['format']);
    if (!_formatMatchesSurface(surface, format)) {
      throw const FormatException('广告位展示类型与位置不匹配');
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

    final startAt = date(json['startAt']);
    final endAt = date(json['endAt']);
    if (startAt != null && endAt != null && !startAt.isBefore(endAt)) {
      throw const FormatException('广告位时间范围无效');
    }
    if (dailyLimit.toInt() <= 0 || dailyLimit.toInt() > 20) {
      throw const FormatException('广告位频控无效');
    }
    if (surface == PlacementSurface.splash && dailyLimit.toInt() != 1) {
      throw const FormatException('开屏广告每天最多一次');
    }

    return PlacementConfig(
      id: id,
      surface: surface,
      format: format,
      contentType: contentType,
      title: title,
      description: description,
      actionLabel: json['actionLabel'] as String?,
      actionRoute: actionRoute as String?,
      enabled: enabled,
      targetAudience: enumValue(
        PlacementAudience.values,
        json['targetAudience'],
      ),
      startAt: startAt,
      endAt: endAt,
      dailyLimit: dailyLimit.toInt(),
      priority: priority.toInt(),
      provider: provider,
      contentCategory: category,
    );
  }

  static bool _formatMatchesSurface(
    PlacementSurface surface,
    AdFormat format,
  ) {
    return switch (surface) {
      PlacementSurface.splash => format == AdFormat.splash,
      PlacementSurface.aiReward => format == AdFormat.rewarded,
      PlacementSurface.homePromo ||
      PlacementSurface.profilePromo ||
      PlacementSurface.goalPromo => format == AdFormat.native,
    };
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
        // Native ad networks require their official renderer so impressions,
        // clicks and disclosure remain owned by the SDK. Do not render their
        // payload as a normal app card.
        if (placement.format == AdFormat.native) continue;
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
  (ref) {
    const baseUrl = String.fromEnvironment('SHARED_API_BASE_URL');
    if (baseUrl.isEmpty) return const BundledPlacementConfigRepository();
    return RemotePlacementConfigRepository(
      api: ref.watch(sharedApiProvider),
      fallback: const BundledPlacementConfigRepository(),
    );
  },
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
