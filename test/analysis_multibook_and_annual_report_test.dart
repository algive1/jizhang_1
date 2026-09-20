import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/analysis/domain/annual_financial_report_service.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';

void main() {
  test('combined analysis merges same named category across ledger books', () {
    const service = StatisticalAnalysisService();
    final now = DateTime(2026, 9, 19, 12);
    final snapshot = service.analyze(
      [
        _record(
          id: 'personal-food',
          bookId: 'book-personal',
          type: TransactionType.expense,
          amount: 100,
          categoryId: 'expense-food',
          categoryName: '餐饮',
          date: DateTime(2026, 9, 10),
        ),
        _record(
          id: 'family-food',
          bookId: 'book-family',
          type: TransactionType.expense,
          amount: 200,
          categoryId: 'book-family::family-expense-food',
          categoryName: '餐饮',
          date: DateTime(2026, 9, 11),
        ),
      ],
      now: now,
    );

    expect(snapshot.totalExpense, 300);
    expect(snapshot.expenseCategories, hasLength(1));
    expect(snapshot.expenseCategories.single.name, '餐饮');
    expect(snapshot.expenseCategories.single.amount, 300);
  });

  test('annual report keeps non-earned inflows out of income and spending', () {
    const service = AnnualFinancialReportService();
    final report = service.build(
      [
        _record(
          id: 'salary',
          bookId: 'book-personal',
          type: TransactionType.income,
          amount: 10000,
          categoryId: 'income-salary',
          categoryName: '工资',
          date: DateTime(2026, 1, 2),
        ),
        _record(
          id: 'refund',
          bookId: 'book-personal',
          type: TransactionType.refund,
          amount: 300,
          categoryId: 'other',
          categoryName: '退款',
          date: DateTime(2026, 1, 3),
        ),
        _record(
          id: 'borrow',
          bookId: 'book-personal',
          type: TransactionType.borrow,
          amount: 2000,
          categoryId: 'other',
          categoryName: '借入',
          date: DateTime(2026, 1, 4),
        ),
        _record(
          id: 'work',
          bookId: 'book-personal',
          type: TransactionType.expense,
          amount: 600,
          categoryId: 'expense-travel',
          categoryName: '出行',
          date: DateTime(2026, 1, 5),
        ).copyWith(
          reimbursementStatus: ReimbursementStatus.pending,
          reimbursementAmount: 500,
        ),
      ],
      year: 2026,
      now: DateTime(2026, 12, 31),
    );

    expect(report.totalIncome, 10000);
    expect(report.totalExpense, 100);
    expect(report.netCashflow, 9900);
  });

  test('annual report uses net refunded expense and prior-year comparison', () {
    const service = AnnualFinancialReportService();
    final refunded = _record(
      id: 'expense',
      bookId: 'book-personal',
      type: TransactionType.expense,
      amount: 600,
      categoryId: 'expense-food',
      categoryName: '餐饮',
      date: DateTime(2026, 1, 10),
    ).copyWith(
      refundStatus: RefundStatus.partial,
      refundAmount: 100,
    );
    final report = service.build(
      [
        _record(
          id: 'income',
          bookId: 'book-personal',
          type: TransactionType.income,
          amount: 1000,
          categoryId: 'income-salary',
          categoryName: '工资',
          date: DateTime(2026, 1, 2),
        ),
        refunded,
        _record(
          id: 'previous-expense',
          bookId: 'book-personal',
          type: TransactionType.expense,
          amount: 400,
          categoryId: 'expense-food',
          categoryName: '餐饮',
          date: DateTime(2025, 1, 10),
        ),
      ],
      year: 2026,
      now: DateTime(2026, 12, 31),
    );

    expect(report.totalIncome, 1000);
    expect(report.totalExpense, 500);
    expect(report.netCashflow, 500);
    expect(report.savingsRate, .5);
    expect(report.expenseYearOverYearPercent, 25);
    expect(report.topExpenseCategories.single.name, '餐饮');
    expect(report.topExpenseCategories.single.amount, 500);
  });
}

TransactionRecord _record({
  required String id,
  required String bookId,
  required TransactionType type,
  required double amount,
  required String categoryId,
  required String categoryName,
  required DateTime date,
}) {
  return TransactionRecord(
    id: id,
    bookId: bookId,
    type: type,
    amount: amount,
    categoryId: categoryId,
    categoryName: categoryName,
    accountId: '$bookId-account',
    occurredAt: date,
    createdAt: date,
    updatedAt: date,
  );
}
