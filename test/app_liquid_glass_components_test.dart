// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/widgets/app_bottom_navigation.dart';
import 'package:jizhang_app/core/widgets/app_liquid_glass_components.dart';
import 'package:jizhang_app/core/widgets/app_liquid_glass_spec.dart';
import 'package:jizhang_app/core/widgets/app_page_background.dart';
import 'package:jizhang_app/core/widgets/quick_add_button.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:liquid_glass_easy/src/widgets/components/liquid_glass_segmented.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(BuiltInThemes.liquidGlass),
    home: Stack(
      children: [
        const Positioned.fill(
          child: AppPageBackground(child: SizedBox.expand()),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: child),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('card uses the same optical material as navigation capsule', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 260,
          height: 120,
          child: AppLiquidGlassCard(child: Text('card')),
        ),
      ),
    );
    await tester.pump();

    final lens = tester.widget<LiquidGlassLens>(
      find.descendant(
        of: find.byType(AppLiquidGlassCard),
        matching: find.byType(LiquidGlassLens),
      ),
    );
    final style = lens.style;

    expect(style.appearance.color, AppBottomNavigation.capsuleTint());
    expect(
      style.appearance.blur.sigmaX,
      AppBottomNavigation.capsuleBlurSigma,
    );
    expect(
      style.appearance.blur.sigmaY,
      AppBottomNavigation.capsuleBlurSigma,
    );
    expect(
      style.refraction.distortion,
      AppLiquidGlassSpec.capsuleDistortion,
    );
    expect(
      style.refraction.distortionWidth,
      AppLiquidGlassSpec.capsuleDistortionWidth,
    );
    expect(
      style.refraction.chromaticAberration,
      AppLiquidGlassSpec.capsuleChromaticAberration,
    );
    expect(style.shape?.cornerRadius, 24);
  });

  testWidgets('single button and quick-add FAB share one optical recipe', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLiquidGlassButton(
              label: '确认',
              onPressed: () {},
            ),
            const SizedBox(width: 24),
            QuickAddButton(
              onPressed: () {},
              onLongPress: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<LiquidGlassButton>(
      find.byType(LiquidGlassButton),
    );
    final fab = tester.widget<LiquidGlassFab>(find.byType(LiquidGlassFab));
    final buttonStyle = button.style!;
    final fabStyle = fab.style!;

    expect(buttonStyle.appearance.color, fabStyle.appearance.color);
    expect(
      buttonStyle.appearance.blur.sigmaX,
      fabStyle.appearance.blur.sigmaX,
    );
    expect(
      buttonStyle.appearance.blur.sigmaY,
      fabStyle.appearance.blur.sigmaY,
    );
    expect(
      buttonStyle.appearance.shadow?.blur,
      fabStyle.appearance.shadow?.blur,
    );
    expect(
      buttonStyle.appearance.shadow?.opacity,
      fabStyle.appearance.shadow?.opacity,
    );
    expect(
      buttonStyle.appearance.shadow?.offset,
      fabStyle.appearance.shadow?.offset,
    );
    expect(
      buttonStyle.refraction.distortion,
      fabStyle.refraction.distortion,
    );
    expect(
      buttonStyle.refraction.distortionWidth,
      fabStyle.refraction.distortionWidth,
    );
    expect(
      buttonStyle.refraction.chromaticAberration,
      fabStyle.refraction.chromaticAberration,
    );
    expect(buttonStyle.shape?.borderWidth, fabStyle.shape?.borderWidth);
    expect(
      buttonStyle.shape?.lightIntensity,
      fabStyle.shape?.lightIntensity,
    );
    expect(buttonStyle.shape?.lightColor, fabStyle.shape?.lightColor);
    expect(
      buttonStyle.shape?.lightDirection,
      fabStyle.shape?.lightDirection,
    );

    // Geometry differs by design: the standalone button is a pill while the
    // FAB is a circle. The optical material around that geometry is identical.
    expect(buttonStyle.shape?.cornerRadius, 24);
    expect(fabStyle.shape?.cornerRadius, QuickAddButton.defaultDiameter / 2);
  });

  testWidgets('tabs reuse navigation capsule, rest pill and moving glass', (
    tester,
  ) async {
    var selected = 0;

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => AppLiquidGlassTabs(
            tabs: const ['日', '周', '月'],
            selectedIndex: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );
    await tester.pump();

    final tabs = tester.widget<LiquidGlassSegmented>(
      find.byType(LiquidGlassSegmented),
    );
    final style = tabs.style!;
    final pill = tabs.pillStyle;
    final moving = const LiquidGlassTabPillStyle().effectiveGlass;

    expect(style.appearance.color, AppBottomNavigation.capsuleTint());
    expect(
      style.appearance.blur.sigmaX,
      AppBottomNavigation.capsuleBlurSigma,
    );
    expect(
      style.refraction.distortion,
      AppLiquidGlassSpec.capsuleDistortion,
    );
    expect(pill.glass, isTrue);
    expect(pill.growHeight, AppLiquidGlassSpec.tabGrowHeight);
    expect(
      pill.glassStyle?.appearance.color,
      moving.appearance.color,
    );
    expect(
      pill.glassStyle?.appearance.blur.sigmaX,
      moving.appearance.blur.sigmaX,
    );
    expect(
      pill.glassStyle?.refraction.distortion,
      moving.refraction.distortion,
    );
    expect(
      pill.glassStyle?.refraction.distortionWidth,
      moving.refraction.distortionWidth,
    );
    expect(
      pill.glassStyle?.refraction.chromaticAberration,
      moving.refraction.chromaticAberration,
    );
    expect(
      pill.restStyle?.appearance.color,
      const Color(0xFF333333).withValues(alpha: .03),
    );

    await tester.tap(find.text('月'));
    await tester.pump();
    expect(selected, 2);
  });

  testWidgets('high contrast removes refraction from reusable surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(BuiltInThemes.liquidGlass),
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 100,
                child: AppLiquidGlassCard(child: Text('card')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final lens = tester.widget<LiquidGlassLens>(
      find.descendant(
        of: find.byType(AppLiquidGlassCard),
        matching: find.byType(LiquidGlassLens),
      ),
    );

    expect(lens.style.appearance.color.a, 1);
    expect(lens.style.refraction.distortion, 0);
    expect(lens.style.refraction.distortionWidth, 0);
    expect(lens.style.refraction.chromaticAberration, 0);
  });
}
