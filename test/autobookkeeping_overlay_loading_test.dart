import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_overlay_app.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';

void main() {
  testWidgets('预热与刷新未完成也立即响应展示，浮层不依赖账本订阅首帧', (tester) async {
    final database = createMemoryDatabase();
    await tester.runAsync(() => DatabaseSeeder(database).seedIfNeeded());
    final bootstrap = Completer<void>(), revision = Completer<int>();
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('jizhang/autobookkeeping_overlay');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('jizhang/bookkeeping_changes'),
      (_) => revision.future,
    );
    addTearDown(() async {
      if (!bootstrap.isCompleted) bootstrap.complete();
      if (!revision.isCompleted) revision.complete(0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 20));
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('jizhang/bookkeeping_changes'),
        null,
      );
      await tester.runAsync(database.close);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          databaseBootstrapProvider.overrideWith((ref) => bootstrap.future),
          booksProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const AutoBookkeepingOverlayApp(),
      ),
    );
    await tester.pump();
    expect(calls.map((call) => call.method), contains('engineReady'));
    final delivered = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('show', {
          'fingerprint': 'overlay-loading-regression',
          'amountInCents': 1200,
          'merchant': '测试商户',
          'paymentMethod': '微信支付',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sourceApp': 'WECHAT',
          'scene': 'PAYMENT_SUCCESS',
          'transactionType': 'EXPENSE',
        }),
      ),
      (_) => delivered.complete(),
    );
    await tester.pump();
    expect(delivered.isCompleted, isTrue);
    final close = find.byKey(const ValueKey('autobookkeeping-loading-close'));
    expect(close, findsOneWidget);
    expect(tester.renderObject(close).attached, isTrue);
    expect(
      find.ancestor(of: close, matching: find.byType(Opacity)),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
    bootstrap.complete();
    for (var frame = 0; frame < 15; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(const ValueKey('autobookkeeping-quick-add-review')),
      findsOneWidget,
    );
    expect(calls.where((call) => call.method == 'prepared'), hasLength(1));
    expect(find.textContaining('加载超时'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
