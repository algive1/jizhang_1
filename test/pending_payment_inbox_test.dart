import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_inbox.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/pending_payment_inbox_section.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/voice/application/speech_recognition_service.dart';
import 'package:jizhang_app/features/voice/domain/transaction_parser.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';

void main() {
  testWidgets('收件箱展示完整付款信息，忽略后保留详情且可重新去记账', (tester) async {
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await database.close();
    });
    final bridge = _ReviewBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          autoBookkeepingInboxBridgeProvider.overrideWithValue(bridge),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PendingPaymentInboxSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('测试午餐'), findsOneWidget);
    expect(find.text('订单号：ORDER-REVIEW-1'), findsOneWidget);
    expect(find.text('备注：工作餐'), findsOneWidget);
    expect(find.text('付款账户尾号：1234'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payment-ignore-review-1')));
    await tester.pumpAndSettle();
    expect(find.text('待确认 0'), findsOneWidget);
    await tester.tap(find.text('已忽略 1'));
    await tester.pumpAndSettle();
    expect(find.text('测试午餐'), findsOneWidget);
    expect(find.text('去记账'), findsOneWidget);
    expect(bridge.completed, 0);
  });

  test('已入账原始指纹从收件箱移除，同金额的其他订单保留', () async {
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded();
    addTearDown(database.close);
    final bridge = _ReviewBridge();
    final candidate = bridge.candidate;
    bridge.items.add(
      PendingPaymentReview(
        PendingAutoBookkeepingCandidate(
          fingerprint: 'another-order',
          amountInCents: candidate.amountInCents,
          merchant: candidate.merchant,
          paymentMethod: candidate.paymentMethod,
          timestamp: candidate.timestamp,
          sourceApp: candidate.sourceApp,
          scene: candidate.scene,
          transactionType: candidate.transactionType,
        ),
      ),
    );
    final saved = TransactionRecord(
      id: 'auto-${candidate.fingerprint}',
      bookId: SeedIds.personalBook,
      type: TransactionType.expense,
      amount: 18, // User edits must not break the original payment identity.
      accountId: SeedIds.alipayAccount,
      merchant: '抖音汉堡',
      occurredAt: candidate.timestamp.add(const Duration(minutes: 1)),
      createdAt: candidate.timestamp,
      updatedAt: candidate.timestamp,
      source: TransactionSource.auto,
    );
    await DriftTransactionRepository(database).create(saved);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        autoBookkeepingInboxBridgeProvider.overrideWithValue(bridge),
      ],
    );
    addTearDown(container.dispose);
    final items = await container.read(pendingPaymentInboxProvider.future);
    expect(items.single.candidate.fingerprint, 'another-order');
    expect(bridge.recorded, [candidate.fingerprint]);
    expect(
      await DriftTransactionRepository(database).getById(saved.id),
      isNotNull,
    );
  });

  testWidgets('收件箱确认复用同一浮层，关闭不入账，完成后只保存一次', (tester) async {
    final notificationRecovery = Completer<bool>();
    const notifications = MethodChannel('jizhang/payment_notifications');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      notifications,
      (call) async {
        if (call.method == 'isEnabled') return notificationRecovery.future;
        return null;
      },
    );
    addTearDown(() {
      if (!notificationRecovery.isCompleted)
        notificationRecovery.complete(false);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        notifications,
        null,
      );
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded();
    final accounts = await DriftAccountRepository(database).getActive();
    final categories = await DriftCategoryRepository(database).getActive();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await database.close();
    });
    final bridge = _ReviewBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          databaseBootstrapProvider.overrideWith((ref) async {}),
          accountsByBookProvider(SeedIds.personalBook)
              .overrideWithValue(AsyncData(accounts)),
          categoriesByBookProvider(SeedIds.personalBook)
              .overrideWithValue(AsyncData(categories)),
          autoBookkeepingInboxBridgeProvider.overrideWithValue(bridge),
          autoBookkeepingPendingBridgeProvider.overrideWithValue(bridge),
          speechRecognitionServiceProvider.overrideWithValue(_SilentSpeech()),
          voiceTransactionParserProvider.overrideWithValue(
            const RuleBasedTransactionParser(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PendingPaymentInboxSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payment-record-review-1')));
    await _load(tester);
    expect(
      find.byKey(const ValueKey('autobookkeeping-quick-add-review')),
      findsOneWidget,
      reason:
          'selected=${bridge.selected?.fingerprint}; '
          '${tester.widgetList<Text>(find.byType(Text, skipOffstage: false)).map((text) => text.data).join(' | ')}',
    );
    await tester.tap(find.byKey(const ValueKey('quick-review-cancel')));
    await _load(tester);
    expect(bridge.completed, 0);
    expect(bridge.deferred, 1);
    expect(await DriftTransactionRepository(database).getAll(), isEmpty);
    await tester.tap(find.byKey(const ValueKey('payment-record-review-1')));
    await _load(tester);
    expect(find.byKey(const ValueKey('quick-ai-entry')), findsNothing);
    expect(find.byKey(const ValueKey('quick-voice-entry')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quick-ledger-only-chip')));
    await _load(tester);
    expect(await DriftTransactionRepository(database).getAll(), isEmpty);
    await tester.tap(find.byKey(const ValueKey('quick-review-complete')));
    await _load(tester);
    expect(bridge.completed, 1);
    expect(bridge.completedFingerprint, bridge.candidate.fingerprint);
    expect(bridge.items, isEmpty);
    final saved = await DriftTransactionRepository(database).getAll();
    expect(saved, hasLength(1));
    expect(saved.single.amount, bridge.candidate.amountInCents / 100);
    expect(
      saved.single.metadataJson,
      contains('"ignoreAccountBalanceEffect":true'),
    );
    expect(
      (await database.accountDao.findById(saved.single.accountId))!
          .balanceInCents,
      0,
    );
    expect(saved.single.bookId, SeedIds.personalBook);
    expect(
      find.byKey(const ValueKey('autobookkeeping-quick-add-review')),
      findsNothing,
      reason: '入账成功必须关闭确认页，即使通知补处理没有返回',
    );
    notificationRecovery.complete(false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _SilentSpeech implements SpeechRecognitionService {
  @override
  Stream<SpeechRecognitionEvent> get events => const Stream.empty();
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

Future<void> _load(WidgetTester tester) async {
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
}

class _ReviewBridge extends AutoBookkeepingInboxBridge
    implements AutoBookkeepingPendingBridge {
  _ReviewBridge();
  final candidate = PendingAutoBookkeepingCandidate(
    fingerprint: 'review-1',
    amountInCents: 1234,
    merchant: '测试午餐',
    paymentMethod: '支付宝',
    timestamp: DateTime(2026, 9, 30, 12),
    sourceApp: 'ALIPAY',
    scene: 'ALIPAY_PAYMENT_SUCCESS',
    transactionType: 'EXPENSE',
    note: '工作餐',
    orderId: 'ORDER-REVIEW-1',
    identifierSuffix: '1234',
  );
  late List<PendingPaymentReview> items = [PendingPaymentReview(candidate)];
  PendingAutoBookkeepingCandidate? selected;
  int completed = 0, deferred = 0;
  String? completedFingerprint;
  final recorded = <String>[];
  @override
  Future<List<PendingPaymentReview>> getInbox() async => List.of(items);
  @override
  Future<void> markRecorded(String fingerprint) async {
    recorded.add(fingerprint);
    items.removeWhere((item) => item.candidate.fingerprint == fingerprint);
  }

  @override
  Future<bool> select(String fingerprint) async {
    selected = candidate;
    return true;
  }

  @override
  Future<void> ignore(String fingerprint) async {
    items = [PendingPaymentReview(candidate, ignored: true)];
  }

  @override
  Future<void> defer(String fingerprint) async {
    deferred++;
    selected = null;
  }

  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() async => selected;
  @override
  Future<void> complete({
    bool keepScreenshot = false,
    String? fingerprint,
  }) async {
    completed++;
    completedFingerprint = fingerprint;
    items = [];
    selected = null;
  }

  @override
  Future<String?> promoteScreenshot(String path) async => null;
  @override
  Future<AutoBookkeepingEnqueueResult> enqueue(
    PendingAutoBookkeepingCandidate candidate,
  ) async => AutoBookkeepingEnqueueResult.accepted;
}
