import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_seeder.dart';
import '../../../core/models/membership.dart';

abstract interface class MembershipRepository {
  Stream<MembershipSnapshot> watchCurrent();
  Future<MembershipSnapshot> getCurrent();
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

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return LocalOnlyMembershipRepository();
});

final membershipProvider = StreamProvider<MembershipSnapshot>((ref) {
  return ref.watch(membershipRepositoryProvider).watchCurrent();
});
