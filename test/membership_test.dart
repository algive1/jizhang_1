import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/membership.dart';
import 'package:jizhang_app/core/config/testing_access.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
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

  test('current test phase grants every local entitlement', () async {
    expect(kAllFeaturesFreeForTesting, isTrue);
    final snapshot = await LocalOnlyMembershipRepository(clock: () => now)
        .getCurrent();

    for (final key in EntitlementKey.values) {
      expect(
        snapshot.has(key, now: now),
        isTrue,
        reason: '${key.name} should be free during product testing',
      );
    }
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

  test('unconfigured feature policies preserve existing local behavior', () {
    final snapshot = MembershipSnapshot(
      membership: Membership(
        userId: 'user',
        plan: MembershipPlan.free,
        status: MembershipStatus.active,
        updatedAt: now,
      ),
      entitlements: const [],
      quotas: const [],
    );

    expect(snapshot.canUseFeature(MembershipFeature.assetReports), isTrue);
    expect(
      snapshot.policyFor(MembershipFeature.assetReports).source,
      'local_default',
    );
  });

  test('feature access honors a server membership policy', () async {
    final snapshot = MembershipSnapshot(
      membership: Membership(
        userId: 'user',
        plan: MembershipPlan.free,
        status: MembershipStatus.active,
        updatedAt: now,
      ),
      entitlements: const [],
      quotas: const [],
      featurePolicies: {
        MembershipFeature.assetReports: MembershipFeaturePolicy.membershipOnly(
          MembershipFeature.assetReports,
        ),
      },
    );
    final service = SnapshotMembershipFeatureAccessService(
      _StaticMembershipRepository(snapshot),
    );

    final access = await service.accessFor(MembershipFeature.assetReports);

    expect(access.enabled, isTrue);
    expect(access.allowed, isFalse);
    expect(access.requiresUpgrade, isTrue);
    expect(access.policy.source, 'server');
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

class _StaticMembershipRepository implements MembershipRepository {
  const _StaticMembershipRepository(this.snapshot);

  final MembershipSnapshot snapshot;

  @override
  Future<MembershipSnapshot> getCurrent() async => snapshot;

  @override
  Stream<MembershipSnapshot> watchCurrent() => Stream.value(snapshot);
}
