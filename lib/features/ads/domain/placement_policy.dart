import '../../../core/models/membership.dart';
import '../../../core/models/placement.dart';

class PlacementPolicy {
  const PlacementPolicy();

  static const _protectedRouteFragments = [
    'bookkeeping',
    'transactions/edit',
    'voice/confirm',
    'goals/complete',
    'data/restore',
    'payment',
    'login',
    'security',
  ];

  bool isProtectedRoute(String route) {
    return _protectedRouteFragments.any(route.contains);
  }

  bool isContentAllowed(AdContentCategory category) => switch (category) {
    AdContentCategory.highRiskLoan ||
    AdContentCategory.gambling ||
    AdContentCategory.untrustedInvestment => false,
    _ => true,
  };

  bool isEligible({
    required PlacementConfig placement,
    required MembershipSnapshot membership,
    required String route,
    required DateTime now,
    required DateTime userCreatedAt,
    required int deliveredToday,
  }) {
    if (!placement.enabled || isProtectedRoute(route)) return false;
    if (membership.has(EntitlementKey.adFree, now: now)) return false;
    if (placement.contentType == PlacementContentType.thirdParty &&
        membership.membership.plan != MembershipPlan.free) {
      return false;
    }
    if (!placement.targets(membership.membership.plan)) return false;
    if (!isContentAllowed(placement.contentCategory)) return false;
    if (placement.startAt != null && now.isBefore(placement.startAt!)) {
      return false;
    }
    if (placement.endAt != null && !now.isBefore(placement.endAt!)) {
      return false;
    }
    if (placement.dailyLimit <= 0 || deliveredToday >= placement.dailyLimit) {
      return false;
    }
    if (placement.format == AdFormat.splash) {
      if (deliveredToday >= 1) return false;
      if (now.difference(userCreatedAt) < const Duration(hours: 24)) {
        return false;
      }
    }
    return true;
  }
}
