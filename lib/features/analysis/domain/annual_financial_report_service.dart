import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/transaction_record.dart';

enum FinancialHealthStatus { positive, watch, attention, insufficient }

class AnnualMonthSummary {
  const AnnualMonthSummary({
    required this.month,
    required this.income,
    required this.expense,
  });

  final int month;
  final double income;
  final double expense;
  double get net => income - expense;
  bool get hasActivity => income != 0 || expense != 0;
}

class AnnualCategorySummary {
  const AnnualCategorySummary({
    required this.name,
    required this.amount,
    required this.count,
  });

  final String name;
  final double amount;
  final int count;
}

class FinancialHealthCheck {
  const FinancialHealthCheck({
    required this.title,
    required this.value,
    required this.description,
    required this.status,
  });

  final String title;
  final String value;
  final String description;
  final FinancialHealthStatus status;
}

class AnnualFinancialReport {
  const AnnualFinancialReport({
    required this.year,
    required this.currency,
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashflow,
    required this.savingsRate,
    required this.months,
    required this.topExpenseCategories,
    required this.checks,
    required this.activeMonths,
    required this.positiveCashflowMonths,
    required this.previousYearIncome,
    required this.previousYearExpense,
  });

  final int year;
  final String currency;
  final double totalIncome;
  final double totalExpense;
  final double netCashflow;
  final double? savingsRate;
  final List<AnnualMonthSummary> months;
  final List<AnnualCategorySummary> topExpenseCategories;
  final List<FinancialHealthCheck> checks;
  final int activeMonths;
  final int positiveCashflowMonths;
  final double previousYearIncome;
  final double previousYearExpense;

  double? get expenseYearOverYearPercent => previousYearExpense <= 0
      ? null
      : (totalExpense - previousYearExpense) / previousYearExpense * 100;

  double? get incomeYearOverYearPercent => previousYearIncome <= 0
      ? null
      : (totalIncome - previousYearIncome) / previousYearIncome * 100;
}

class AnnualFinancialReportService {
  const AnnualFinancialReportService();

  AnnualFinancialReport build(
    List<TransactionRecord> transactions, {
    required int year,
    String currency = 'CNY',
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final normalizedCurrency = currency.toUpperCase();
    final usable = transactions.where(
      (item) =>
          item.deletedAt == null &&
          item.currency.toUpperCase() == normalizedCurrency &&
          !item.occurredAt.isAfter(clock),
    );

    final current = usable.where((item) => item.occurredAt.year == year).toList();
    final previous = usable
        .where((item) => item.occurredAt.year == year - 1)
        .toList();

    final months = [
      for (var month = 1; month <= 12; month++)
        AnnualMonthSummary(
          month: month,
          income: _income(
            current.where((item) => item.occurredAt.month == month),
          ),
          expense: _expense(
            current.where((item) => item.occurredAt.month == month),
          ),
        ),
    ];
    final totalIncome = _income(current);
    final totalExpense = _expense(current);
    final netCashflow = totalIncome - totalExpense;
    final savingsRate = totalIncome <= 0 ? null : netCashflow / totalIncome;
    final active = months.where((item) => item.hasActivity).toList();
    final positiveMonths = active.where((item) => item.net >= 0).length;

    final categoryGroups = <String, List<TransactionRecord>>{};
    for (final item in current.where((item) => item.isExpense)) {
      final name = item.categoryName?.trim();
      categoryGroups
          .putIfAbsent(
            name == null || name.isEmpty ? '未分类' : name,
            () => <TransactionRecord>[],
          )
          .add(item);
    }
    final categories = categoryGroups.entries
        .map(
          (entry) => AnnualCategorySummary(
            name: entry.key,
            amount: _expense(entry.value),
            count: entry.value.length,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final checks = <FinancialHealthCheck>[
      FinancialHealthCheck(
        title: '年度现金流',
        value: _signedMoney(netCashflow),
        description: netCashflow >= 0
            ? '全年收入覆盖了支出，年度现金流为正。'
            : '全年支出高于收入，需要关注持续性现金流缺口。',
        status: netCashflow >= 0
            ? FinancialHealthStatus.positive
            : FinancialHealthStatus.attention,
      ),
      _savingsCheck(savingsRate),
      _positiveMonthCheck(active.length, positiveMonths),
      _stabilityCheck(active.map((item) => item.expense).where((v) => v > 0)),
    ];

    return AnnualFinancialReport(
      year: year,
      currency: normalizedCurrency,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netCashflow: netCashflow,
      savingsRate: savingsRate,
      months: List.unmodifiable(months),
      topExpenseCategories: List.unmodifiable(categories.take(8)),
      checks: List.unmodifiable(checks),
      activeMonths: active.length,
      positiveCashflowMonths: positiveMonths,
      previousYearIncome: _income(previous),
      previousYearExpense: _expense(previous),
    );
  }

  FinancialHealthCheck _savingsCheck(double? rate) {
    if (rate == null) {
      return const FinancialHealthCheck(
        title: '结余率',
        value: '数据不足',
        description: '本年度没有可用于计算结余率的收入记录。',
        status: FinancialHealthStatus.insufficient,
      );
    }
    final percent = '${(rate * 100).toStringAsFixed(1)}%';
    if (rate >= .2) {
      return FinancialHealthCheck(
        title: '结余率',
        value: percent,
        description: '年度结余占收入比例较高，现金流缓冲相对充足。',
        status: FinancialHealthStatus.positive,
      );
    }
    if (rate >= 0) {
      return FinancialHealthCheck(
        title: '结余率',
        value: percent,
        description: '年度仍有结余，但可继续关注固定支出和非必要支出占比。',
        status: FinancialHealthStatus.watch,
      );
    }
    return FinancialHealthCheck(
      title: '结余率',
      value: percent,
      description: '年度支出超过收入，建议优先定位持续性支出来源。',
      status: FinancialHealthStatus.attention,
    );
  }

  FinancialHealthCheck _positiveMonthCheck(int active, int positive) {
    if (active < 2) {
      return FinancialHealthCheck(
        title: '月度现金流稳定性',
        value: '$positive / $active 月',
        description: '有效月份不足，暂不判断月度现金流稳定性。',
        status: FinancialHealthStatus.insufficient,
      );
    }
    final ratio = positive / active;
    final status = ratio >= .67
        ? FinancialHealthStatus.positive
        : ratio >= .5
        ? FinancialHealthStatus.watch
        : FinancialHealthStatus.attention;
    return FinancialHealthCheck(
      title: '月度现金流稳定性',
      value: '$positive / $active 月为正',
      description: status == FinancialHealthStatus.positive
          ? '多数有记录月份保持正现金流。'
          : status == FinancialHealthStatus.watch
          ? '正负现金流月份接近，建议关注波动较大的月份。'
          : '多数有记录月份为负现金流，需要检查长期支出压力。',
      status: status,
    );
  }

  FinancialHealthCheck _stabilityCheck(Iterable<double> values) {
    final expenses = values.toList();
    if (expenses.length < 3) {
      return const FinancialHealthCheck(
        title: '支出波动',
        value: '数据不足',
        description: '至少需要 3 个有支出的月份才能判断年度支出波动。',
        status: FinancialHealthStatus.insufficient,
      );
    }
    final mean = expenses.reduce((a, b) => a + b) / expenses.length;
    final variance = expenses
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        expenses.length;
    final coefficient = mean == 0 ? 0 : math.sqrt(variance) / mean;
    final status = coefficient <= .3
        ? FinancialHealthStatus.positive
        : coefficient <= .6
        ? FinancialHealthStatus.watch
        : FinancialHealthStatus.attention;
    return FinancialHealthCheck(
      title: '支出波动',
      value: '${(coefficient * 100).toStringAsFixed(0)}%',
      description: status == FinancialHealthStatus.positive
          ? '月度支出相对稳定。'
          : status == FinancialHealthStatus.watch
          ? '部分月份支出波动较明显，可结合大额支出查看原因。'
          : '月度支出波动较大，建议定位异常月份和一次性大额支出。',
      status: status,
    );
  }

  double _income(Iterable<TransactionRecord> items) =>
      items.where((item) => item.isIncome).fold<int>(
            0,
            (sum, item) => sum + (item.amount * 100).round(),
          ) /
      100;

  double _expense(Iterable<TransactionRecord> items) =>
      items.where((item) => item.isExpense).fold<int>(
            0,
            (sum, item) => sum + (item.netExpenseAmount * 100).round(),
          ) /
      100;

  String _signedMoney(double value) =>
      '${value < 0 ? '-' : '+'}¥${value.abs().toStringAsFixed(2)}';
}

final annualFinancialReportServiceProvider = Provider(
  (ref) => const AnnualFinancialReportService(),
);
