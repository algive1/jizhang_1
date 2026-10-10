import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/membership.dart';
import 'package:jizhang_app/features/analysis/application/analysis_report_export_service.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_settings.dart';
import 'package:jizhang_app/features/membership/application/membership_feature_guard.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';

class _Member implements MembershipRepository {
  @override
  Future<MembershipSnapshot> getCurrent() async => MembershipSnapshot(
    membership: Membership(
      userId: 'member',
      plan: MembershipPlan.free,
      status: MembershipStatus.active,
      updatedAt: DateTime.now(),
    ),
    entitlements: const [],
    quotas: const [],
    featurePolicies: {
      for (final feature in MembershipFeature.values)
        feature: MembershipFeaturePolicy.membershipOnly(feature),
    },
  );
  @override
  Stream<MembershipSnapshot> watchCurrent() => Stream.fromFuture(getCurrent());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'denied activation never starts native service, but disabling always works',
    () async {
      const channel = MethodChannel('jizhang/autobookkeeping');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = SnapshotMembershipFeatureAccessService(_Member());
      final bridge = MethodChannelAutoBookkeepingSettings(
        beforeEnable: () => requireMembershipFeature(
          service,
          MembershipFeature.automaticBookkeeping,
        ),
      );
      await expectLater(
        bridge.setEnabled(true),
        throwsA(isA<MembershipFeatureDenied>()),
      );
      expect(calls, isEmpty);
      await bridge.setEnabled(false);
      expect(calls.single.method, 'setEnabled');
      expect(calls.single.arguments, isFalse);
    },
  );
  test(
    'report export checks access before rendering or touching a share platform',
    () async {
      final access = SnapshotMembershipFeatureAccessService(_Member());
      final service = AnalysisReportExportService(
        beforeExport: () =>
            requireMembershipFeature(access, MembershipFeature.assetReports),
      );
      await expectLater(
        service.capturePng(GlobalKey()),
        throwsA(isA<MembershipFeatureDenied>()),
      );
    },
  );
}
