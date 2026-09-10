// Optional local visual QA: fonts are loaded from the host, never shipped.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadReferenceFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final entry in {
      'PingFang SC': '/System/Library/Fonts/STHeiti Light.ttc',
      'Reference Latin': '/System/Library/Fonts/Supplemental/Arial.ttf',
      'MaterialIcons': '/Users/algive/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(entry.value);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
}

Future<void> captureReference(
  WidgetTester tester,
  Finder finder,
  String name,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('docs/qa/home-reference-2026-09-10/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
