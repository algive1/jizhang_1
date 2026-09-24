import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/models/analysis.dart';
import '../../../core/models/transaction_record.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/asset_history.dart';
import '../../accounts/domain/asset_overview.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../investments/data/investment_repository.dart';
import '../../investments/domain/investment_portfolio.dart';
import '../../transactions/data/transactions_repository.dart';
import 'home_cards.dart';
import 'home_trend_chart.dart';

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
      includedInvestmentValueByCurrencyProvider,
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
      if (day == today) return currentCurrencyInvestment;
      final exact = investmentsByDay[InvestmentSnapshot.dateKey(day)];
      if (exact == 0) return 0;
      if (currentInvestmentByCurrency.isEmpty && investmentSnapshots.isEmpty) {
        return 0;
      }
      return exact;
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
      for (final point in snapshot.cashflowTrend)
        CashflowPoint(
          point.date,
          point.income,
          point.expense,
          totalAssets: totalAssetsAt(point.date),
        ),
    ];
    final points = _period == AnalysisPeriod.currentYear
        ? _monthlyPoints(dailyPoints)
        : dailyPoints;
    final selected = points.isEmpty
        ? 0
        : (_selected ?? ((points.length - 1) / 2).round())
              .clamp(0, math.max(0, points.length - 1))
              .toInt();
    final point = points.isEmpty ? null : points[selected];
    final year = _period == AnalysisPeriod.currentYear;

    double? latestAsset;
    for (final candidate in points.reversed) {
      if (candidate.totalAssets != null) {
        latestAsset = candidate.totalAssets;
        break;
      }
    }

    String dateLabel(CashflowPoint value) => year
        ? '${value.date.year}年${value.date.month}月'
        : '${value.date.month}月${value.date.day}日';

    return HomeSurface(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -2,
            top: -9,
            width: 48,
            height: 48,
            child: IgnorePointer(
              child: Opacity(
                opacity: .34,
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
                      '收支趋势',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: context.appPrimaryText,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    child: _TrendPeriodControl(
                      selected: _period,
                      onChanged: (period) => setState(() {
                        _period = period;
                        _selected = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              if (widget.amountHidden)
                Text(
                  '金额已隐藏',
                  key: const ValueKey('home-trend-value'),
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                _TrendSummaryRow(
                  expense: snapshot.totalExpense,
                  income: snapshot.totalIncome,
                  average: snapshot.range.dayCount <= 0
                      ? 0
                      : snapshot.totalExpense / snapshot.range.dayCount,
                  asset: latestAsset,
                  currency: trendCurrency,
                ),
              const SizedBox(height: 9),
              if (widget.amountHidden)
                SizedBox(
                  height: 104,
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
                  label: '收支趋势，${year ? "按月" : "按日"}查看',
                  value:
                      '${dateLabel(point!)}，支出 CNY ${MoneyFormatter.decimal(point.expense)}，收入 CNY ${MoneyFormatter.decimal(point.income)}，${point.totalAssets == null ? '资产暂无历史估值' : '资产 ${MoneyFormatter.decimal(point.totalAssets!)} $trendCurrency'}',
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
                  child: HomeTrendChart(
                    key: const ValueKey('home-trend-chart'),
                    points: points,
                    selected: selected,
                    year: year,
                    currency: trendCurrency,
                    onSelected: (index) => setState(() => _selected = index),
                  ),
                )
              else
                SizedBox(
                  height: 104,
                  child: Center(
                    child: Text(
                      '这段时间还没有流水',
                      style: TextStyle(
                        color: context.appSecondaryText,
                        fontSize: 11,
                      ),
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
    for (final point in daily) {
      final month = DateTime(point.date.year, point.date.month);
      final old = amounts[month];
      amounts[month] = (
        income: (old?.income ?? 0) + (point.income * 100).round(),
        expense: (old?.expense ?? 0) + (point.expense * 100).round(),
        totalAssets: point.totalAssets ?? old?.totalAssets,
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

class _TrendPeriodControl extends StatelessWidget {
  const _TrendPeriodControl({
    required this.selected,
    required this.onChanged,
  });

  final AnalysisPeriod selected;
  final ValueChanged<AnalysisPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (AnalysisPeriod.last7Days, '周'),
      (AnalysisPeriod.currentMonth, '月'),
      (AnalysisPeriod.currentYear, '年'),
    ];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.appSurfaceSoft.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                key: ValueKey('home-trend-${item.$1.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(item.$1),
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: item.$1 == selected
                        ? context.appPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: item.$1 == selected
                        ? [
                            BoxShadow(
                              color: context.appPrimary.withValues(alpha: .18),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      color: item.$1 == selected
                          ? Colors.white
                          : context.appSecondaryText,
                      fontSize: 10.5,
                      height: 1,
                      fontWeight: item.$1 == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendSummaryRow extends StatelessWidget {
  const _TrendSummaryRow({
    required this.expense,
    required this.income,
    required this.average,
    required this.asset,
    required this.currency,
  });

  final double expense;
  final double income;
  final double average;
  final double? asset;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final assetText = asset == null
        ? '--'
        : '${_currencySymbol(currency)}${MoneyFormatter.whole(asset!)}';
    return SizedBox(
      key: const ValueKey('home-trend-value'),
      width: double.infinity,
      height: 16,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            _metric(
              '支出 ¥${MoneyFormatter.whole(expense)}',
              homeTrendExpenseColor,
            ),
            _divider(context),
            _metric(
              '收入 ¥${MoneyFormatter.whole(income)}',
              homeTrendIncomeColor,
            ),
            _divider(context),
            _metric('资产 $assetText', homeTrendAssetColor),
            _divider(context),
            _metric(
              '日均 ¥${MoneyFormatter.whole(average)}',
              homeTrendExpenseColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String text, Color color) => Text(
    text,
    style: TextStyle(
      color: color,
      fontSize: 10.5,
      height: 1,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _divider(BuildContext context) => Container(
    width: 1,
    height: 13,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: context.appSecondaryText.withValues(alpha: .38),
  );
}

String _currencySymbol(String currency) => switch (currency.toUpperCase()) {
  'CNY' => '¥',
  'USD' => r'$',
  'EUR' => '€',
  'GBP' => '£',
  'JPY' => '¥',
  _ => '$currency ',
};
