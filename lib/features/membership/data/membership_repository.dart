import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_seeder.dart';
import '../../../core/models/membership.dart';
import '../domain/commercial_service_contracts.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';

abstract interface class MembershipRepository {
  Stream<MembershipSnapshot> watchCurrent();
  Future<MembershipSnapshot> getCurrent();
}

class SnapshotMembershipFeatureAccessService
    implements MembershipFeatureAccessService {
  const SnapshotMembershipFeatureAccessService(this._membership);

  final MembershipRepository _membership;

  @override
  Future<MembershipFeatureAccess> accessFor(MembershipFeature feature) async {
    final snapshot = await _membership.getCurrent();
    final policy = snapshot.policyFor(feature);
    final allowed = policy.canUse(snapshot);
    return MembershipFeatureAccess(
      feature: feature,
      enabled: policy.enabled,
      allowed: allowed,
      requiresUpgrade: policy.enabled && policy.requiresMembership && !allowed,
      policy: policy,
    );
  }
}

class LocalOnlyMembershipRepository implements MembershipRepository {
  LocalOnlyMembershipRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  MembershipSnapshot _snapshot() {
    final now = _clock();
    return MembershipSnapshot(
      membership: Membership(
        userId: SeedIds.localUser,
        plan: MembershipPlan.free,
        status: MembershipStatus.active,
        updatedAt: now,
      ),
      entitlements: [
        EntitlementGrant(
          key: EntitlementKey.localBookkeeping,
          source: 'local_free_baseline',
          grantedAt: DateTime(2020),
        ),
        EntitlementGrant(
          key: EntitlementKey.dataExport,
          source: 'local_free_baseline',
          grantedAt: DateTime(2020),
        ),
      ],
      quotas: const [],
    );
  }

  @override
  Future<MembershipSnapshot> getCurrent() async => _snapshot();

  @override
  Stream<MembershipSnapshot> watchCurrent() => Stream.value(_snapshot());
}

class RemoteMembershipRepository implements MembershipRepository {
  const RemoteMembershipRepository(this.api, this.session);

  final SharedApi api;
  final SessionRepository session;

  @override
  Future<MembershipSnapshot> getCurrent() async {
    await session.initialize();
    if (session.user == null)
      return LocalOnlyMembershipRepository().getCurrent();
    final data = await api.request('/membership/current');
    return _snapshotFromJson(data);
  }

  @override
  Stream<MembershipSnapshot> watchCurrent() => Stream.fromFuture(getCurrent());

  MembershipSnapshot _snapshotFromJson(Map<String, dynamic> json) {
    final membership = Map<String, dynamic>.from(
      json['membership'] as Map? ?? const {},
    );
    final plan = switch (membership['plan']) {
      'family' => MembershipPlan.family,
      'pro' => MembershipPlan.pro,
      _ => MembershipPlan.free,
    };
    final status = MembershipStatus.values.firstWhere(
      (value) => value.name == membership['status'],
      orElse: () => MembershipStatus.active,
    );
    final updatedAt = _date(membership['updatedAt']);
    final subscriptionJson = json['subscription'];
    return MembershipSnapshot(
      membership: Membership(
        userId: membership['userId'] as String? ?? session.user!.id,
        plan: plan,
        status: status,
        updatedAt: updatedAt,
      ),
      subscription: subscriptionJson is Map
          ? Subscription(
              id: subscriptionJson['id'] as String,
              userId: subscriptionJson['userId'] as String,
              provider: subscriptionJson['provider'] == 'alipay'
                  ? SubscriptionProvider.alipay
                  : SubscriptionProvider.wechat,
              productId: subscriptionJson['productId'] as String,
              startedAt: _date(subscriptionJson['startedAt']),
              expiresAt: _date(subscriptionJson['expiresAt']),
              autoRenew: subscriptionJson['autoRenew'] as bool? ?? false,
              externalSubscriptionId:
                  subscriptionJson['externalSubscriptionId'] as String?,
            )
          : null,
      entitlements: (json['entitlements'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) => EntitlementGrant(
              key: _entitlement(value['key'] as String?),
              source: value['source'] as String? ?? 'server',
              grantedAt: _date(value['grantedAt']),
              expiresAt: value['expiresAt'] == null
                  ? null
                  : _date(value['expiresAt']),
            ),
          )
          .toList(),
      quotas: const [],
    );
  }

  DateTime _date(Object? value) {
    if (value is num)
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  EntitlementKey _entitlement(String? value) =>
      EntitlementKey.values.firstWhere(
        (key) => key.name == value,
        orElse: () => EntitlementKey.localBookkeeping,
      );
}

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  const baseUrl = String.fromEnvironment('SHARED_API_BASE_URL');
  if (baseUrl.isEmpty) return LocalOnlyMembershipRepository();
  return RemoteMembershipRepository(
    ref.watch(sharedApiProvider),
    ref.watch(sessionRepositoryProvider),
  );
});

final membershipProvider = StreamProvider<MembershipSnapshot>((ref) {
  return ref.watch(membershipRepositoryProvider).watchCurrent();
});

final membershipFeatureAccessServiceProvider =
    Provider<MembershipFeatureAccessService>((ref) {
      return SnapshotMembershipFeatureAccessService(
        ref.watch(membershipRepositoryProvider),
      );
    });
