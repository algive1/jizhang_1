import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/assistant/application/assistant_conversation.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/voice/application/speech_recognition_service.dart';
import 'package:jizhang_app/features/voice/presentation/voice_bookkeeping_sheet.dart';

void main() {
  testWidgets('段落确认前不入账，确认后保存两笔并关闭重复入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = createMemoryDatabase();
    await DatabaseSeeder(db).seedIfNeeded();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        speechRecognitionServiceProvider.overrideWithValue(_SilentSpeech()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(databaseBootstrapProvider.future);
    final repo = container.read(transactionRepositoryProvider);
    final before = (await repo.getAll()).length;
    await container
        .read(assistantConversationProvider.notifier)
        .send('午饭12元微信，地铁6元支付宝');
    expect((await repo.getAll()).length, before);
    final router = container.read(appRouterProvider)..go('/assistant');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('检查并确认账单'));
    await tester.tap(find.text('检查并确认账单'));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceBookkeepingSheet), findsOneWidget);
    expect(find.text('确认 2 笔并保存'), findsOneWidget);
    expect((await repo.getAll()).length, before);
    await tester.tap(find.byKey(const ValueKey('ai-confirm')));
    await tester.pumpAndSettle();
    expect((await repo.getAll()).length, before + 2);
    expect(find.byType(VoiceBookkeepingSheet), findsNothing);
    expect(find.text('检查并确认账单'), findsNothing);
    expect(find.text('本次确认的账单已入账，可在流水中查看。'), findsOneWidget);
    for (final entry in [
      ('选择图片', '/profile/receipt-ocr'),
      ('附件', '/profile/bill-import'),
    ]) {
      final direct = find.byTooltip(entry.$1);
      if (direct.evaluate().isEmpty) {
        await tester.tap(find.byTooltip('更多输入方式'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.$1));
      } else {
        await tester.tap(direct);
      }
      await tester.pumpAndSettle();
      expect(router.state.uri.path, entry.$2);
      router.go('/assistant');
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

class _SilentSpeech implements SpeechRecognitionService {
  @override
  Stream<SpeechRecognitionEvent> get events => const Stream.empty();
  @override
  Future<bool> initialize() async => false;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}
