import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/transactions/data/refund_service.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test(
    'refund atomically restores the account and source net amount',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftTransactionRepository(database);
      final now = DateTime(2026, 9, 12);
      final original = TransactionRecord(
        id: 'refund-source',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 500,
        accountId: SeedIds.bankAccount,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await repository.create(original);
      final service = RefundService(database, bookId: SeedIds.personalBook);
      final category = Category(
        id: 'income-refund',
        bookId: SeedIds.personalBook,
        name: '退款',
        icon: 'undo',
        type: CategoryType.income,
        sortOrder: 0,
        isDefault: true,
        isArchived: false,
      );

      final partial = await service.register(
        original: original,
        amount: 200,
        category: category,
        occurredAt: now,
      );
      expect(partial.relatedTransactionId, original.id);
      final afterPartial = await repository.getById(original.id);
      expect(afterPartial?.refundStatus, RefundStatus.partial);
      expect(afterPartial?.netExpenseAmount, 300);

      await service.register(
        original: afterPartial!,
        amount: 300,
        category: category,
        occurredAt: now,
      );
      final completed = await repository.getById(original.id);
      expect(completed?.refundStatus, RefundStatus.refunded);
      expect(completed?.netExpenseAmount, 0);
      expect(
        (await database.accountDao.findById(SeedIds.bankAccount))!
            .balanceInCents,
        0,
      );
    },
  );

  test(
    'editing and voiding a refund keeps the source relationship consistent',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftTransactionRepository(database);
      final now = DateTime(2026, 9, 12);
      final original = TransactionRecord(
        id: 'refund-edit-source',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 500,
        accountId: SeedIds.bankAccount,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await repository.create(original);
      final service = RefundService(database, bookId: SeedIds.personalBook);
      final category = Category(
        id: 'income-refund',
        bookId: SeedIds.personalBook,
        name: '退款',
        icon: 'undo',
        type: CategoryType.income,
        sortOrder: 0,
        isDefault: true,
        isArchived: false,
      );

      final refund = await service.register(
        original: original,
        amount: 200,
        category: category,
        occurredAt: now,
      );
      await service.updateRefund(refund: refund, amount: 100, occurredAt: now);
      final editedOriginal = await repository.getById(original.id);
      expect(editedOriginal?.refundStatus, RefundStatus.partial);
      expect(editedOriginal?.refundAmount, 100);
      expect(
        (await database.accountDao.findById(SeedIds.bankAccount))!
            .balanceInCents,
        -40000,
      );

      await service.voidRefund(refund);
      final restoredOriginal = await repository.getById(original.id);
      expect(restoredOriginal?.refundStatus, RefundStatus.none);
      expect(restoredOriginal?.refundAmount, isNull);
      expect(await repository.getById(refund.id), isNull);
      expect(
        (await database.accountDao.findById(SeedIds.bankAccount))!
            .balanceInCents,
        -50000,
      );
    },
  );
}
