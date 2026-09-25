import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/widgets/app_liquid_glass_surface.dart';

void main() {
  testWidgets('liquid surface uses the tracked lens engine', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(BuiltInThemes.liquidGlass),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 120,
              child: LiquidGlassBatch(
                child: AppLiquidGlassSurface(
                  borderRadius: 22,
                  child: Text('glass'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LiquidGlassLens), findsOneWidget);
    expect(find.text('glass'), findsOneWidget);
  });

  testWidgets('solid theme keeps the inexpensive non-glass fallback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(BuiltInThemes.freshGreen),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 120,
              child: AppLiquidGlassSurface(
                borderRadius: 22,
                child: Text('solid'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LiquidGlassLens), findsNothing);
    expect(find.text('solid'), findsOneWidget);
  });
}
