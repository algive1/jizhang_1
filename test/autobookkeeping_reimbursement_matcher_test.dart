import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_reimbursement_matcher.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test('reimbursement matches one explicitly pending expense by exact amount', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final spentAt = DateTime(2026, 9, 10, 9);
    final receivedAt = DateTime(2026, 9, 20, 9);
    await repository.create(
      TransactionRecord(
        id: 'pending-reimbursement',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 128,
        accountId: SeedIds.bankAccount,
        merchant: '出差酒店',
        reimbursementStatus: ReimbursementStatus.pending,
        reimbursementAmount: 128,
        occurredAt: spentAt,
        createdAt: spentAt,
        updatedAt: spentAt,
      ),
    );

    final matcher = AutoBookkeepingReimbursementMatcher(repository);
    final matched = await matcher.findOriginal(
      candidate: PendingAutoBookkeepingCandidate(
        fingerprint: 'reimbursement-128',
        amountInCents: 12800,
        merchant: '公司报销',
        paymentMethod: '银行卡',
        timestamp: receivedAt,
        sourceApp: 'UNIONPAY',
        scene: 'UNIONPAY_REIMBURSEMENT_SUCCESS',
        transactionType: 'REIMBURSEMENT',
      ),
    );

    expect(matched?.id, 'pending-reimbursement');
  });

  test('ordinary expenses are never guessed as reimbursement sources', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final spentAt = DateTime(2026, 9, 10, 9);
    await repository.create(
      TransactionRecord(
        id: 'ordinary-expense',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 128,
        accountId: SeedIds.bankAccount,
        merchant: '普通消费',
        occurredAt: spentAt,
        createdAt: spentAt,
        updatedAt: spentAt,
      ),
    );

    final matched = await AutoBookkeepingReimbursementMatcher(repository)
        .findOriginal(
          candidate: PendingAutoBookkeepingCandidate(
            fingerprint: 'ordinary-not-match',
            amountInCents: 12800,
            merchant: '公司报销',
            paymentMethod: '银行卡',
            timestamp: DateTime(2026, 9, 20, 9),
            sourceApp: 'UNIONPAY',
            scene: 'UNIONPAY_REIMBURSEMENT_SUCCESS',
            transactionType: 'REIMBURSEMENT',
          ),
        );

    expect(matched, isNull);
  });

  test('ambiguous same-amount pending expenses are not auto-linked', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final spentAt = DateTime(2026, 9, 10, 9);
    for (final id in ['pending-a', 'pending-b']) {
      await repository.create(
        TransactionRecord(
          id: id,
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 88,
          accountId: SeedIds.bankAccount,
          reimbursementStatus: ReimbursementStatus.pending,
          reimbursementAmount: 88,
          occurredAt: spentAt,
          createdAt: spentAt,
          updatedAt: spentAt,
        ),
      );
    }

    final matched = await AutoBookkeepingReimbursementMatcher(repository)
        .findOriginal(
          candidate: PendingAutoBookkeepingCandidate(
            fingerprint: 'ambiguous-88',
            amountInCents: 8800,
            merchant: '公司报销',
            paymentMethod: '银行卡',
            timestamp: DateTime(2026, 9, 20, 9),
            sourceApp: 'UNIONPAY',
            scene: 'UNIONPAY_REIMBURSEMENT_SUCCESS',
            transactionType: 'REIMBURSEMENT',
          ),
        );

    expect(matched, isNull);
  });

  test('partial reimbursement matches only the exact remaining amount', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final spentAt = DateTime(2026, 9, 1, 9);
    await repository.create(
      TransactionRecord(
        id: 'partial-source',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 500,
        accountId: SeedIds.bankAccount,
        reimbursementStatus: ReimbursementStatus.partial,
        reimbursementAmount: 200,
        occurredAt: spentAt,
        createdAt: spentAt,
        updatedAt: spentAt,
      ),
    );
    final matcher = AutoBookkeepingReimbursementMatcher(repository);

    Future<TransactionRecord?> match(int cents) => matcher.findOriginal(
      candidate: PendingAutoBookkeepingCandidate(
        fingerprint: 'partial-$cents',
        amountInCents: cents,
        merchant: '公司报销',
        paymentMethod: '银行卡',
        timestamp: DateTime(2026, 9, 20, 9),
        sourceApp: 'UNIONPAY',
        scene: 'UNIONPAY_REIMBURSEMENT_SUCCESS',
        transactionType: 'REIMBURSEMENT',
      ),
    );

    expect((await match(30000))?.id, 'partial-source');
    expect(await match(20000), isNull);
  });
}
