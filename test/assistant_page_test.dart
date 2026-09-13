import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/assistant/application/assistant_conversation.dart';
import 'package:jizhang_app/features/assistant/presentation/assistant_page.dart';

import 'support/reference_capture.dart';

void main() {
  for (final width in [320.0, 393.0, 430.0]) {
    testWidgets('assistant real conversation fits $width and keyboard', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = createMemoryDatabase();
      await DatabaseSeeder(db).seedIfNeeded();
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      {
        await c.read(assistantConversationProvider.future);
        await c
            .read(assistantConversationProvider.notifier)
            .send('今天中午吃饭微信支付12元');
        await c
            .read(assistantConversationProvider.notifier)
            .send('再帮我记一笔，地铁6元，支付宝');
      }
      await loadReferenceFonts(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: RepaintBoundary(
              key: const ValueKey('capture'),
              child: const AssistantPage(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('已为你记账成功！'), findsWidgets);
      if (width == 393) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('docs/qa/assistant-2026-09-12/conversation.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '怎么记账');
      await tester.tap(find.byTooltip('发送'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
