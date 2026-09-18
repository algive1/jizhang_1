import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/constants/app_assets.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/home/presentation/home_asset_card.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/membership/presentation/membership_page.dart';

import 'support/reference_capture.dart';

void main() {
  testWidgets('captures membership page QA slices at 390dp', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await loadReferenceFonts(tester);

    final db = createMemoryDatabase();
    addTearDown(db.close);
    await DatabaseSeeder(db).seedIfNeeded(includeDemoData: true);
    final accounts = await DriftAccountRepository(db).getAll();
    final membership = await LocalOnlyMembershipRepository().getCurrent();

    const assetBoundary = ValueKey('asset-prototype-boundary');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: _referenceTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: assetBoundary,
                child: HomeAssetCard(
                  accounts: accounts,
                  amountHidden: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final imageContext = tester.element(find.byType(HomeAssetCard));
      await precacheImage(AssetImage(AppAssets.homeLeaves), imageContext);
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, assetBoundary, 'home-asset-card-390');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    const membershipBoundary = ValueKey('membership-prototype-boundary');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipProvider.overrideWithValue(AsyncData(membership)),
        ],
        child: MaterialApp(
          theme: _referenceTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: membershipBoundary,
              child: ColoredBox(
                color: const Color(0xFFFAF7EF),
                child: const MembershipPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final imageContext = tester.element(find.byType(MembershipPage));
      for (final asset in [
        'assets/images/membership/hero-bg.webp',
        'assets/images/membership/hero-mascot.png',
        'assets/images/membership/hero-leaves.png',
        'assets/images/membership/testimonial-user-female.webp',
        'assets/images/membership/testimonial-user-male.webp',
      ]) {
        await precacheImage(AssetImage(asset), imageContext);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, membershipBoundary, 'membership-page-top-390');
    final scrollable = find.byType(CustomScrollView);
    await tester.drag(scrollable, const Offset(0, -680));
    await tester.pumpAndSettle();
    await _capture(tester, membershipBoundary, 'membership-page-lower-390');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        membershipProvider.overrideWithValue(AsyncData(membership)),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    const shellBoundary = ValueKey('membership-shell-prototype-boundary');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: _referenceTheme(),
          routerConfig: router,
          builder: (context, child) =>
              RepaintBoundary(key: shellBoundary, child: child!),
        ),
      ),
    );
    router.go('/profile/membership');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, shellBoundary, 'membership-page-shell-390');
  });
}

ThemeData _referenceTheme() => AppTheme.light().copyWith(
  textTheme: AppTheme.light().textTheme.apply(
    fontFamily: 'Reference Latin',
    fontFamilyFallback: const ['PingFang SC'],
  ),
);

Future<void> _capture(WidgetTester tester, Key key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('docs/qa/member-open-2026-09-17/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
