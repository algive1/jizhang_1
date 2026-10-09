import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_learning.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_strategy.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_confirm_page.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'package:jizhang_app/features/intelligence/domain/merchant_classification_service.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  for (final (stalledCall, dismiss) in [(1, false), (2, false), (1, true)]) {
    testWidgets('自动入账服务检查 $stalledCall 无响应，主动关闭=$dismiss，迟到响应不会入账', (
      tester,
    ) async {
      final database = createMemoryDatabase();
      await tester.runAsync(() => DatabaseSeeder(database).seedIfNeeded());
      final settings = DriftAppSettingsRepository(database);
      await tester.runAsync(
        () => settings.set(AutoBookkeepingStrategy.settingKey, 'automatic'),
      );
      final bill = PendingAutoBookkeepingCandidate(
        fingerprint: 'stalled-runtime-$stalledCall',
        amountInCents: 1200,
        merchant: '测试商户',
        paymentMethod: '微信支付',
        timestamp: DateTime.now(),
        sourceApp: 'WECHAT',
        scene: 'PAYMENT_SUCCESS',
        transactionType: 'EXPENSE',
      );
      final pending = _Pending(bill), response = Completer<bool>();
      var checks = 0, ready = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('jizhang/autobookkeeping_pending'),
        (call) async {
          if (call.method != 'canAutoRecord') return null;
          return ++checks == stalledCall ? response.future : true;
        },
      );
      for (final name in [
        'jizhang/autobookkeeping_overlay',
        'jizhang/autobookkeeping_logs',
        'jizhang/notice_theme',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(name),
          (_) async => true,
        );
      }
      addTearDown(() async {
        if (!response.isCompleted) response.complete(true);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 20));
        for (final name in [
          'jizhang/autobookkeeping_pending',
          'jizhang/autobookkeeping_overlay',
          'jizhang/autobookkeeping_logs',
          'jizhang/notice_theme',
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(name), null);
        }
        await tester.runAsync(database.close);
        await tester.pump();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            databaseBootstrapProvider.overrideWith((ref) async {}),
            autoBookkeepingPendingBridgeProvider.overrideWithValue(pending),
            autoBookkeepingLearningServiceProvider.overrideWithValue(
              _KnownLearning(),
            ),
          ],
          child: MaterialApp(
            home: AutoBookkeepingConfirmPage(
              overlayMode: true,
              initialCandidate: bill,
              allowAutomaticSave: true,
              onReady: () => ready++,
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 15; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(checks, stalledCall);
      if (dismiss) {
        await tester.tap(
          find.byKey(const ValueKey('autobookkeeping-loading-close')),
        );
        await tester.pump();
        response.complete(true);
      }
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('autobookkeeping-quick-add-review')),
        findsOneWidget,
      );
      expect(ready, 1);
      if (!response.isCompleted) response.complete(true);
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(
          () => DriftTransactionRepository(database).getAll(),
        ),
        isEmpty,
      );
      expect(pending.completed, 0);
      expect(pending.current?.fingerprint, bill.fingerprint);
      expect(tester.takeException(), isNull);
    });
  }
  for (final (mode, score, healthy, fail, shouldSave) in [
    (AutoBookkeepingStrategy.conservative, 1.0, true, false, false),
    (AutoBookkeepingStrategy.smart, 1.0, true, false, true),
    (AutoBookkeepingStrategy.smart, .2, true, false, false),
    (AutoBookkeepingStrategy.automatic, .2, true, false, true),
    (AutoBookkeepingStrategy.automatic, 1.0, false, false, false),
    (AutoBookkeepingStrategy.automatic, 1.0, true, true, false),
  ]) {
    testWidgets(
      '真实入账 ${mode.name} confidence=$score healthy=$healthy failure=$fail',
      (tester) async {
        final database = createMemoryDatabase();
        addTearDown(() async {
          await tester.runAsync(database.close);
          await tester.pump();
        });
        await tester.runAsync(() => DatabaseSeeder(database).seedIfNeeded());
        final settings = DriftAppSettingsRepository(database);
        await tester.runAsync(
          () => settings.set(AutoBookkeepingStrategy.settingKey, mode.name),
        );
        final repository = DriftTransactionRepository(database);
        final accounts = DriftAccountRepository(database);
        final before = (await tester.runAsync(accounts.getActive))!
            .firstWhere((a) => a.id == SeedIds.wechatAccount)
            .balance;
        final bill = PendingAutoBookkeepingCandidate(
          fingerprint: 'automatic-save',
          amountInCents: 3200,
          merchant: '星巴克',
          paymentMethod: '微信支付',
          timestamp: DateTime.now(),
          sourceApp: 'WECHAT',
          scene: 'PAYMENT_SUCCESS',
          transactionType: 'EXPENSE',
          amountConfidence: score,
          merchantConfidence: score,
          sceneConfidence: score,
        );
        final pending = _Pending(bill), learning = _KnownLearning();
        var ready = 0;
        final notices = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('jizhang/autobookkeeping_pending'),
          (call) async => call.method == 'canAutoRecord' ? healthy : null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('jizhang/autobookkeeping_overlay'),
          (_) async => null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('jizhang/notice_theme'),
          (call) async {
            if (call.method == 'show')
              notices.add((call.arguments as Map)['message'] as String);
            return true;
          },
        );
        addTearDown(() {
          for (final name in [
            'jizhang/autobookkeeping_pending',
            'jizhang/autobookkeeping_overlay',
            'jizhang/notice_theme',
          ]) {
            messenger.setMockMethodCallHandler(MethodChannel(name), null);
          }
        });
        Widget page() => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            autoBookkeepingPendingBridgeProvider.overrideWithValue(pending),
            autoBookkeepingLearningServiceProvider.overrideWithValue(learning),
            quickBookkeepingServiceProvider.overrideWithValue(
              fail
                  ? _FailingSave(repository, settings)
                  : QuickBookkeepingService(
                      repository,
                      settings,
                      database: database,
                      activeBookId: () => SeedIds.personalBook,
                    ),
            ),
          ],
          child: MaterialApp(
            home: AutoBookkeepingConfirmPage(
              overlayMode: true,
              allowAutomaticSave: true,
              onReady: () => ready++,
            ),
          ),
        );
        await tester.pumpWidget(page());
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        final saved = await tester.runAsync(
          () => repository.getById('auto-automatic-save'),
        );
        expect(saved != null, shouldSave);
        expect(pending.completed, shouldSave ? 1 : 0);
        expect(ready, 1);
        if (fail) expect(notices, contains('自动入账未完成，账单已保留待确认'));
        if (shouldSave) {
          expect(saved!.userCorrected, isFalse);
          expect(
            (jsonDecode(saved.metadataJson!)
                as Map)['autobookkeeping']['strategy'],
            mode.name,
          );
          // Replay the same native identity: complete it again without a second debit.
          await tester.pumpWidget(const SizedBox());
          pending.current = bill;
          await tester.pumpWidget(page());
          for (var i = 0; i < 10; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          final after = (await tester.runAsync(accounts.getActive))!
              .firstWhere((a) => a.id == SeedIds.wechatAccount)
              .balance;
          expect(after, closeTo(before - 32, .001));
          expect(pending.completed, 2);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      },
    );
  }
}

class _Pending extends MethodChannelAutoBookkeepingPendingBridge {
  _Pending(this.current);
  PendingAutoBookkeepingCandidate? current;
  int completed = 0;
  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() async => current;
  @override
  Future<void> complete({
    bool keepScreenshot = false,
    String? fingerprint,
  }) async {
    completed++;
    current = null;
  }
}

class _KnownLearning implements AutoBookkeepingLearningService {
  @override
  MerchantNormalizer get normalizer => const MerchantNormalizer();
  @override
  Future<AutoBookkeepingRecommendation> recommend({
    required PendingAutoBookkeepingCandidate candidate,
    required String fallbackBookId,
    required TransactionType transactionType,
  }) async => AutoBookkeepingRecommendation(
    bookId: fallbackBookId,
    accountId: SeedIds.wechatAccount,
    categoryId: 'expense-food',
    categoryConfidence: 1,
  );
  @override
  Future<void> remember({
    required String transactionId,
    required PendingAutoBookkeepingCandidate candidate,
    required String bookId,
    required String accountId,
    required String categoryId,
    String? subcategoryId,
    List<String> tags = const [],
    required bool rememberForMerchant,
  }) async {
    if (rememberForMerchant) throw StateError('自动入账不应该学习推断结果');
  }
}

class _FailingSave extends QuickBookkeepingService {
  _FailingSave(super.transactions, super.settings);
  @override
  Future<TransactionRecord> save(QuickBookkeepingRequest request) async =>
      throw StateError('simulated write failure');
}
