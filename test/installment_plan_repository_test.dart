import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/installment_plan.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/installments/data/installment_plan_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test(
    'installment plan links to the original purchase and stores repayment math',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      final now = DateTime(2026, 9, 12);
      await transactions.create(
        TransactionRecord(
          id: 'macbook-purchase',
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 12000,
          accountId: SeedIds.cashAccount,
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final plans = DriftInstallmentPlanRepository(
        database,
        bookId: SeedIds.personalBook,
      );
      final plan = InstallmentPlan(
        id: 'macbook-plan',
        bookId: SeedIds.personalBook,
        name: 'MacBook 分期',
        originalTransactionId: 'macbook-purchase',
        totalAmount: 12000,
        totalPeriods: 12,
        currentPeriod: 4,
        principalPerPeriod: 1000,
        feePerPeriod: 26,
        startDate: now,
        dueDay: 15,
        creditAccountId: SeedIds.bankAccount,
        repaymentAccountId: SeedIds.cashAccount,
        remainingPrincipal: 8000,
        createdAt: now,
        updatedAt: now,
      );
      await plans.create(plan);
      expect((await plans.watchActive().first).single.monthlyPayment, 1026);
      await expectLater(
        transactions.softDelete('macbook-purchase'),
        throwsStateError,
      );
      expect(await transactions.getById('macbook-purchase'), isNotNull);
    },
  );

  test(
    'registering a repayment updates both sides and completes the plan',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      final now = DateTime(2026, 9, 12);
      await transactions.create(
        TransactionRecord(
          id: 'phone-purchase',
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 100,
          accountId: SeedIds.bankAccount,
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final plans = DriftInstallmentPlanRepository(
        database,
        bookId: SeedIds.personalBook,
      );
      await plans.create(
        InstallmentPlan(
          id: 'phone-plan',
          bookId: SeedIds.personalBook,
          name: '手机分期',
          originalTransactionId: 'phone-purchase',
          totalAmount: 100,
          totalPeriods: 2,
          currentPeriod: 0,
          principalPerPeriod: 50,
          feePerPeriod: 1,
          startDate: now,
          dueDay: 15,
          creditAccountId: SeedIds.bankAccount,
          repaymentAccountId: SeedIds.cashAccount,
          remainingPrincipal: 100,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final repayment = await plans.recordRepayment(
        'phone-plan',
        occurredAt: now,
      );
      expect(repayment.type, TransactionType.repayment);
      expect(repayment.amount, 51);
      expect(repayment.destinationAccountId, SeedIds.bankAccount);
      expect((await plans.getById('phone-plan'))?.currentPeriod, 1);
      expect(
        (await plans.getById('phone-plan'))?.status,
        InstallmentPlanStatus.active,
      );
      await expectLater(
        transactions.softDelete(repayment.id),
        throwsStateError,
      );

      final second = await plans.recordRepayment('phone-plan', occurredAt: now);
      expect(second.amount, 51);
      final completed = await plans.getById('phone-plan');
      expect(completed?.status, InstallmentPlanStatus.completed);
      expect(completed?.remainingPrincipal, 0);
      expect(
        (await database.accountDao.findById(SeedIds.cashAccount))!
            .balanceInCents,
        -10200,
      );
      expect(
        (await database.accountDao.findById(SeedIds.bankAccount))!
            .balanceInCents,
        200,
      );
    },
  );

  test('due repayment processor catches up periods idempotently', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final start = DateTime(2026, 9, 1);
    await transactions.create(
      TransactionRecord(
        id: 'camera-purchase',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 300,
        accountId: SeedIds.bankAccount,
        occurredAt: start,
        createdAt: start,
        updatedAt: start,
      ),
    );
    final plans = DriftInstallmentPlanRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    await plans.create(
      InstallmentPlan(
        id: 'camera-plan',
        bookId: SeedIds.personalBook,
        name: '相机分期',
        originalTransactionId: 'camera-purchase',
        totalAmount: 300,
        totalPeriods: 3,
        currentPeriod: 0,
        principalPerPeriod: 100,
        feePerPeriod: 2,
        startDate: start,
        dueDay: 1,
        creditAccountId: SeedIds.bankAccount,
        repaymentAccountId: SeedIds.cashAccount,
        remainingPrincipal: 300,
        createdAt: start,
        updatedAt: start,
      ),
    );

    expect(
      plans.dueDateFor((await plans.getById('camera-plan'))!, 1),
      DateTime(2026, 10, 1),
    );
    expect(await plans.processDueRepayments(now: DateTime(2026, 11, 5)), 2);
    expect((await plans.getById('camera-plan'))?.currentPeriod, 2);
    expect(
      (await transactions.getAll()).where(
        (item) => item.type == TransactionType.repayment,
      ),
      hasLength(2),
    );
    expect(await plans.processDueRepayments(now: DateTime(2026, 11, 5)), 0);
  });

  test('deleted original purchase cannot start an installment plan', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final now = DateTime(2026, 9, 12);
    await transactions.create(
      TransactionRecord(
        id: 'deleted-purchase',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 100,
        accountId: SeedIds.cashAccount,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await transactions.softDelete('deleted-purchase');
    final plans = DriftInstallmentPlanRepository(
      database,
      bookId: SeedIds.personalBook,
    );

    await expectLater(
      plans.create(
        InstallmentPlan(
          id: 'deleted-plan',
          bookId: SeedIds.personalBook,
          name: '已删除流水分期',
          originalTransactionId: 'deleted-purchase',
          totalAmount: 100,
          totalPeriods: 2,
          currentPeriod: 0,
          principalPerPeriod: 50,
          feePerPeriod: 0,
          startDate: now,
          dueDay: 15,
          creditAccountId: SeedIds.bankAccount,
          repaymentAccountId: SeedIds.cashAccount,
          remainingPrincipal: 100,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsArgumentError,
    );
  });
}
