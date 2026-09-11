import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/bookkeeping/application/local_file_opener.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/transactions/data/transaction_attachment_repository.dart';
import 'package:jizhang_app/features/transactions/domain/transaction_attachment.dart';
import 'package:jizhang_app/features/transactions/presentation/transaction_detail_page.dart';

void main() {
  test('attachment metadata parses paths and reports malformed entries', () {
    final metadata = TransactionAttachmentMetadata.fromJson(
      jsonEncode({
        'attachments': [
          '/documents/lunch.jpg',
          {'path': '/documents/receipt.pdf'},
          {'name': 'missing path'},
          3,
        ],
      }),
    );

    expect(metadata.attachments, hasLength(2));
    expect(metadata.attachments.first.name, 'lunch.jpg');
    expect(metadata.attachments.first.isImage, isTrue);
    expect(metadata.attachments.last.isPdf, isTrue);
    expect(metadata.hasMalformedAttachments, isTrue);
  });

  test(
    'local file opener distinguishes missing and platform outcomes',
    () async {
      const channel = MethodChannel('test/local_file_opener');
      final existing = File(
        '${Directory.systemTemp.path}/jizhang-attachment-test.txt',
      );
      await existing.writeAsString('attachment');
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (await existing.exists()) await existing.delete();
      });

      final opener = LocalFileOpener(channel: channel);
      expect(
        await opener.open('${existing.path}.missing'),
        LocalFileOpenResult.missing,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => true);
      expect(await opener.open(existing.path), LocalFileOpenResult.opened);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
      expect(await opener.open(existing.path), LocalFileOpenResult.noHandler);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(code: 'INVALID_FILE_PATH'),
          );
      expect(await opener.open(existing.path), LocalFileOpenResult.unsupported);
    },
  );

  test(
    'transaction repository detail lookup is book-scoped and hides deleted',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftTransactionRepository(database);
      final now = DateTime(2026, 9, 11, 10, 15);
      final transaction = TransactionRecord(
        id: 'detail-transaction',
        bookId: 'book-personal',
        type: TransactionType.expense,
        amount: 18,
        accountId: 'account-cash',
        categoryId: 'expense-food',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await repository.create(transaction);

      expect((await repository.getById(transaction.id))?.id, transaction.id);
      expect(
        await DriftTransactionRepository(
          database,
          bookId: 'book-missing',
        ).getById(transaction.id),
        isNull,
      );
      await repository.softDelete(transaction.id);
      expect(await repository.getById(transaction.id), isNull);
    },
  );

  testWidgets('detail page shows fields and missing attachment state', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 11, 10, 15);
    final transaction = TransactionRecord(
      id: 'detail-widget',
      bookId: 'book-personal',
      type: TransactionType.expense,
      amount: 35,
      accountId: 'account-cash',
      categoryId: 'expense-food',
      categoryName: '餐饮',
      merchant: '午餐',
      note: '和同事一起',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      metadataJson: jsonEncode({
        'attachments': ['/documents/missing-receipt.jpg'],
      }),
      syncStatus: SyncStatus.pending,
      createdBy: 'user-local',
    );
    final account = Account(
      id: 'account-cash',
      name: '现金',
      type: AccountType.cash,
      balance: 100,
      currency: 'CNY',
      icon: 'payments_outlined',
      color: 0xff000000,
      sortOrder: 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allAccountsProvider.overrideWith((ref) => Stream.value([account])),
          transactionAttachmentRepositoryProvider.overrideWithValue(
            _EmptyAttachmentRepository(),
          ),
        ],
        child: MaterialApp(
          home: TransactionDetailPage(
            transactionId: transaction.id,
            initialTransaction: transaction,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('交易详情'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('和同事一起'), findsOneWidget);
    expect(find.text('待同步'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    expect(find.text('文件未找到'), findsOneWidget);
    expect(find.text('重新添加'), findsOneWidget);
  });

  testWidgets(
    'detail page previews images and reports missing system handlers',
    (tester) async {
      const channel = MethodChannel('test/transaction_detail_file_opener');
      final image = File('${Directory.current.path}/assets/images/icon.png');
      final pdf = File('${Directory.current.path}/test/fixtures/receipt.pdf');
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);

      final now = DateTime(2026, 9, 11, 10, 15);
      final transaction = TransactionRecord(
        id: 'detail-preview-widget',
        bookId: 'book-personal',
        type: TransactionType.expense,
        amount: 35,
        accountId: 'account-cash',
        categoryId: 'expense-food',
        categoryName: '餐饮',
        merchant: '午餐',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        metadataJson: jsonEncode({
          'attachments': [image.path, pdf.path],
        }),
      );
      final account = Account(
        id: 'account-cash',
        name: '现金',
        type: AccountType.cash,
        balance: 100,
        currency: 'CNY',
        icon: 'payments_outlined',
        color: 0xff000000,
        sortOrder: 0,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allAccountsProvider.overrideWith((ref) => Stream.value([account])),
            transactionAttachmentRepositoryProvider.overrideWithValue(
              _EmptyAttachmentRepository(),
            ),
            localFileOpenerProvider.overrideWithValue(
              LocalFileOpener(channel: channel),
            ),
          ],
          child: MaterialApp(
            home: TransactionDetailPage(
              transactionId: transaction.id,
              initialTransaction: transaction,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      final imageTap = find.ancestor(
        of: find.byType(Image),
        matching: find.byType(InkWell),
      );
      expect(imageTap, findsOneWidget);
      await tester.tap(imageTap);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      Navigator.of(tester.element(find.byType(InteractiveViewer))).pop();
      await tester.pump();

      await tester.fling(find.byType(ListView), const Offset(0, -1000), 1000);
      await tester.pump();
      expect(find.byTooltip('打开 PDF 预览'), findsOneWidget);
      await tester.tap(find.byTooltip('打开 PDF 预览'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(
        find.text('没有可打开此文件的应用：${pdf.path.split('/').last}'),
        findsOneWidget,
      );
    },
  );
}

class _EmptyAttachmentRepository implements TransactionAttachmentRepository {
  @override
  Future<List<TransactionAttachment>> getForTransaction(
    String transactionId, {
    required String bookId,
  }) async => const [];

  @override
  Future<void> replaceForTransaction({
    required String transactionId,
    required String bookId,
    required List<String> paths,
  }) async {}

  @override
  Stream<List<TransactionAttachment>> watchForTransaction(
    String transactionId, {
    required String bookId,
  }) => Stream.value(const []);
}
