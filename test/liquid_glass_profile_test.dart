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

    final glassViewFinder = find.byKey(
      const ValueKey('profile-glass-view-false'),
    );
    final glassView = tester.widget<LiquidGlassView>(glassViewFinder);
    expect(glassView.useImpellerBackdrop, isFalse);
    expect(glassView.realTimeCapture, isFalse);
    expect(glassView.batch, isFalse);

    // Scrolling content keeps only the tiny brightness toggle as a real
    // refracting lens. Quick actions and recommendation tiles are static
    // translucent surfaces, so dragging the page no longer drives a field of
    // independent liquid-glass shaders.
    expect(
      find.descendant(
        of: glassViewFinder,
        matching: find.byType(LiquidGlassLens),
      ),
      findsOneWidget,
    );
    final quickGrid = find.byKey(
      const ValueKey('profile-quick-actions-grid'),
    );
    expect(
      find.descendant(
        of: quickGrid,
        matching: find.byType(LiquidGlassLens),
      ),
      findsNothing,
    );

    // The debug tuner is an overlay owned by the profile page only. Opening
    // and changing it must neither move nor cover the app-level navigation.
    final navBar = find.byKey(
      const ValueKey('app-bottom-navigation-bar'),
    );
    final navRect = tester.getRect(navBar);
    final debugButton = find.byKey(
      const ValueKey('profile-glass-debug-button'),
    );
    expect(debugButton, findsOneWidget);

    await tester.tap(debugButton);
    await tester.pumpAndSettle();
    final debugPanel = find.byKey(
      const ValueKey('profile-glass-debug-panel'),
    );
    expect(debugPanel, findsOneWidget);

    await tester.drag(find.byType(Slider).first, const Offset(36, 0));
    await tester.pump();
    expect(tester.getRect(navBar), navRect);

    await tester.tap(
      find.byKey(const ValueKey('profile-glass-debug-close')),
    );
    await tester.pumpAndSettle();
    expect(debugPanel, findsNothing);

    final topArea = find.byKey(const ValueKey('profile-top-area'));
    final identity = find.byKey(const ValueKey('profile-identity'));
    expect(tester.getSize(topArea).height, 116);
    expect(
      tester.getRect(identity).overlaps(tester.getRect(brightnessToggle)),
      isFalse,
    );
    expect(
      tester.getTopLeft(identity).dy,
      lessThan(tester.getBottomLeft(brightnessToggle).dy),
      reason: 'identity should use the freed left-side header space',
    );

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
