import 'dart:math' as math;

import '../domain/investment_asset.dart';
import '../domain/investment_quote.dart';

/// Market-data contract. Nothing outside a provider may talk to a vendor API,
/// so swapping the mock for a real HTTP source never touches a widget.
///
/// Every method is batched where the vendor allows it: [getQuotes] takes a list
/// so 50 holdings cost one request instead of 50.
abstract interface class MarketDataProvider {
  /// Human-readable source name, shown in the 行情状态 label.
  String get name;

  /// Search by name, code or symbol.
  Future<List<MarketSearchResult>> search(
    String query, {
    InvestmentAssetType? type,
    int limit = 20,
  });

  Future<InvestmentQuote?> getQuote(String symbol, InvestmentAssetType type);

  Future<Map<String, InvestmentQuote>> getQuotes(
    List<({String symbol, InvestmentAssetType type})> requests,
  );

  Future<List<InvestmentHistoryPoint>> getHistory(
    String symbol,
    InvestmentAssetType type,
    InvestmentRange range,
  );
}

/// One search hit, carrying enough detail to render the result row and to
/// pre-fill the add form.
class MarketSearchResult {
  const MarketSearchResult({
    required this.symbol,
    required this.name,
    required this.type,
    required this.price,
    required this.change,
    required this.changePercent,
    this.currency = 'CNY',
    this.market,
  });

  final String symbol;
  final String name;
  final InvestmentAssetType type;
  final double price;
  final double change;
  final double changePercent;
  final String currency;
  final String? market;

  InvestmentQuote toQuote(DateTime timestamp) => InvestmentQuote(
    symbol: symbol,
    name: name,
    price: price,
    change: change,
    changePercent: changePercent,
    currency: currency,
    timestamp: timestamp,
    type: type,
  );
}

class _Instrument {
  const _Instrument({
    required this.type,
    required this.symbol,
    required this.name,
    required this.basePrice,
    this.market,
  });

  final InvestmentAssetType type;
  final String symbol;
  final String name;
  final double basePrice;
  final String? market;
}

/// Deterministic offline market data.
///
/// The same symbol always yields the same price for the same calendar day,
/// which keeps the mock idempotent: a widget test, a manual walkthrough and a
/// repeated page open all agree, and average-cost / profit maths stays
/// reproducible. Prices move day to day so trend charts are not flat.
///
/// Replace with `HttpMarketDataProvider` when a quote vendor is configured.
/// The UI and the repository depend only on [MarketDataProvider].
class MockMarketDataProvider implements MarketDataProvider {
  MockMarketDataProvider({
    DateTime Function()? clock,
    List<({String symbol, double price})> overrides = const [],
  }) : _clock = clock ?? DateTime.now,
       _overrides = {
         for (final override in overrides) override.symbol: override.price,
       };

  final DateTime Function() _clock;
  final Map<String, double> _overrides;

  /// Set to true to exercise the “行情更新失败” / stale-quote path in manual
  /// QA and widget tests.
  bool simulateFailure = false;

  @override
  String get name => '模拟行情';

  @override
  Future<List<MarketSearchResult>> search(
    String query, {
    InvestmentAssetType? type,
    int limit = 20,
  }) async {
    if (simulateFailure) throw const MarketDataException('行情服务暂时不可用');
    final needle = query.trim().toLowerCase();
    final now = _clock();
    final matches = <_Instrument>[];
    for (final instrument in _catalog) {
      if (type != null && instrument.type != type) continue;
      if (needle.isNotEmpty &&
          !instrument.symbol.toLowerCase().contains(needle) &&
          !instrument.name.toLowerCase().contains(needle)) {
        continue;
      }
      matches.add(instrument);
      if (matches.length >= limit) break;
    }
    return [
      for (final instrument in matches)
        _resultFor(instrument, now),
    ];
  }

  @override
  Future<InvestmentQuote?> getQuote(
    String symbol,
    InvestmentAssetType type,
  ) async {
    final quotes = await getQuotes([(symbol: symbol, type: type)]);
    return quotes[_quoteKey(symbol, type)];
  }

  @override
  Future<Map<String, InvestmentQuote>> getQuotes(
    List<({String symbol, InvestmentAssetType type})> requests,
  ) async {
    if (simulateFailure) throw const MarketDataException('行情服务暂时不可用');
    final now = _clock();
    final quotes = <String, InvestmentQuote>{};
    for (final request in requests) {
      final instrument =
          _find(request.symbol, request.type) ??
          // An unknown symbol still gets a stable synthetic quote so a
          // manually added market asset is never left without a price.
          _Instrument(
            type: request.type,
            symbol: request.symbol,
            name: request.symbol,
            basePrice: 100,
            market: request.type.market,
          );
      quotes[_quoteKey(request.symbol, request.type)] = _quoteFor(
        instrument,
        now,
      );
    }
    return quotes;
  }

  @override
  Future<List<InvestmentHistoryPoint>> getHistory(
    String symbol,
    InvestmentAssetType type,
    InvestmentRange range,
  ) async {
    if (simulateFailure) throw const MarketDataException('行情服务暂时不可用');
    final now = _clock();
    final instrument = _find(symbol, type);
    final base = instrument?.basePrice ?? 100;
    // A year of dailies is too dense for a phone chart; sample weekly.
    final step = range.days > 120 ? 7 : 1;
    final points = <InvestmentHistoryPoint>[];
    for (var offset = range.days; offset >= 0; offset -= step) {
      final date = DateTime(now.year, now.month, now.day - offset);
      points.add(InvestmentHistoryPoint(date, _priceAt(base, symbol, date)));
    }
    return points;
  }

  String _quoteKey(String symbol, InvestmentAssetType type) =>
      'quote:${type.name}:${type.market}:$symbol';

  _Instrument? _find(String symbol, InvestmentAssetType type) {
    final upper = symbol.toUpperCase();
    for (final instrument in _catalog) {
      if (instrument.type != type) continue;
      if (instrument.symbol.toUpperCase() == upper) return instrument;
    }
    return null;
  }

  MarketSearchResult _resultFor(_Instrument instrument, DateTime now) {
    final quote = _quoteFor(instrument, now);
    return MarketSearchResult(
      symbol: quote.symbol,
      name: quote.name,
      type: instrument.type,
      price: quote.price,
      change: quote.change,
      changePercent: quote.changePercent,
      currency: quote.currency,
      market: instrument.market,
    );
  }

  InvestmentQuote _quoteFor(_Instrument instrument, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final price = _priceAt(instrument.basePrice, instrument.symbol, today);
    final previous = _priceAt(
      instrument.basePrice,
      instrument.symbol,
      today.subtract(const Duration(days: 1)),
    );
    final change = price - previous;
    return InvestmentQuote(
      symbol: instrument.symbol,
      name: instrument.name,
      price: price,
      change: change,
      changePercent: previous == 0 ? 0 : change / previous * 100,
      currency: instrument.type == InvestmentAssetType.crypto ? 'USD' : 'CNY',
      timestamp: now,
      type: instrument.type,
    );
  }

  /// Stable pseudo-random walk: a per-symbol phase plus a per-day drift, so a
  /// given (symbol, date) pair is always priced identically.
  double _priceAt(double base, String symbol, DateTime date) {
    final override = _overrides[symbol.toUpperCase()] ?? _overrides[symbol];
    if (override != null) return override;
    final seed = _hash(symbol);
    final dayNumber = date.difference(DateTime(2024)).inDays;
    final phase = (seed % 1000) / 1000 * math.pi * 2;
    final drift =
        math.sin(dayNumber / 37 + phase) * 0.12 +
        math.sin(dayNumber / 11 + phase * 1.7) * 0.05;
    final value = base * (1 + drift);
    return double.parse(value.toStringAsFixed(value >= 100 ? 2 : 4));
  }

  int _hash(String value) {
    var hash = 7;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}

/// Raised when a provider cannot serve a request. Callers keep the previously
/// cached quote and surface a stale-data label instead of clearing the UI.
class MarketDataException implements Exception {
  const MarketDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Offline catalogue used by the mock provider. Real instruments with real
/// codes so search, add and detail flows behave like production.
const _catalog = <_Instrument>[
  // ---------------------------------------------------------------- stocks
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '600519',
    name: '贵州茅台',
    basePrice: 1680,
  ),
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '000858',
    name: '五粮液',
    basePrice: 138,
  ),
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '601318',
    name: '中国平安',
    basePrice: 52,
  ),
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '600036',
    name: '招商银行',
    basePrice: 38,
  ),
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '000001',
    name: '平安银行',
    basePrice: 11,
  ),
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '300750',
    name: '宁德时代',
    basePrice: 210,
  ),
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '002594',
    name: '比亚迪',
    basePrice: 245,
  ),
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '601899',
    name: '紫金矿业',
    basePrice: 16,
  ),
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '600900',
    name: '长江电力',
    basePrice: 27,
  ),
  _Instrument(
    type: InvestmentAssetType.stock,
    symbol: '000651',
    name: '格力电器',
    basePrice: 41,
  ),

  // ----------------------------------------------------------------- funds
  _Instrument(
    type: InvestmentAssetType.fund,
    symbol: '510300',
    name: '沪深300ETF',
    basePrice: 3.85,
  ),
  _Instrument(
    type: InvestmentAssetType.fund,
    symbol: '510500',
    name: '中证500ETF',
    basePrice: 5.62,
  ),
  _Instrument(
    type: InvestmentAssetType.fund,
    symbol: '159915',
    name: '创业板ETF',
    basePrice: 2.11,
  ),
  _Instrument(
    type: InvestmentAssetType.fund,
    symbol: '110022',
    name: '易方达消费行业',
    basePrice: 2.74,
  ),
  _Instrument(
    type: InvestmentAssetType.fund,
    symbol: '161725',
    name: '招商中证白酒',
    basePrice: 0.92,
  ),
  _Instrument(
    type: InvestmentAssetType.fund,
    symbol: '005827',
    name: '易方达蓝筹精选',
    basePrice: 2.35,
  ),
  _Instrument(
    type: InvestmentAssetType.fund,
    symbol: '270042',
    name: '广发纳斯达克100',
    basePrice: 4.18,
  ),
  _Instrument(
    type: InvestmentAssetType.fund,
    symbol: '000961',
    name: '天弘沪深300',
    basePrice: 1.63,
  ),

  // ----------------------------------------------------------------- bonds
  _Instrument(
    type: InvestmentAssetType.bond,
    symbol: '230023',
    name: '23附息国债10',
    basePrice: 100,
  ),
  _Instrument(
    type: InvestmentAssetType.bond,
    symbol: '240001',
    name: '24特别国债01',
    basePrice: 100.35,
  ),
  _Instrument(
    type: InvestmentAssetType.bond,
    symbol: '220008',
    name: '22国债08',
    basePrice: 100.12,
  ),
  _Instrument(
    type: InvestmentAssetType.bond,
    symbol: '240401',
    name: '24农发债01',
    basePrice: 100.56,
  ),
  _Instrument(
    type: InvestmentAssetType.bond,
    symbol: '240301',
    name: '24进出债01',
    basePrice: 100.48,
  ),
  _Instrument(
    type: InvestmentAssetType.bond,
    symbol: '123456',
    name: '宁银转债',
    basePrice: 103.5,
  ),
  _Instrument(
    type: InvestmentAssetType.bond,
    symbol: 'MTN001',
    name: '中铁建MTN001',
    basePrice: 100.6,
  ),

  // ---------------------------------------------------------------- crypto
  _Instrument(
    type: InvestmentAssetType.crypto,
    symbol: 'BTC',
    name: '比特币',
    basePrice: 68000,
  ),
  _Instrument(
    type: InvestmentAssetType.crypto,
    symbol: 'ETH',
    name: '以太坊',
    basePrice: 3200,
  ),
  _Instrument(
    type: InvestmentAssetType.crypto,
    symbol: 'SOL',
    name: 'Solana',
    basePrice: 148,
  ),
  _Instrument(
    type: InvestmentAssetType.crypto,
    symbol: 'BNB',
    name: '币安币',
    basePrice: 580,
  ),
  _Instrument(
    type: InvestmentAssetType.crypto,
    symbol: 'USDT',
    name: '泰达币',
    basePrice: 7.19,
  ),
];
