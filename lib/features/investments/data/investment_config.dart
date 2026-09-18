import '../domain/investment_asset.dart';

/// Single place for every investment-module tuning value.
///
/// Quote TTLs intentionally live here rather than inside the provider or the
/// cache, so changing a refresh policy never means touching business code.
abstract final class InvestmentConfig {
  /// How long a cached quote stays usable, per asset class. A fund NAV only
  /// changes once a day, so it is cached far longer than a crypto price.
  static const tradingTtl = <InvestmentAssetType, Duration>{
    InvestmentAssetType.stock: Duration(minutes: 4),
    InvestmentAssetType.fund: Duration(minutes: 60),
    InvestmentAssetType.bond: Duration(minutes: 20),
    InvestmentAssetType.crypto: Duration(minutes: 2),
  };

  /// Outside mainland trading hours an equity/bond price cannot move, so the
  /// cached value is kept much longer instead of re-fetching a flat quote.
  static const closedMarketTtl = <InvestmentAssetType, Duration>{
    InvestmentAssetType.stock: Duration(hours: 2),
    InvestmentAssetType.fund: Duration(hours: 12),
    InvestmentAssetType.bond: Duration(hours: 6),
    InvestmentAssetType.crypto: Duration(minutes: 2),
  };

  static Duration ttlFor(InvestmentAssetType type, {DateTime? now}) {
    final at = now ?? DateTime.now();
    // Crypto never closes; everything else falls back to the closed-market TTL
    // on weekends and outside 09:30–15:00 China time.
    if (type == InvestmentAssetType.crypto) return tradingTtl[type]!;
    return isTradingHours(at)
        ? tradingTtl[type]!
        : closedMarketTtl[type]!;
  }

  /// Mainland A-share session: Mon–Fri, 09:30–11:30 and 13:00–15:00.
  static bool isTradingHours(DateTime at) {
    if (at.weekday == DateTime.saturday || at.weekday == DateTime.sunday) {
      return false;
    }
    final minutes = at.hour * 60 + at.minute;
    const morningOpen = 9 * 60 + 30;
    const morningClose = 11 * 60 + 30;
    const afternoonOpen = 13 * 60;
    const afternoonClose = 15 * 60;
    return (minutes >= morningOpen && minutes <= morningClose) ||
        (minutes >= afternoonOpen && minutes <= afternoonClose);
  }

  /// Number of days the overview trend can show, per range.
  static const portfolioSnapshotDays = 365;

  /// Never request more symbols in one provider call than this.
  static const maxBatchSymbols = 50;

  /// Default holding account when the user picks none.
  static const defaultCurrency = 'CNY';
}
