enum MembershipPlan { free, pro, family }

extension MembershipPlanLabel on MembershipPlan {
  String get label => switch (this) {
    MembershipPlan.free => 'Free',
    MembershipPlan.pro => 'Pro',
    MembershipPlan.family => 'Family',
  };

  int get level => switch (this) {
    MembershipPlan.free => 0,
    MembershipPlan.pro => 1,
    MembershipPlan.family => 2,
  };
}

enum MembershipStatus { active, gracePeriod, expired, canceled }

enum EntitlementKey {
  localBookkeeping,
  automaticBookkeeping,
  dataExport,
  basicBackup,
  cloudSync,
  multiDevice,
  aiAnalysis,
  voiceAi,
  ocr,
  advancedReport,
  familyBook,
  adFree,
}

/// Business capabilities whose availability can be switched by the server.
///
/// Keep this list at the product level instead of coupling feature entry
/// points directly to a plan name. The remote membership response can later
/// provide a policy for each key without changing those entry points.
enum MembershipFeature {
  automaticBookkeeping,
  ledgerSync,
  assetReports,
  dataExport,
  sharedAssets,
}

extension MembershipFeatureInfo on MembershipFeature {
  String get apiKey => switch (this) {
    MembershipFeature.automaticBookkeeping => 'automatic_bookkeeping',
    MembershipFeature.ledgerSync => 'ledger_sync',
    MembershipFeature.assetReports => 'asset_reports',
    MembershipFeature.dataExport => 'data_export',
    MembershipFeature.sharedAssets => 'shared_assets',
  };

  String get label => switch (this) {
    MembershipFeature.automaticBookkeeping => '自动记账',
    MembershipFeature.ledgerSync => '账本同步',
    MembershipFeature.assetReports => '资产报表',
    MembershipFeature.dataExport => '数据导出',
    MembershipFeature.sharedAssets => '共享资产',
  };

  EntitlementKey get defaultEntitlement => switch (this) {
    MembershipFeature.automaticBookkeeping =>
      EntitlementKey.automaticBookkeeping,
    MembershipFeature.ledgerSync => EntitlementKey.cloudSync,
    MembershipFeature.assetReports => EntitlementKey.advancedReport,
    MembershipFeature.dataExport => EntitlementKey.dataExport,
    MembershipFeature.sharedAssets => EntitlementKey.familyBook,
  };
}

/// A server-controlled feature switch and the entitlement needed when it is
/// enabled for members. An absent policy is intentionally treated as a local
/// pass-through so unfinished backend rollout cannot break existing features.
class MembershipFeaturePolicy {
  const MembershipFeaturePolicy({
    required this.enabled,
    required this.requiresMembership,
    this.entitlement,
    this.minimumPlan,
    this.source = 'server',
  });

  const MembershipFeaturePolicy.passthrough()
    : enabled = true,
      requiresMembership = false,
      entitlement = null,
      minimumPlan = null,
      source = 'local_default';

  factory MembershipFeaturePolicy.membershipOnly(
    MembershipFeature feature, {
    bool enabled = true,
    String source = 'server',
  }) {
    return MembershipFeaturePolicy(
      enabled: enabled,
      requiresMembership: true,
      entitlement: feature.defaultEntitlement,
      source: source,
    );
  }

  final bool enabled;
  final bool requiresMembership;
  final EntitlementKey? entitlement;
  final MembershipPlan? minimumPlan;
  final String source;

  bool canUse(MembershipSnapshot snapshot, {DateTime? now}) {
    if (!enabled) return false;
    if (!requiresMembership) return true;
    if (!snapshot.membership.canUseGrantedEntitlements) return false;
    if (entitlement != null) {
      return snapshot.has(entitlement!, now: now);
    }
    final requiredPlan = minimumPlan;
    if (requiredPlan == null) return false;
    return snapshot.membership.plan.level >= requiredPlan.level;
  }
}

class Membership {
  const Membership({
    required this.userId,
    required this.plan,
    required this.status,
    required this.updatedAt,
  });

  final String userId;
  final MembershipPlan plan;
  final MembershipStatus status;
  final DateTime updatedAt;

  bool get canUseGrantedEntitlements =>
      status == MembershipStatus.active ||
      status == MembershipStatus.gracePeriod;
}

enum SubscriptionProvider { apple, wechat, alipay, manualGrant }

class Subscription {
  const Subscription({
    required this.id,
    required this.userId,
    required this.provider,
    required this.productId,
    required this.startedAt,
    required this.expiresAt,
    required this.autoRenew,
    this.externalSubscriptionId,
  });

  final String id;
  final String userId;
  final SubscriptionProvider provider;
  final String productId;
  final String? externalSubscriptionId;
  final DateTime startedAt;
  final DateTime expiresAt;
  final bool autoRenew;

  bool isActiveAt(DateTime now) =>
      !now.isBefore(startedAt) && now.isBefore(expiresAt);
}

class EntitlementGrant {
  const EntitlementGrant({
    required this.key,
    required this.source,
    required this.grantedAt,
    this.expiresAt,
  });

  final EntitlementKey key;
  final String source;
  final DateTime grantedAt;
  final DateTime? expiresAt;

  bool isActiveAt(DateTime now) =>
      !now.isBefore(grantedAt) &&
      (expiresAt == null || now.isBefore(expiresAt!));
}

class UsageQuota {
  const UsageQuota({
    required this.key,
    required this.limit,
    required this.used,
    required this.periodStart,
    required this.periodEnd,
  });

  final EntitlementKey key;
  final int limit;
  final int used;
  final DateTime periodStart;
  final DateTime periodEnd;

  int get remaining => (limit - used).clamp(0, limit);
}

class MembershipSnapshot {
  const MembershipSnapshot({
    required this.membership,
    required this.entitlements,
    required this.quotas,
    this.subscription,
    this.featurePolicies = const {},
  });

  final Membership membership;
  final Subscription? subscription;
  final List<EntitlementGrant> entitlements;
  final List<UsageQuota> quotas;
  final Map<MembershipFeature, MembershipFeaturePolicy> featurePolicies;

  MembershipFeaturePolicy policyFor(MembershipFeature feature) {
    return featurePolicies[feature] ??
        const MembershipFeaturePolicy.passthrough();
  }

  bool canUseFeature(MembershipFeature feature, {DateTime? now}) {
    return policyFor(feature).canUse(this, now: now);
  }

  bool has(EntitlementKey key, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    return membership.canUseGrantedEntitlements &&
        entitlements.any(
          (grant) => grant.key == key && grant.isActiveAt(clock),
        );
  }

  UsageQuota? quotaFor(EntitlementKey key) {
    return quotas.where((quota) => quota.key == key).firstOrNull;
  }
}
