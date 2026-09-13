import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/reimbursements/data/reimbursement_service.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test('reimbursement payment and source status commit atomically', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final now = DateTime(2026, 9, 12);
    final original = TransactionRecord(
      id: 'travel-expense',
      bookId: SeedIds.personalBook,
      type: TransactionType.expense,
      amount: 500,
      accountId: SeedIds.bankAccount,
      reimbursementStatus: ReimbursementStatus.pending,
      reimbursementAmount: 500,
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );
    await transactions.create(original);
    final account = Account(
      id: SeedIds.cashAccount,
      bookId: SeedIds.personalBook,
      name: '现金',
      type: AccountType.cash,
      balance: 0,
      currency: 'CNY',
      assetForm: AssetForm.cash,
      icon: 'payments_outlined',
      color: 0,
      sortOrder: 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    final category = Category(
      id: 'income-salary',
      bookId: SeedIds.personalBook,
      name: '工资',
      icon: 'work_outline',
      type: CategoryType.income,
      sortOrder: 0,
      isDefault: true,
      isArchived: false,
    );
    final service = ReimbursementService(
      database,
      bookId: SeedIds.personalBook,
    );
    final payment = await service.markReimbursed(
      original: original,
      account: account,
      category: category,
      occurredAt: now,
    );
    expect(payment.type, TransactionType.reimbursement);
    expect(payment.relatedTransactionId, original.id);
    expect(
      (await transactions.getById(original.id))?.reimbursementStatus,
      ReimbursementStatus.reimbursed,
    );
    expect((await transactions.getById(original.id))?.reimbursementAmount, 500);
    expect(
      (await transactions.getAll()).where(
        (item) => item.type == TransactionType.reimbursement,
      ),
      hasLength(1),
    );
  });

  test(
    'editing and voiding reimbursement payment restores source and balance',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      final now = DateTime(2026, 9, 12);
      final original = TransactionRecord(
        id: 'reimbursement-edit-source',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 500,
        accountId: SeedIds.bankAccount,
        reimbursementStatus: ReimbursementStatus.pending,
        reimbursementAmount: 500,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await transactions.create(original);
      final account = Account(
        id: SeedIds.cashAccount,
        bookId: SeedIds.personalBook,
        name: '现金',
        type: AccountType.cash,
        balance: 0,
        currency: 'CNY',
        assetForm: AssetForm.cash,
        icon: 'payments_outlined',
        color: 0,
        sortOrder: 0,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      final category = Category(
        id: 'income-salary',
        bookId: SeedIds.personalBook,
        name: '工资',
        icon: 'work_outline',
        type: CategoryType.income,
        sortOrder: 0,
        isDefault: true,
        isArchived: false,
      );
      final service = ReimbursementService(
        database,
        bookId: SeedIds.personalBook,
      );
      final payment = await service.markReimbursed(
        original: original,
        account: account,
        category: category,
        occurredAt: now,
      );
      await service.updatePayment(
        payment: payment,
        amount: 200,
        occurredAt: now,
      );
      expect(
        (await transactions.getById(original.id))?.reimbursementStatus,
        ReimbursementStatus.partial,
      );
      expect(
        (await transactions.getById(original.id))?.reimbursementAmount,
        200,
      );
      expect(
        (await database.accountDao.findById(SeedIds.cashAccount))!
            .balanceInCents,
        20000,
      );

      await service.voidPayment(payment);
      final restored = await transactions.getById(original.id);
      expect(restored?.reimbursementStatus, ReimbursementStatus.none);
      expect(restored?.reimbursementAmount, isNull);
      expect(await transactions.getById(payment.id), isNull);
      expect(
        (await database.accountDao.findById(SeedIds.cashAccount))!
            .balanceInCents,
        0,
      );
    },
  );
}
