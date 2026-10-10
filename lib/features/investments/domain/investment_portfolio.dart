import 'dart:math' as math;

import 'investment_asset.dart';
import 'investment_holding.dart';
import 'investment_quote.dart';

/// One investment class inside the overview / category cards.
class InvestmentCategorySummary {
  const InvestmentCategorySummary({
    required this.type,
    required this.value,
    required this.cost,
    required this.holdingCount,
    this.currency = 'CNY',
    this.hasMissingQuote = false,
  });

  final InvestmentAssetType type;
  final String currency;
  final bool hasMissingQuote;

  /// Current market value of everything held in this class.
  final double value;

  /// Total cost basis of the same positions.
  final double cost;

  final int holdingCount;

  double get profit => value - cost;

  /// Null when there is no comparable cost base, so the UI can render
  /// “暂无可比基数” instead of a fabricated 0%.
  double? get profitPercent =>
      !hasMissingQuote && cost > 0 ? profit / cost * 100 : null;

  bool get isEmpty => holdingCount == 0;
}

/// A valued position: the holding plus the quote used to value it.
class ValuedHolding {
  const ValuedHolding({required this.holding, required this.price, this.quote});

  final InvestmentHolding holding;
  final double price;
  final InvestmentQuote? quote;

  double get marketValue => holding.marketValue(price);
  double get cost => holding.cost;
  double get profit => holding.profit(price);
  double? get profitPercent =>
      quote == null ? null : holding.profitPercent(price);

  /// Today's move for this position, derived from the quote when available.
  double get todayProfit =>
      quote == null ? 0 : quote!.change * holding.quantity;

  bool get isStale => quote?.isStale ?? false;
}

/// The whole-portfolio summary backing the 投资管理总览 page.
///
/// Total invested value is deliberately named `investmentValue`, never
/// “总资产”, so it can never be confused with the net worth shown on the
/// existing 资产总览 page.
class InvestmentPortfolio {
  const InvestmentPortfolio({
    required this.currency,
    required this.positions,
    required this.categories,
  });

  final String currency;
  final List<ValuedHolding> positions;

  /// All four classes, always present and in canonical order.
  final List<InvestmentCategorySummary> categories;

  static const empty = InvestmentPortfolio(
    currency: 'CNY',
    positions: [],
    categories: [
      InvestmentCategorySummary(
        type: InvestmentAssetType.stock,
        value: 0,
        cost: 0,
        holdingCount: 0,
      ),
      InvestmentCategorySummary(
        type: InvestmentAssetType.fund,
        value: 0,
        cost: 0,
        holdingCount: 0,
      ),
      InvestmentCategorySummary(
        type: InvestmentAssetType.bond,
        value: 0,
        cost: 0,
        holdingCount: 0,
      ),
      InvestmentCategorySummary(
        type: InvestmentAssetType.crypto,
        value: 0,
        cost: 0,
        holdingCount: 0,
      ),
    ],
  );

  bool get isEmpty => positions.isEmpty;

  /// Positions keep their original currencies; sums never silently convert.
  Iterable<ValuedHolding> get currencyPositions => positions.where(
    (position) =>
        position.holding.asset.currency.toUpperCase() == currency.toUpperCase(),
  );
  List<String> get currencies =>
      (positions
          .map((p) => p.holding.asset.currency.toUpperCase())
          .toSet()
          .toList()
        ..sort());
  bool get hasMissingQuote => currencyPositions.any((p) => p.quote == null);
  bool get hasTodayChange =>
      currencyPositions.isNotEmpty &&
      currencyPositions.every(
        (p) =>
            p.holding.asset.priceSource == PriceSource.market &&
            p.quote != null &&
            !p.isStale,
      );
  InvestmentPortfolio inCurrency(String value) => buildPortfolio(
    holdings: positions
        .where(
          (p) => p.holding.asset.currency.toUpperCase() == value.toUpperCase(),
        )
        .map((p) => p.holding)
        .toList(),
    quotes: {
      for (final p in positions)
        if (p.quote != null) p.holding.asset.quoteKey: p.quote!,
    },
    currency: value.toUpperCase(),
  );

  double get investmentValue =>
      currencyPositions.fold(0, (sum, position) => sum + position.marketValue);

  double get cost =>
      currencyPositions.fold(0, (sum, position) => sum + position.cost);

  double get totalProfit => investmentValue - cost;

  /// Null when nothing has a comparable cost base yet.
  double? get totalProfitPercent {
    final base = cost;
    return base > 0 ? totalProfit / base * 100 : null;
  }

  double get todayProfit =>
      currencyPositions.fold(0, (sum, position) => sum + position.todayProfit);

  /// Today's return is measured against yesterday's close, which is the
  /// current value minus today's move.
  double? get todayProfitPercent {
    final base = investmentValue - todayProfit;
    return base > 0 ? todayProfit / base * 100 : null;
  }

  /// True when any position had to fall back to stale cached data.
  bool get hasStaleQuote => positions.any((position) => position.isStale);

  InvestmentCategorySummary categoryOf(InvestmentAssetType type) =>
      categories.firstWhere(
        (category) => category.type == type,
        orElse: () => InvestmentCategorySummary(
          type: type,
          currency: currency,
          value: 0,
          cost: 0,
          holdingCount: 0,
        ),
      );

  /// Rebuilds a portfolio scoped to one class; used by 分类持仓页 so the
  /// summary card reuses exactly the same maths as the overview.
  InvestmentPortfolio scopedTo(InvestmentAssetType type) {
    final scoped = positions
        .where(
          (position) =>
              position.holding.asset.type == type &&
              position.holding.asset.currency.toUpperCase() ==
                  currency.toUpperCase(),
        )
        .toList(growable: false);
    return InvestmentPortfolio(
      currency: currency,
      positions: scoped,
      categories: [
        InvestmentCategorySummary(
          type: type,
          currency: currency,
          value: scoped.fold(0, (sum, position) => sum + position.marketValue),
          cost: scoped.fold(0, (sum, position) => sum + position.cost),
          holdingCount: scoped.length,
          hasMissingQuote: scoped.any((p) => p.quote == null),
        ),
      ],
    );
  }
}

/// Assembles a [InvestmentPortfolio] from holdings and the quotes that priced
/// them. Pure and synchronous so it is directly unit-testable.
///
/// A holding with no quote falls back to its own average cost, which keeps
/// the invested amount visible during a market-data outage instead of
/// reporting a fake zero.
InvestmentPortfolio buildPortfolio({
  required List<InvestmentHolding> holdings,
  required Map<String, InvestmentQuote> quotes,
  String currency = 'CNY',
  DateTime? now,
}) {
  final positions = <ValuedHolding>[];
  for (final holding in holdings) {
    if (holding.isArchived) continue;
    final candidate =
        quotes[holding.asset.quoteKey] ?? quotes[holding.asset.symbol];
    final quote =
        candidate?.currency.toUpperCase() ==
            holding.asset.currency.toUpperCase()
        ? candidate
        : null;
    positions.add(
      ValuedHolding(
        holding: holding,
        price: quote?.price ?? holding.averageCost,
        quote: quote,
      ),
    );
  }
  positions.sort((a, b) => b.marketValue.compareTo(a.marketValue));

  final categories = <InvestmentCategorySummary>[];
  for (final type in InvestmentAssetType.values) {
    final scoped = positions
        .where(
          (position) =>
              position.holding.asset.type == type &&
              position.holding.asset.currency.toUpperCase() ==
                  currency.toUpperCase(),
        )
        .toList(growable: false);
    categories.add(
      InvestmentCategorySummary(
        type: type,
        currency: currency,
        value: scoped.fold(0, (sum, position) => sum + position.marketValue),
        cost: scoped.fold(0, (sum, position) => sum + position.cost),
        holdingCount: scoped.length,
        hasMissingQuote: scoped.any((p) => p.quote == null),
      ),
    );
  }

  return InvestmentPortfolio(
    currency: currency,
    positions: positions,
    categories: categories,
  );
}

/// A once-per-day portfolio snapshot. Foreground opening and the daily finance
/// scheduler both call the same idempotent writer; only fresh market quotes or
/// explicit manual valuations are persisted.
class InvestmentSnapshot {
  const InvestmentSnapshot({
    required this.date,
    required this.investmentValue,
    required this.stockValue,
    required this.fundValue,
    required this.bondValue,
    required this.cryptoValue,
  });

  final DateTime date;
  final double investmentValue;
  final double stockValue;
  final double fundValue;
  final double bondValue;
  final double cryptoValue;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  double valueOf(InvestmentAssetType type) => switch (type) {
    InvestmentAssetType.stock => stockValue,
    InvestmentAssetType.fund => fundValue,
    InvestmentAssetType.bond => bondValue,
    InvestmentAssetType.crypto => cryptoValue,
  };
}

/// Turns stored snapshots into a chart timeline, dropping future dates and
/// keeping only the requested window.
class InvestmentTrend {
  const InvestmentTrend(this.points);

  final List<InvestmentHistoryPoint> points;

  bool get isEmpty => points.length < 2;

  static InvestmentTrend from(
    List<InvestmentSnapshot> snapshots, {
    required DateTime now,
    int days = 30,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: math.max(1, days) - 1));
    final byDate = <String, InvestmentSnapshot>{
      for (final snapshot in snapshots)
        InvestmentSnapshot.dateKey(snapshot.date): snapshot,
    };
    final sorted = byDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final windowed = sorted
        .where(
          (snapshot) =>
              !snapshot.date.isBefore(start) && !snapshot.date.isAfter(today),
        )
        .toList(growable: false);
    return InvestmentTrend([
      for (final snapshot in windowed)
        InvestmentHistoryPoint(
          DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day),
          snapshot.investmentValue,
        ),
    ]);
  }
}
