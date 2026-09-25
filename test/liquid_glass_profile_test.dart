import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/insights/application/insight_feed_provider.dart';

void main() {
  testWidgets('liquid profile keeps header geometry and tracked glass stable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = createMemoryDatabase();
    await DatabaseSeeder(db).seedIfNeeded(includeDemoData: true);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionProvider.overrideWithValue(const AsyncData(null)),
        confirmedInsightFeedProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(BuiltInThemes.liquidGlass),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: child!,
          ),
        ),
      ),
    );

    router.go('/profile');
    await tester.pumpAndSettle();

    expect(find.text('你好，\n生活值得好好记录'), findsNothing);
    expect(find.text('让每一笔收支，都通向更好的自己'), findsNothing);

    final brightnessToggle = find.byKey(
      const ValueKey('profile-brightness-toggle'),
    );
    final lightMode = find.byKey(const ValueKey('profile-light-mode'));
    final darkMode = find.byKey(const ValueKey('profile-dark-mode'));
    final brightnessThumb = find.byKey(
      const ValueKey('profile-brightness-thumb'),
    );
    final sunIcon = find.descendant(
      of: lightMode,
      matching: find.byIcon(Icons.wb_sunny_rounded),
    );
    final moonIcon = find.descendant(
      of: darkMode,
      matching: find.byIcon(Icons.dark_mode_rounded),
    );

    expect(tester.getSize(brightnessToggle), const Size(92, 36));
    expect(
      (tester.getCenter(lightMode) - tester.getCenter(sunIcon)).distance,
      lessThan(.01),
    );
    expect(
      (tester.getCenter(darkMode) - tester.getCenter(moonIcon)).distance,
      lessThan(.01),
    );
    expect(
      (tester.getCenter(brightnessThumb) - tester.getCenter(lightMode))
          .distance,
      lessThan(.01),
    );

    // The page owns one outer batch and nested batches for glass-on-glass
    // action groups. Every visible panel/control is rendered by the tracked
    // lens engine rather than the old standalone BackdropFilter surface.
    expect(find.byType(LiquidGlassBatch), findsWidgets);
    expect(find.byType(LiquidGlassLens), findsWidgets);

    // Exercise both ordinary scrolling and the top edge. The glass renderer
    // must stay attached to the moving list without throwing during either.
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -320));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);

    await tester.drag(list, const Offset(0, 500));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
