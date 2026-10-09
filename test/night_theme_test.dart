import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/widgets/app_bottom_navigation.dart';
import 'package:jizhang_app/core/widgets/app_card.dart';
import 'package:jizhang_app/core/widgets/app_glass_surface.dart';
import 'package:jizhang_app/core/widgets/app_page_background.dart';
import 'package:jizhang_app/core/widgets/quick_add_button.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

AppThemeDefinition _remote(String color) => AppThemeDefinition.fromJson({
  'id': 'remote',
  'name': '远程主题',
  'premium': false,
  'background': '#FFFFFF',
  'surface': '#FFFFFF',
  'surfaceSoft': '#EEEEEE',
  'primary': color,
  'primaryDark': color,
  'primarySoft': '#EEEEEE',
  'textPrimary': '#111111',
  'textSecondary': '#666666',
  'divider': '#DDDDDD',
});

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance(), l2 = b.computeLuminance();
  return (l1 > l2 ? l1 + .05 : l2 + .05) / (l1 > l2 ? l2 + .05 : l1 + .05);
}

void main() {
  final themes = [
    ...BuiltInThemes.all,
    _remote('#7B3EB0'),
    _remote('#808080'),
    _remote('#000000'),
    _remote('#0033FF'),
  ];
  for (final definition in themes) {
    testWidgets(
      '${definition.id}/${definition.primary} night surfaces and buttons remain readable',
      (tester) async {
        final theme = AppTheme.dark(definition);
        expect(theme.scaffoldBackgroundColor, Colors.black);
        expect(theme.cardColor, const Color(0xFF111111));
        expect(theme.dialogTheme.backgroundColor, theme.cardColor);
        expect(
          _contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  const AppCard(
                    material: AppCardMaterial.frosted,
                    borderRadius: 20,
                    child: Text('普通卡片'),
                  ),
                  const AppGlassSurface(child: Text('玻璃面板')),
                  FilledButton(
                    onPressed: () => taps++,
                    child: const Text('确认'),
                  ),
                  const FilledButton(onPressed: null, child: Text('不可用')),
                  QuickAddButton(onPressed: () => taps++, onLongPress: () {}),
                ],
              ),
            ),
          ),
        );
        final card =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byType(AppCard),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        expect(card.color, theme.cardColor);
        expect(card.borderRadius, BorderRadius.circular(16));
        final panel =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byType(AppGlassSurface),
                            matching: find.byType(Container),
                          )
                          .last,
                    )
                    .decoration!
                as BoxDecoration;
        expect(panel.gradient, isNull);
        expect(panel.color, Colors.white.withValues(alpha: .10));
        final panelBackground = Color.alphaBlend(panel.color!, Colors.black);
        expect(
          _contrast(theme.colorScheme.onSurfaceVariant, panelBackground),
          greaterThanOrEqualTo(4.5),
        );
        final fab = tester.widget<LiquidGlassFab>(find.byType(LiquidGlassFab));
        expect(
          fab.style!.appearance.color,
          Colors.white.withValues(alpha: .26),
        );
        await tester.tap(find.text('确认'));
        await tester.tap(find.text('不可用'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final highContrast in [false, true]) {
    testWidgets('night navigation contrast, high contrast=$highContrast', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final definition in themes) {
        await tester.pumpWidget(const SizedBox.shrink());
        final theme = AppTheme.dark(definition);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(393, 844),
                highContrast: highContrast,
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: AppPageBackground(child: SizedBox.expand()),
                  ),
                  AppBottomNavigation(location: '/', onNavigate: (_) {}),
                ],
              ),
            ),
          ),
        );
        final bar = tester.widget<LiquidGlassTabBar>(
          find.byType(LiquidGlassTabBar),
        );
        final capsule = bar.style!.appearance.color;
        expect(capsule.a, highContrast ? 1 : .5);
        if (!highContrast)
          expect(
            bar.pillStyle.rest!.appearance.color,
            Colors.white.withValues(alpha: .10),
          );
        final barBackground = Color.alphaBlend(
          capsule,
          const Color(0xFF101010),
        );
        final pillBackground = Color.alphaBlend(
          bar.pillStyle.rest!.appearance.color,
          barBackground,
        );
        expect(
          _contrast(bar.itemStyle.selectedColor, pillBackground),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(bar.itemStyle.unselectedColor, barBackground),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'night glow stays at the upper left and neutral themes stay neutral',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final definition in [BuiltInThemes.freshGreen, _remote('#808080')]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(definition),
            home: RepaintBoundary(
              key: key,
              child: const AppPageBackground(child: SizedBox.expand()),
            ),
          ),
        );
        await tester.pump();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage());
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        Color pixel(int x, int y) {
          final index = (y * image!.width + x) * 4;
          return Color.fromARGB(
            255,
            bytes!.getUint8(index),
            bytes.getUint8(index + 1),
            bytes.getUint8(index + 2),
          );
        }

        final top = pixel(30, 65), bottom = pixel(30, 775);
        expect(top.computeLuminance(), greaterThan(bottom.computeLuminance()));
        if (definition == BuiltInThemes.freshGreen) {
          expect(top.g, greaterThan(top.r));
        } else {
          expect(top.r, top.g);
          expect(top.g, top.b);
        }
        image!.dispose();
      }
    },
  );
}
