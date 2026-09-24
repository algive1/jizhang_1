import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';

const _captureKey = ValueKey('route-capture');

Future<Color> _pixelAt(WidgetTester tester, int x, int y) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (y * image.width + x) * 4;
    final pixel = Color.fromARGB(
      bytes.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
    image.dispose();
    return pixel;
  }))!;
}

void main() {
  for (final appearance in [
    BuiltInThemes.freshGreen,
    BuiltInThemes.liquidGlass,
  ]) {
    testWidgets(
      '${appearance.id}: push and swipe-back do not show the old page through blank space',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          RepaintBoundary(
            key: _captureKey,
            child: MaterialApp(
              theme: AppTheme.light(appearance)
                  .copyWith(platform: TargetPlatform.android),
              home: Scaffold(
                backgroundColor: Colors.red,
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
                            body: Center(child: Text('new page')),
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(await _pixelAt(tester, 750, 350), appearance.background);

        await tester.pumpAndSettle();
        final restingLeft = tester.getTopLeft(find.text('new page')).dx;
        final gesture = await tester.startGesture(const Offset(4, 300));
        await gesture.moveBy(const Offset(180, 0));
        await tester.pump();
        expect(
          tester.getTopLeft(find.text('new page')).dx - restingLeft,
          greaterThan(100),
        );
        expect(await _pixelAt(tester, 750, 350), appearance.background);
        await gesture.up();
      },
    );
  }

  testWidgets(
    'iOS content-only route keeps its background through push and back swipe',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: MaterialApp(
            theme: AppTheme.light(BuiltInThemes.liquidGlass)
                .copyWith(platform: TargetPlatform.iOS),
            home: Scaffold(
              backgroundColor: Colors.red,
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const SafeArea(
                          child: Center(child: Text('content-only page')),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        await _pixelAt(tester, 750, 350),
        BuiltInThemes.liquidGlass.background,
      );

      await tester.pumpAndSettle();
      final restingLeft = tester.getTopLeft(find.text('content-only page')).dx;
      final gesture = await tester.startGesture(const Offset(4, 300));
      await gesture.moveBy(const Offset(180, 0));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('content-only page')).dx - restingLeft,
        greaterThan(100),
      );
      expect(
        await _pixelAt(tester, 750, 350),
        BuiltInThemes.liquidGlass.background,
      );
      await gesture.up();
    },
  );

  testWidgets(
    'fullscreen bookkeeping-style route covers the previous page during entry',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: MaterialApp(
            theme: AppTheme.light(BuiltInThemes.liquidGlass),
            home: Scaffold(
              backgroundColor: Colors.red,
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => const Scaffold(
                          body: Center(child: Text('bookkeeping page')),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        await _pixelAt(tester, 400, 550),
        BuiltInThemes.liquidGlass.background,
      );
    },
  );
}
