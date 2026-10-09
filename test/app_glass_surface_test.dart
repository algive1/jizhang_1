import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/widgets/app_glass_surface.dart';

void main() {
  for (final theme in [BuiltInThemes.freshGreen, BuiltInThemes.liquidGlass]) {
    for (final dark in [false, true]) {
      testWidgets('显式透明度在 ${theme.id} 深色=$dark 下实际透出背景', (tester) async {
        final pixels = <Color>[];
        for (final background in [Colors.red, Colors.blue]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark(theme) : AppTheme.light(theme),
              home: RepaintBoundary(
                key: const ValueKey('glass-probe'),
                child: ColoredBox(
                  color: background,
                  child: const Center(
                    child: AppGlassSurface(
                      glassOpacity: .6,
                      blurSigma: 0,
                      shadow: false,
                      chromaticEdge: false,
                      child: SizedBox.square(dimension: 120),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          pixels.add(
            (await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('glass-probe')),
              );
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                final offset =
                    ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
                return Color.fromARGB(
                  bytes.getUint8(offset + 3),
                  bytes.getUint8(offset),
                  bytes.getUint8(offset + 1),
                  bytes.getUint8(offset + 2),
                );
              } finally {
                image.dispose();
              }
            }))!,
          );
        }
        expect(pixels.first.r - pixels.last.r, greaterThan(.25));
        expect(pixels.last.b - pixels.first.b, greaterThan(.25));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
