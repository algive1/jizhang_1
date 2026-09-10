import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/membership.dart';
import 'package:jizhang_app/features/membership/domain/commercial_service_contracts.dart';

void main() {
  final now = DateTime(2026, 8, 31);

  test('entitlements are evaluated from active grants, not plan labels', () {
    final snapshot = MembershipSnapshot(
      membership: Membership(
        userId: 'user',
        plan: MembershipPlan.pro,
        status: MembershipStatus.active,
        updatedAt: now,
      ),
      entitlements: [
        EntitlementGrant(
          key: EntitlementKey.cloudSync,
          source: 'server_subscription',
          grantedAt: now.subtract(const Duration(days: 1)),
          expiresAt: now.add(const Duration(days: 1)),
        ),
      ],
      quotas: const [],
    );

    expect(snapshot.has(EntitlementKey.cloudSync, now: now), isTrue);
    expect(snapshot.has(EntitlementKey.adFree, now: now), isFalse);
  });

  test('expired membership stops new Pro services without deleting grants', () {
    final grant = EntitlementGrant(
      key: EntitlementKey.multiDevice,
      source: 'server_subscription',
      grantedAt: now.subtract(const Duration(days: 30)),
    );
    final snapshot = MembershipSnapshot(
      membership: Membership(
        userId: 'user',
        plan: MembershipPlan.pro,
        status: MembershipStatus.expired,
        updatedAt: now,
      ),
      entitlements: [grant],
      quotas: const [],
    );

    expect(snapshot.entitlements, contains(grant));
    expect(snapshot.has(EntitlementKey.multiDevice, now: now), isFalse);
  });

  test('usage quota never reports a negative remaining count', () {
    final quota = UsageQuota(
      key: EntitlementKey.voiceAi,
      limit: 3,
      used: 5,
      periodStart: DateTime(2026, 8),
      periodEnd: DateTime(2026, 9),
    );
    expect(quota.remaining, 0);
  });

  test(
    'unconfigured cloud sync reports unavailable instead of success',
    () async {
      final state = await const UnconfiguredCloudSyncService().synchronize();
      expect(state.availability, CloudSyncAvailability.notConfigured);
      expect(state.lastSuccessfulSyncAt, isNull);
    },
  );
}
