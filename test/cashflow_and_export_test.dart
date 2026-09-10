import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';
import 'package:jizhang_app/features/data_export/domain/transaction_csv.dart';

void main() {
  test('cashflow totals, daily trend and categories agree per currency', () {
    final records = [
      _record('salary', TransactionType.income, 500.01),
      _record('food1', TransactionType.expense, 12.34),
      _record('food2', TransactionType.expense, 0.01),
      _record('transfer', TransactionType.transfer, 30),
      _record('balance', TransactionType.adjustment, -10),
      _record('foreign', TransactionType.expense, 888, currency: 'USD'),
      _record(
        'deleted',
        TransactionType.expense,
        900,
      ).copyWith(deletedAt: DateTime(2026, 9, 8)),
    ];
    final snapshot = const StatisticalAnalysisService().analyze(
      records,
      now: DateTime(2026, 9, 8, 12),
    );
    expect(snapshot.totalIncome, 500.01);
    expect(snapshot.totalExpense, 12.35);
    expect(snapshot.netCashflow, closeTo(487.66, 0.000001));
    expect(snapshot.incomeCount, 1);
    expect(snapshot.expenseCount, 2);
    expect(snapshot.cashflowTrend, hasLength(8));
    expect(snapshot.cashflowTrend[6].income, 500.01);
    expect(snapshot.cashflowTrend[6].expense, 12.35);
    expect(snapshot.cashflowTrend[7].expense, 0);
    expect(snapshot.incomeCategories.single.amount, 500.01);
    expect(snapshot.expenseCategories.single.amount, 12.35);
    expect(snapshot.expenseCategories.single.count, 2);
    final foreign = const StatisticalAnalysisService().analyze(
      records,
      now: DateTime(2026, 9, 8, 12),
      currency: 'USD',
    );
    expect(foreign.totalExpense, 888);
    expect(foreign.totalIncome, 0);
  });

  test('CSV preserves Chinese, cents, signed adjustments, archived accounts and text safely', () {
    final csv = TransactionCsv.encode(
      [
        _record(
          'safe',
          TransactionType.expense,
          12.34,
        ).copyWith(merchant: '商户,"名称"', note: '\t=HYPERLINK("x")\n备注'),
        _record('calibration', TransactionType.adjustment, -20.05),
        _record(
          'deleted',
          TransactionType.expense,
          1,
        ).copyWith(deletedAt: DateTime(2026)),
      ],
      [
        Account(
          id: 'cash',
          name: '已归档账户',
          type: AccountType.cash,
          balance: 0,
          currency: 'CNY',
          icon: 'wallet',
          color: 0,
          sortOrder: 0,
          isArchived: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('"12.34"'));
    expect(csv, contains('"-20.05"'));
    expect(csv, contains('"已归档账户"'));
    expect(csv, contains('"商户,""名称"""'));
    expect(csv, contains('"\'\t=HYPERLINK(""x"")\n备注"'));
    expect(csv, isNot(contains('"deleted"')));
  });
}

TransactionRecord _record(
  String id,
  TransactionType type,
  double amount, {
  String currency = 'CNY',
}) => TransactionRecord(
  id: id,
  bookId: 'book',
  type: type,
  amount: amount,
  currency: currency,
  accountId: 'cash',
  destinationAccountId: type == TransactionType.transfer ? 'bank' : null,
  categoryId: type == TransactionType.income ? 'salary' : 'food',
  categoryName: type == TransactionType.income ? '工资' : '餐饮',
  occurredAt: DateTime(2026, 9, 7, 12),
  createdAt: DateTime(2026, 9, 7),
  updatedAt: DateTime(2026, 9, 7),
);
