enum MembershipPlan { free, pro, family }

extension MembershipPlanLabel on MembershipPlan {
  String get label => switch (this) {
    MembershipPlan.free => 'Free',
    MembershipPlan.pro => 'Pro',
    MembershipPlan.family => 'Family',
  };
}

enum MembershipStatus { active, gracePeriod, expired, canceled }

enum EntitlementKey {
  localBookkeeping,
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

enum SubscriptionProvider { apple, wechat, manualGrant }

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
  });

  final Membership membership;
  final Subscription? subscription;
  final List<EntitlementGrant> entitlements;
  final List<UsageQuota> quotas;

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
