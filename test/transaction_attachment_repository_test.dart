import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/transactions/data/transaction_attachment_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test(
    'attachment records are book-scoped and replace with soft deletion',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      final attachments = DriftTransactionAttachmentRepository(database);
      final transaction = _transaction('attachment-transaction');
      await transactions.create(transaction);

      await attachments.replaceForTransaction(
        transactionId: transaction.id,
        bookId: transaction.bookId,
        paths: const ['/documents/receipt.pdf', '/documents/lunch.jpg'],
      );

      final firstRead = await attachments.getForTransaction(
        transaction.id,
        bookId: transaction.bookId,
      );
      expect(firstRead.map((item) => item.name), ['receipt.pdf', 'lunch.jpg']);
      expect(firstRead.map((item) => item.resolvedMimeType), [
        'application/pdf',
        'image/jpeg',
      ]);
      expect(firstRead.every((item) => item.id != null), isTrue);

      await attachments.replaceForTransaction(
        transactionId: transaction.id,
        bookId: transaction.bookId,
        paths: const ['/documents/lunch.jpg', '/documents/updated.png'],
      );
      expect(
        (await attachments.getForTransaction(
          transaction.id,
          bookId: transaction.bookId,
        )).map((item) => item.path),
        ['/documents/lunch.jpg', '/documents/updated.png'],
      );
      final allRecords = await database.transactionAttachmentDao
          .getForTransaction(
            transaction.id,
            bookId: transaction.bookId,
            includeDeleted: true,
          );
      expect(allRecords, hasLength(3));
      expect(allRecords.where((item) => item.deletedAt != null), hasLength(1));

      expect(
        await attachments.getForTransaction(
          transaction.id,
          bookId: 'book-not-visible',
        ),
        isEmpty,
      );
    },
  );

  test('schema 10 migration moves legacy metadata attachments once', () async {
    final directory = await Directory.systemTemp.createTemp('attachment-v10-');
    final file = File('${directory.path}/database.sqlite');
    final database = AppDatabase.forTesting(NativeDatabase(file));
    await DatabaseSeeder(database).seedIfNeeded();
    final transaction = _transaction(
      'legacy-attachment-transaction',
      metadataJson: jsonEncode({
        'tags': ['午餐'],
        'attachments': [
          '/documents/receipt.pdf',
          {'path': '/documents/lunch.jpg'},
          '/documents/receipt.pdf',
          {'name': 'invalid'},
        ],
      }),
    );
    await DriftTransactionRepository(database).create(transaction);
    await database.close();

    final oldDatabase = sqlite.sqlite3.open(file.path);
    oldDatabase.execute(
      'DROP INDEX IF EXISTS idx_transaction_attachments_transaction',
    );
    oldDatabase.execute(
      'DROP INDEX IF EXISTS idx_transaction_attachments_book',
    );
    oldDatabase.execute('DROP TABLE transaction_attachments');
    oldDatabase.userVersion = 10;
    oldDatabase.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(() async {
      await upgraded.close();
      await directory.delete(recursive: true);
    });

    final migrated = await DriftTransactionAttachmentRepository(upgraded)
        .getForTransaction(transaction.id, bookId: transaction.bookId);
    expect(migrated.map((item) => item.path), [
      '/documents/receipt.pdf',
      '/documents/lunch.jpg',
    ]);
    final migratedTransaction = await DriftTransactionRepository(upgraded)
        .getById(transaction.id);
    expect(migratedTransaction, isNotNull);
    expect(migratedTransaction!.metadataJson, contains('午餐'));
    expect(migratedTransaction.metadataJson, contains('attachments'));
    expect(upgraded.schemaVersion, 11);

    await upgraded.close();
    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(reopened.close);
    expect(
      await DriftTransactionAttachmentRepository(reopened)
          .getForTransaction(transaction.id, bookId: transaction.bookId),
      hasLength(2),
    );
  });
}

TransactionRecord _transaction(String id, {String? metadataJson}) {
  final now = DateTime(2026, 9, 11, 12);
  return TransactionRecord(
    id: id,
    bookId: 'book-personal',
    type: TransactionType.expense,
    amount: 12,
    accountId: SeedIds.cashAccount,
    categoryId: 'expense-food',
    occurredAt: now,
    createdAt: now,
    updatedAt: now,
    metadataJson: metadataJson,
  );
}
