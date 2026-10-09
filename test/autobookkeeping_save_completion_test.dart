import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_confirm_page.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/quick_add_sheet.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transaction_attachment_repository.dart';
import 'package:jizhang_app/features/transactions/domain/transaction_attachment.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  for (final heldLogs in [false, true]) {
    testWidgets('完整确认页保存并关闭，日志无响应=$heldLogs', (tester) async {
      final database = createMemoryDatabase();
      await tester.runAsync(() => DatabaseSeeder(database).seedIfNeeded());
      final balance = (await tester.runAsync(
        () => database.accountDao.findById(SeedIds.wechatAccount),
      ))!.balanceInCents;
      final candidate = {
        'fingerprint': 'save-completion-regression',
        'amountInCents': 1600,
        'merchant': '保存回归商户',
        'paymentMethod': '微信支付',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sourceApp': 'WECHAT',
        'scene': 'PAYMENT_SUCCESS',
        'transactionType': 'EXPENSE',
      };
      var completed = 0, closed = 0;
      final logWait = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('jizhang/autobookkeeping_pending'),
        (call) async {
          if (call.method == 'getPending') return candidate;
          if (call.method == 'complete') completed++;
          return null;
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('jizhang/autobookkeeping_overlay'),
        (call) async {
          if (call.method == 'close') closed++;
          return null;
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('jizhang/autobookkeeping_logs'),
        (_) async {
          if (heldLogs) await logWait.future;
          return null;
        },
      );
      addTearDown(() async {
        logWait.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        for (final name in ['pending', 'overlay', 'logs']) {
          messenger.setMockMethodCallHandler(
            MethodChannel('jizhang/autobookkeeping_$name'),
            null,
          );
        }
        await tester.runAsync(database.close);
        await tester.pump(const Duration(seconds: 1));
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            databaseBootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            home: AutoBookkeepingConfirmPage(
              overlayMode: true,
              initialCandidate: PendingAutoBookkeepingCandidate.fromMap(
                candidate,
              ),
            ),
          ),
        ),
      );
      Future<void> progress(int frames) async {
        for (var i = 0; i < frames; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      await progress(15);
      await tester.tap(find.byKey(const ValueKey('quick-review-complete')));
      await progress(65);
      expect(find.text('完成中…'), findsNothing);
      expect(completed, 1);
      expect(closed, 1);
      final records = (await tester.runAsync(
        () => DriftTransactionRepository(database).getAll(),
      ))!;
      expect(records, hasLength(1));
      expect(records.single.id, 'auto-save-completion-regression');
      expect(
        (await tester.runAsync(
          () => database.accountDao.findById(SeedIds.wechatAccount),
        ))!.balanceInCents,
        balance - 1600,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  test('附加处理不返回时，报告已提交流水，账户仅扣款一次', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final attachments = _HeldAttachments();
    final service = QuickBookkeepingService(
      transactions,
      DriftAppSettingsRepository(database),
      attachments: attachments,
    );
    final balance = (await database.accountDao.findById(SeedIds.wechatAccount))!
        .balanceInCents;
    try {
      await service.save(
        QuickBookkeepingRequest(
          transactionId: 'auto-timeout-test',
          type: TransactionType.expense,
          amount: 25,
          accountId: SeedIds.wechatAccount,
          categoryId: 'expense-food',
          occurredAt: DateTime(2026, 10, 1),
        ),
      );
      fail('附加处理应超时并告知已提交');
    } on BookkeepingCommittedException catch (error) {
      expect(error.cause, isA<TimeoutException>());
      expect(error.records.single.id, 'auto-timeout-test');
    } finally {
      attachments.pending.complete();
    }
    expect(await transactions.getAll(), hasLength(1));
    expect(
      (await database.accountDao.findById(SeedIds.wechatAccount))!
          .balanceInCents,
      balance - 2500,
    );
  });

  testWidgets('完成回调成功返回但宿主未关闭时，停止转圈并禁止重复完成', (tester) async {
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded();
    final books = await DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    ).getForUser(SeedIds.localUser);
    final accounts = await DriftAccountRepository(database).getActive();
    final categories = await DriftCategoryRepository(database).getActive();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await database.close();
    });
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          databaseBootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          home: QuickAddSheet(
            reviewMode: true,
            reviewBooks: books,
            reviewAccounts: accounts,
            reviewCategories: categories,
            initialBookId: SeedIds.personalBook,
            initialAccountId: SeedIds.wechatAccount,
            initialCategoryId: 'expense-food',
            initialAmountInCents: 2500,
            onReviewComplete: (_) async {
              calls++;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-review-complete')));
    await tester.pumpAndSettle();
    expect(find.text('完成中…'), findsNothing);
    expect(find.text('已保存'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('quick-review-complete')),
          )
          .onPressed,
      isNull,
    );
    expect(calls, 1);
  });
}

class _HeldAttachments implements TransactionAttachmentRepository {
  final pending = Completer<void>();
  @override
  Future<void> replaceForTransaction({
    required String transactionId,
    required String bookId,
    required List<String> paths,
  }) => pending.future;
  @override
  Future<List<TransactionAttachment>> getForTransaction(
    String transactionId, {
    required String bookId,
  }) async => [];
  @override
  Stream<List<TransactionAttachment>> watchForTransaction(
    String transactionId, {
    required String bookId,
  }) => const Stream.empty();
}
