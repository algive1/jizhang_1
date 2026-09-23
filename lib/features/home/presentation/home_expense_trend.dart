import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/models/account.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/cashflow_trend_chart.dart';
import '../../../core/widgets/sliding_segmented_control.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/asset_history.dart';
import '../../accounts/domain/asset_overview.dart';
import '../../investments/data/investment_repository.dart';
import '../../investments/domain/investment_portfolio.dart';
import '../../transactions/data/transactions_repository.dart';
import 'home_cards.dart';
import '../../../app/theme/app_theme_tokens.dart';

class HomeExpenseTrend extends ConsumerStatefulWidget {
  const HomeExpenseTrend({super.key, this.amountHidden = false});
  final bool amountHidden;
  @override
  ConsumerState<HomeExpenseTrend> createState() => _HomeExpenseTrendState();
}

class _HomeExpenseTrendState extends ConsumerState<HomeExpenseTrend> {
  AnalysisPeriod _period = AnalysisPeriod.currentMonth;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref
        .watch(analysisRepositoryProvider)
        .analyze(period: _period);
    final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final transactions =
        ref.watch(allTransactionsProvider).value ?? const <TransactionRecord>[];
    final investmentSnapshots =
        ref.watch(investmentSnapshotsProvider(365)).value ??
        const <InvestmentSnapshot>[];
    final currentInvestmentByCurrency = ref.watch(
      investmentValueByCurrencyProvider,
    );
    final trendCurrency =
        AssetOverview.group(
          accounts,
          investmentByCurrency: currentInvestmentByCurrency,
        ).firstOrNull?.currency ??
        'CNY';
    final trendAccounts = accounts
        .where((account) => account.currency.toUpperCase() == trendCurrency)
        .toList(growable: false);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final assetHistory = AssetHistory(trendAccounts, transactions, now);
    final investmentsByDay = <String, double>{
      for (final item in investmentSnapshots)
        InvestmentSnapshot.dateKey(item.date): item.investmentValue,
    };
    final currentCurrencyInvestment =
        currentInvestmentByCurrency[trendCurrency] ?? 0;
    double? investmentAt(DateTime date) {
      final day = DateTime(date.year, date.month, date.day);
      if (day == today) {
        return currentCurrencyInvestment;
      }
      final key = InvestmentSnapshot.dateKey(day);
      final exact = investmentsByDay[key];
      if (exact == 0) return 0;
      if (currentInvestmentByCurrency.isEmpty && investmentSnapshots.isEmpty) {
        return 0;
      }
      return null;
    }

    int accountAssetsAt(DateTime date) =>
        trendAccounts.fold<int>(0, (cents, account) {
          final balance = assetHistory.balanceAt(date, accountId: account.id);
          return balance > 0 ? cents + (balance * 100).round() : cents;
        });
    int currentAccountAssets() => trendAccounts.fold<int>(
      0,
      (cents, account) =>
          account.balance > 0 ? cents + (account.balance * 100).round() : cents,
    );
    double? totalAssetsAt(DateTime date) {
      final day = DateTime(date.year, date.month, date.day);
      if (assetHistory.hasFutureRecords && day != today) return null;
      final investments = investmentAt(date);
      if (investments == null) return null;
      if (assetHistory.hasFutureRecords) {
        return currentAccountAssets() / 100 + investments;
      }
      final endOfDay = date
          .add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1));
      return accountAssetsAt(endOfDay) / 100 + investments;
    }

    final dailyPoints = [
      for (final p in snapshot.cashflowTrend)
        CashflowPoint(
          p.date,
          p.income,
          p.expense,
          totalAssets: totalAssetsAt(p.date),
        ),
    ];
    final points = _period == AnalysisPeriod.currentYear
        ? _monthlyPoints(dailyPoints)
        : dailyPoints;
    final selected = (_selected ?? points.length - 1)
        .clamp(0, math.max(0, points.length - 1))
        .toInt();
    final point = points.isEmpty ? null : points[selected];
    final year = _period == AnalysisPeriod.currentYear;
    String dateLabel(CashflowPoint p) => year
        ? '${p.date.year}年${p.date.month}月'
        : '${p.date.month}月${p.date.day}日';
    final average = snapshot.range.dayCount <= 0
        ? 0.0
        : snapshot.totalExpense / snapshot.range.dayCount;
    return HomeSurface(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            width: 70,
            height: 70,
            child: IgnorePointer(
              child: Opacity(
                opacity: .38,
                child: Image.asset(AppAssets.homeLeaves, fit: BoxFit.contain),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '收支与资产趋势',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.appPrimaryText,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 132,
                    child: SlidingSegmentedControl<AnalysisPeriod>(
                      compact: true,
                      colors: [context.appPrimary, context.appPrimary],
                      backgroundColor: context.appSurfaceSoft,
                      inactiveTextColor: context.appSecondaryText,
                      keyPrefix: 'home-trend',
                      items: const [
                        (AnalysisPeriod.last7Days, '周'),
                        (AnalysisPeriod.currentMonth, '月'),
                        (AnalysisPeriod.currentYear, '年'),
                      ],
                      selected: _period,
                      onChanged: (period) => setState(() {
                        _period = period;
                        _selected = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.amountHidden
                          ? '金额已隐藏'
                          : '本期累计支出 ¥${MoneyFormatter.whole(snapshot.totalExpense)}  · 日均 ¥${MoneyFormatter.whole(average)}',
                      key: const ValueKey('home-trend-value'),
                      style: TextStyle(
                        color: context.appPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (!widget.amountHidden && point != null) ...[
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    _TrendValue(
                      color: context.appPrimary,
                      label: '支出',
                      amount: point.expense,
                    ),
                    _TrendValue(
                      color: AppColors.income,
                      label: '收入',
                      amount: point.income,
                    ),
                    _TrendValue(
                      color: AppColors.warning,
                      label: '总资产',
                      amount: point.totalAssets,
                      currency: trendCurrency,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 5),
              if (widget.amountHidden)
                SizedBox(
                  height: 88,
                  child: Center(
                    child: Text(
                      '趋势金额已隐藏',
                      style: TextStyle(
                        color: context.appSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              else if (points.isNotEmpty)
                Semantics(
                  label: '收支与资产趋势，${year ? "按月" : "按日"}查看',
                  value:
                      '${dateLabel(point!)}，支出 CNY ${MoneyFormatter.decimal(point.expense)}，收入 CNY ${MoneyFormatter.decimal(point.income)}，${point.totalAssets == null ? '总资产暂无历史估值' : '总资产 ${MoneyFormatter.decimal(point.totalAssets!)} $trendCurrency'}',
                  increasedValue: selected < points.length - 1
                      ? dateLabel(points[selected + 1])
                      : null,
                  decreasedValue: selected > 0
                      ? dateLabel(points[selected - 1])
                      : null,
                  onIncrease: selected < points.length - 1
                      ? () => setState(() => _selected = selected + 1)
                      : null,
                  onDecrease: selected > 0
                      ? () => setState(() => _selected = selected - 1)
                      : null,
                  child: CashflowTrendChart(
                    key: const ValueKey('home-trend-chart'),
                    points: points,
                    selected: selected,
                    year: year,
                    height: 88,
                    showIncome: true,
                    showTotalAssets: true,
                    independentSeriesScales: true,
                    incomeColor: AppColors.income,
                    totalAssetsColor: AppColors.warning,
                    onSelected: (index) => setState(() => _selected = index),
                  ),
                ),
              if (snapshot.expenseCount == 0)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '这段时间还没有支出，记下一笔就能看到变化',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<CashflowPoint> _monthlyPoints(List<CashflowPoint> daily) {
    final amounts =
        <DateTime, ({int income, int expense, double? totalAssets})>{};
    for (final p in daily) {
      final month = DateTime(p.date.year, p.date.month);
      final old = amounts[month];
      amounts[month] = (
        income: (old?.income ?? 0) + (p.income * 100).round(),
        expense: (old?.expense ?? 0) + (p.expense * 100).round(),
        totalAssets: p.totalAssets,
      );
    }
    return amounts.entries
        .map(
          (entry) => CashflowPoint(
            entry.key,
            entry.value.income / 100,
            entry.value.expense / 100,
            totalAssets: entry.value.totalAssets,
          ),
        )
        .toList();
  }
}

class _TrendValue extends StatelessWidget {
  const _TrendValue({
    required this.color,
    required this.label,
    required this.amount,
    this.currency,
  });

  final Color color;
  final String label;
  final double? amount;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final value = amount == null
        ? '暂无历史估值'
        : currency == null
        ? '¥${MoneyFormatter.whole(amount!)}'
        : _formatCurrencyAmount(currency!, amount!);
    return Text(
      '$label $value',
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    );
  }
}

String _formatCurrencyAmount(String currency, double amount) {
  final symbol = switch (currency.toUpperCase()) {
    'CNY' => '¥',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    'JPY' => '¥',
    _ => '',
  };
  final formatted = MoneyFormatter.whole(amount);
  return symbol.isEmpty
      ? '$currency $formatted'
      : '$currency $symbol$formatted';
}
