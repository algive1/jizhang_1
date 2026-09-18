import 'investment_asset.dart';

/// A normalised market quote. Every provider — mock today, a real HTTP source
/// later — must return this shape so no widget ever depends on a vendor
/// payload.
class InvestmentQuote {
  const InvestmentQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    this.currency = 'CNY',
    required this.timestamp,
    this.type,
    this.isStale = false,
  });

  final String symbol;
  final String name;
  final double price;

  /// Absolute change against the previous close.
  final double change;

  /// Change in percent, e.g. `0.38` means +0.38%.
  final double changePercent;

  final String currency;
  final DateTime timestamp;
  final InvestmentAssetType? type;

  /// True when the value came from the cache after a failed refresh. The UI
  /// keeps showing it and labels it “行情更新失败”.
  final bool isStale;

  String get cacheKey => type == null
      ? 'quote:$symbol'
      : 'quote:${type!.name}:${type!.market}:$symbol';

  InvestmentQuote copyWith({bool? isStale, DateTime? timestamp}) =>
      InvestmentQuote(
        symbol: symbol,
        name: name,
        price: price,
        change: change,
        changePercent: changePercent,
        currency: currency,
        timestamp: timestamp ?? this.timestamp,
        type: type,
        isStale: isStale ?? this.isStale,
      );
}

/// One sample on a price/net-value trend line.
class InvestmentHistoryPoint {
  const InvestmentHistoryPoint(this.date, this.value);

  final DateTime date;
  final double value;
}

/// Supported trend ranges for a single holding.
enum InvestmentRange {
  month('近1月', 30),
  quarter('近3月', 90),
  year('近1年', 365),
  all('全部', 1095);

  const InvestmentRange(this.label, this.days);

  final String label;
  final int days;
}

/// Supported ranges for the whole-portfolio trend.
enum PortfolioRange {
  month('近30天', 30),
  year('近1年', 365),
  all('全部', 1095);

  const PortfolioRange(this.label, this.days);

  final String label;
  final int days;
}
