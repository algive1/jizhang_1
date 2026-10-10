import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/insights/domain/insight_month_summary.dart';

TransactionRecord row(
  String id,
  DateTime at,
  double amount, {
  TransactionType type = TransactionType.expense,
  String currency = 'CNY',
}) => TransactionRecord(
  id: id,
  bookId: 'book-personal',
  type: type,
  amount: amount,
  currency: currency,
  accountId: 'cash',
  occurredAt: at,
  createdAt: at,
  updatedAt: at,
);

void main() {
  test('month-to-date compares the same elapsed calendar window and net personal spending', () {
    final now = DateTime(2026, 10, 10, 12);
    final summary = InsightMonthSummary.from([
      row(
        'current',
        DateTime(2026, 10, 1),
        100,
      ).copyWith(refundAmount: 20, refundStatus: RefundStatus.partial),
      row('reimbursed', DateTime(2026, 10, 2), 200).copyWith(
        reimbursementAmount: 200,
        reimbursementStatus: ReimbursementStatus.reimbursed,
      ),
      row('previous', DateTime(2026, 9, 10, 11), 40),
      row('previous-later', DateTime(2026, 9, 10, 13), 100),
      row('future', DateTime(2026, 10, 10, 13), 100),
      row('foreign', DateTime(2026, 10, 1), 1000, currency: 'USD'),
      row(
        'investment',
        DateTime(2026, 10, 1),
        1000,
        type: TransactionType.assetPurchase,
      ),
      row(
        'transfer',
        DateTime(2026, 10, 1),
        1000,
        type: TransactionType.transfer,
      ),
      row('deleted', DateTime(2026, 10, 1), 1000).copyWith(deletedAt: now),
    ], now);
    expect(summary.spent, 80);
    expect(summary.previousSpent, 40);
    expect(summary.count, 1);
    expect(summary.changePercent, 100);
  });
  test('missing baseline is unknown; a shorter prior month is capped at its last day', () {
    final at = DateTime(2026, 3, 31, 12);
    expect(
      InsightMonthSummary.from([row('current', at, 10)], at).changePercent,
      isNull,
    );
    final summary = InsightMonthSummary.from([
      row('last-day', DateTime(2026, 2, 28, 23), 10),
      row('current', at, 20),
    ], at);
    expect(summary.previousSpent, 10);
    expect(summary.changePercent, 100);
  });
}
