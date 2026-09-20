import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/intelligence/domain/financial_truth_service.dart';

void main() {
  const truth = FinancialTruthService();
  final now = DateTime(2026, 9, 20, 12);

  test('golden ledger truth separates income, consumption and cash movement', () {
    final rows = [
      _row('salary', TransactionType.income, 10000, now),
      _row('meal', TransactionType.expense, 100, now),
      _row('taxi', TransactionType.expense, 500, now).copyWith(
        reimbursementStatus: ReimbursementStatus.pending,
        reimbursementAmount: 400,
      ),
      _row('shopping', TransactionType.expense, 500, now).copyWith(
        refundStatus: RefundStatus.partial,
        refundAmount: 200,
      ),
      _row('refund', TransactionType.refund, 200, now),
      _row('reimbursement', TransactionType.reimbursement, 400, now),
      _row('borrow', TransactionType.borrow, 1000, now),
      _row('repayment', TransactionType.repayment, 300, now),
      _row('lend', TransactionType.lend, 700, now),
      _row('asset-buy', TransactionType.assetPurchase, 1500, now),
      _row('asset-sell', TransactionType.assetSale, 600, now),
      _row('transfer', TransactionType.transfer, 800, now),
      _row(
        'future',
        TransactionType.expense,
        999,
        now.add(const Duration(days: 1)),
      ),
      _row('usd', TransactionType.expense, 999, now, currency: 'USD'),
    ];

    final summary = truth.summarize(
      rows,
      start: DateTime(2026, 9),
      endExclusive: DateTime(2026, 10),
      currency: 'CNY',
      now: now,
    );

    expect(summary.earnedIncome, 10000);
    expect(summary.personalConsumption, 500);
    expect(summary.incomeCount, 1);
    expect(summary.consumptionCount, 3);
    expect(summary.externalCashIn, 12200);
    expect(summary.externalCashOut, 3600);
    expect(summary.externalCashflow, 8600);
    expect(summary.disposableDelta, 9500);
  });

  test('golden imported multi-source ledger produces one stable financial truth', () {
    final wallet = _row(
      'wallet',
      TransactionType.expense,
      128,
      now,
    ).copyWith(
      categoryId: 'expense-food',
      merchant: '餐厅',
    );
    final bankDuplicate = _row(
      'bank-duplicate',
      TransactionType.expense,
      128,
      now.add(const Duration(minutes: 1)),
    );
    final workTaxi = _row(
      'work-taxi',
      TransactionType.expense,
      80,
      now,
    ).copyWith(
      reimbursementStatus: ReimbursementStatus.pending,
      reimbursementAmount: 60,
    );
    final returnedShopping = _row(
      'shopping',
      TransactionType.expense,
      300,
      now,
    ).copyWith(
      refundStatus: RefundStatus.partial,
      refundAmount: 100,
    );
    final rows = [
      _row('salary', TransactionType.income, 6000, now),
      wallet,
      bankDuplicate,
      workTaxi,
      returnedShopping,
      _row('refund-receipt', TransactionType.refund, 100, now),
      _row(
        'reimbursement-receipt',
        TransactionType.reimbursement,
        60,
        now,
      ),
      _row('internal-transfer', TransactionType.transfer, 500, now),
      _row('credit-repayment', TransactionType.repayment, 900, now),
    ];
    final suppressed = truth.confirmedDuplicateSuppressionIds(
      records: rows,
      confirmedEventTransactionIds: {
        'event-wallet-bank': ['wallet', 'bank-duplicate'],
      },
    );
    final summary = truth.summarize(
      rows,
      start: DateTime(2026, 9),
      endExclusive: DateTime(2026, 10),
      currency: 'CNY',
      now: now.add(const Duration(hours: 1)),
      excludedTransactionIds: suppressed,
    );

    expect(suppressed, {'bank-duplicate'});
    expect(summary.earnedIncome, 6000);
    expect(summary.personalConsumption, 348);
    expect(summary.consumptionCount, 3);
    expect(summary.disposableDelta, 5652);
    expect(summary.externalCashIn, 6160);
    expect(summary.externalCashOut, 1408);
  });

  test('confirmed economic events count exactly once using the richer record', () {
    final imported = _row(
      'imported',
      TransactionType.expense,
      88,
      now,
    ).copyWith(
      categoryId: 'food',
      merchant: '餐厅',
    );
    final bank = _row(
      'bank',
      TransactionType.expense,
      88,
      now,
    ).copyWith();
    final suppressed = truth.confirmedDuplicateSuppressionIds(
      records: [bank, imported],
      confirmedEventTransactionIds: {
        'event-1': ['bank', 'imported'],
      },
    );

    expect(suppressed, {'bank'});
    final summary = truth.summarize(
      [bank, imported],
      start: DateTime(2026, 9),
      endExclusive: DateTime(2026, 10),
      currency: 'CNY',
      now: now,
      excludedTransactionIds: suppressed,
    );
    expect(summary.personalConsumption, 88);
    expect(summary.consumptionCount, 1);
  });

  test('analysis normalization drops fully reimbursable rows and rewrites partials', () {
    final rows = [
      _row('full', TransactionType.expense, 300, now).copyWith(
        reimbursementStatus: ReimbursementStatus.pending,
        reimbursementAmount: 300,
      ),
      _row('partial', TransactionType.expense, 500, now).copyWith(
        reimbursementStatus: ReimbursementStatus.pending,
        reimbursementAmount: 350,
      ),
      _row('income', TransactionType.income, 1000, now),
    ];

    final normalized = truth.normalizeForAnalysis(
      rows,
      currency: 'CNY',
      now: now,
    );

    expect(normalized.map((item) => item.id), ['partial', 'income']);
    expect(normalized.first.amount, 150);
    expect(normalized.first.reimbursementStatus, ReimbursementStatus.none);
  });
}

TransactionRecord _row(
  String id,
  TransactionType type,
  double amount,
  DateTime occurredAt, {
  String currency = 'CNY',
}) => TransactionRecord(
  id: id,
  bookId: 'book-personal',
  type: type,
  amount: amount,
  currency: currency,
  accountId: 'cash',
  occurredAt: occurredAt,
  createdAt: occurredAt,
  updatedAt: occurredAt,
);
