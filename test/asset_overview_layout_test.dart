import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/constants/app_assets.dart';

import 'support/reference_capture.dart';

void main() {
  for (final width in [320.0, 393.0, 430.0]) {
    testWidgets('asset overview fits $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createMemoryDatabase();
      await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      await loadReferenceFonts(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: AssetOverviewPageBoundary(child: child!),
            ),
          ),
        ),
      );
      router.go('/profile/assets');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(AppAssets.homeAssetScene),
          tester.element(find.byType(AssetOverviewPageBoundary)),
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width == 393) await _capture(tester, 'top');
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width == 393) await _capture(tester, 'lower');
    });
  }
}

Future<void> _capture(WidgetTester tester, String section) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(AssetOverviewPageBoundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'docs/qa/asset-overview-reference-2026-09-12/asset-overview-393-$section.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

class AssetOverviewPageBoundary extends StatelessWidget {
  const AssetOverviewPageBoundary({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: child);
}
