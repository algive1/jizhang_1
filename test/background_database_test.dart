import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test(
    'background file database seeds, streams writes and reopens persistently',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'jizhang-background-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/ledger.sqlite');
      final database = AppDatabase.forTesting(
        NativeDatabase.createInBackground(file),
      );
      try {
        await DatabaseSeeder(database).seedIfNeeded();
        final repository = DriftTransactionRepository(
          database,
          bookId: SeedIds.personalBook,
        );
        final events = StreamIterator(repository.watchAll());
        try {
          expect(await events.moveNext(), isTrue);
          expect(events.current, isEmpty);
          final now = DateTime.now();
          await repository.create(
            TransactionRecord(
              id: 'background-expense',
              bookId: SeedIds.personalBook,
              type: TransactionType.expense,
              amount: 12.5,
              accountId: scopedSeedId(
                SeedIds.personalBook,
                SeedIds.cashAccount,
              ),
              occurredAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
          expect(
            await events.moveNext().timeout(const Duration(seconds: 5)),
            isTrue,
          );
          expect(events.current.single.amount, 12.5);
          await repository.update(events.current.single.copyWith(amount: 18));
          expect(
            await events.moveNext().timeout(const Duration(seconds: 5)),
            isTrue,
          );
          expect(events.current.single.amount, 18);
        } finally {
          await events.cancel();
        }
      } finally {
        await database.close();
      }
      final reopened = AppDatabase.forTesting(
        NativeDatabase.createInBackground(file),
      );
      try {
        final repository = DriftTransactionRepository(
          reopened,
          bookId: SeedIds.personalBook,
        );
        expect((await repository.getAll()).single.amount, 18);
        await repository.softDelete('background-expense');
        expect(await repository.getAll(), isEmpty);
      } finally {
        await reopened.close();
      }
    },
  );
}
