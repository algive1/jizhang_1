import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/membership.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/membership/presentation/membership_upgrade_prompt.dart';

void main() {
  testWidgets('gated feature opens the shared membership upgrade prompt', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 12);
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipRepositoryProvider.overrideWithValue(
            _StaticMembershipRepository(snapshot),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => FilledButton(
                onPressed: () => ensureMembershipFeatureAvailable(
                  context,
                  ref,
                  MembershipFeature.assetReports,
                ),
                child: const Text('检查权限'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('检查权限'));
    await tester.pumpAndSettle();

    expect(find.text('资产报表需要会员'), findsOneWidget);
    expect(find.text('快捷开通会员'), findsOneWidget);
    Navigator.of(tester.element(find.text('资产报表需要会员'))).pop();
    await tester.pumpAndSettle();
  });
}

class _StaticMembershipRepository implements MembershipRepository {
  const _StaticMembershipRepository(this.snapshot);

  final MembershipSnapshot snapshot;

  @override
  Future<MembershipSnapshot> getCurrent() async => snapshot;

  @override
  Stream<MembershipSnapshot> watchCurrent() => Stream.value(snapshot);
}
