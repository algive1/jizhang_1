import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/home/presentation/goal_flow_track.dart';

void main() {
  testWidgets('flow repaints, loops and stops for reduced motion', (
    tester,
  ) async {
    GoalFlowTrack.animationsEnabled = true;
    addTearDown(() => GoalFlowTrack.animationsEnabled = false);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: false);
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 32,
            child: RepaintBoundary(
              key: ValueKey('flow-capture'),
              child: GoalFlowTrack(count: 6, currentIndex: 3, enabled: true),
            ),
          ),
        ),
      ),
    );
    Future<List<int>> pixels() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('flow-capture')),
      );
      return tester
          .runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            return bytes!.buffer.asUint8List().toList();
          })
          .then((value) => value!);
    }

    await tester.pump();
    final first = await pixels();
    await tester.pump(const Duration(milliseconds: 900));
    expect(await pixels(), isNot(equals(first)));
    await tester.pump(const Duration(milliseconds: 3600));
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpAndSettle();
    final stopped = await pixels();
    await tester.pump(const Duration(seconds: 1));
    expect(await pixels(), equals(stopped));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
