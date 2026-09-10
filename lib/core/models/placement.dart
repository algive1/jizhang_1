import 'membership.dart';

enum AdFormat { splash, native, rewarded }

enum PlacementSurface { splash, homePromo, profilePromo, goalPromo, aiReward }

enum PlacementContentType { membership, feature, campaign, thirdParty }

enum PlacementAudience { all, free, pro, family }

enum AdContentCategory {
  productFeature,
  financialEducation,
  consumerCampaign,
  highRiskLoan,
  gambling,
  untrustedInvestment,
}

enum AdEventType { impression, click, complete, close, postAdExit }

class PlacementConfig {
  const PlacementConfig({
    required this.id,
    required this.surface,
    required this.format,
    required this.contentType,
    required this.title,
    required this.description,
    required this.enabled,
    required this.targetAudience,
    required this.dailyLimit,
    required this.priority,
    required this.provider,
    required this.contentCategory,
    this.actionLabel,
    this.actionRoute,
    this.startAt,
    this.endAt,
  });

  final String id;
  final PlacementSurface surface;
  final AdFormat format;
  final PlacementContentType contentType;
  final String title;
  final String description;
  final String? actionLabel;
  final String? actionRoute;
  final bool enabled;
  final PlacementAudience targetAudience;
  final DateTime? startAt;
  final DateTime? endAt;
  final int dailyLimit;
  final int priority;
  final String provider;
  final AdContentCategory contentCategory;

  bool targets(MembershipPlan plan) => switch (targetAudience) {
    PlacementAudience.all => true,
    PlacementAudience.free => plan == MembershipPlan.free,
    PlacementAudience.pro => plan == MembershipPlan.pro,
    PlacementAudience.family => plan == MembershipPlan.family,
  };
}

class AdDeliveryResult {
  const AdDeliveryResult({required this.completed, this.providerReference});

  final bool completed;
  final String? providerReference;
}

class NativeAdPayload {
  const NativeAdPayload({
    required this.headline,
    required this.body,
    required this.callToAction,
    required this.providerReference,
  });

  final String headline;
  final String body;
  final String callToAction;
  final String providerReference;
}

class RewardGrant {
  const RewardGrant({required this.extraUses, required this.expiresAt});

  final int extraUses;
  final DateTime expiresAt;
}
