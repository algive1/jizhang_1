import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_catalog.dart';
import 'package:jizhang_app/features/membership/presentation/membership_page.dart';

void main() {
  for (final size in [const Size(320, 700), const Size(393, 844)]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('membership page stays usable at $size and scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final membership = await LocalOnlyMembershipRepository().getCurrent();
        final catalog = await ConfiguredMembershipCatalogRepository().load();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              membershipProvider.overrideWithValue(AsyncData(membership)),
              membershipCatalogProvider.overrideWithValue(AsyncData(catalog)),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: MembershipPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('会员中心'), findsOneWidget);
        expect(find.text('选择会员套餐'), findsOneWidget);
        expect(find.text('会员专享权益'), findsOneWidget);
        final quarterlyPlan = find.byKey(
          const ValueKey('membership-plan-quarterly'),
          skipOffstage: false,
        );
        expect(quarterlyPlan, findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(quarterlyPlan);
        await tester.pumpAndSettle();
        await tester.tap(quarterlyPlan);
        await tester.pumpAndSettle();
        expect(find.text('季度会员'), findsOneWidget);
        expect(find.text('会员开通后可以在哪些设备使用？'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
