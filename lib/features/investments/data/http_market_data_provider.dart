import '../../sharing/data/shared_api.dart';
import '../domain/investment_asset.dart';
import '../domain/investment_quote.dart';
import 'market_data_provider.dart';

/// Production client for the app's own market proxy.
///
/// Vendor keys and Redis credentials stay on the server. This class only knows
/// the normalized /api/v1/market contract.
class HttpMarketDataProvider implements MarketDataProvider {
  HttpMarketDataProvider(this._api);

  final SharedApi _api;

  @override
  String get name => '实时行情';

  @override
  Future<List<MarketSearchResult>> search(
    String query, {
    InvestmentAssetType? type,
    int limit = 20,
  }) => _guard(() async {
    final params = <String, String>{
      'q': query.trim(),
      'limit': '$limit',
      if (type != null) 'type': type.name,
    };
    final uri = Uri(queryParameters: params);
    final data = await _api.request('/market/search?${uri.query}');
    final raw = data['results'];
    if (raw is! List) throw const FormatException('行情搜索响应缺少 results');
    return raw.map(_searchResult).toList(growable: false);
  });

  @override
  Future<InvestmentQuote?> getQuote(
    String symbol,
    InvestmentAssetType type,
  ) async {
    final values = await getQuotes([(symbol: symbol, type: type)]);
    return values[_key(symbol, type)];
  }

  @override
  Future<Map<String, InvestmentQuote>> getQuotes(
    List<({String symbol, InvestmentAssetType type})> requests,
  ) => _guard(() async {
    if (requests.isEmpty) return <String, InvestmentQuote>{};
    final data = await _api.request(
      '/market/quotes',
      method: 'POST',
      body: {
        'requests': [
          for (final request in requests)
            {'symbol': request.symbol, 'type': request.type.name},
        ],
      },
    );
    final raw = data['quotes'];
    if (raw is! List) throw const FormatException('行情响应缺少 quotes');
    final quotes = <String, InvestmentQuote>{};
    for (final item in raw) {
      if (item == null) continue;
      final quote = _quote(item);
      final type = quote.type;
      if (type == null) throw const FormatException('行情响应缺少资产类型');
      quotes[_key(quote.symbol, type)] = quote;
    }
    return quotes;
  });

  @override
  Future<List<InvestmentHistoryPoint>> getHistory(
    String symbol,
    InvestmentAssetType type,
    InvestmentRange range,
  ) => _guard(() async {
    final uri = Uri(
      queryParameters: {
        'symbol': symbol,
        'type': type.name,
        'days': '${range.days}',
      },
    );
    final data = await _api.request('/market/history?${uri.query}');
    final raw = data['points'];
    if (raw is! List) throw const FormatException('行情历史响应缺少 points');
    return raw.map((item) {
      final map = _map(item, '行情历史');
      final date = DateTime.tryParse(_string(map, 'date'));
      final value = _number(map, 'value');
      if (date == null || value <= 0) {
        throw const FormatException('行情历史字段无效');
      }
      return InvestmentHistoryPoint(date, value);
    }).toList(growable: false);
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MarketDataException {
      rethrow;
    } on SharedApiException catch (error) {
      throw MarketDataException(error.message);
    } on FormatException catch (error) {
      throw MarketDataException(error.message);
    } on Object {
      throw const MarketDataException('行情服务暂时不可用');
    }
  }

  MarketSearchResult _searchResult(Object? value) {
    final map = _map(value, '行情搜索');
    final type = _type(map);
    final price = _number(map, 'price');
    if (price <= 0) throw const FormatException('行情价格无效');
    return MarketSearchResult(
      symbol: _string(map, 'symbol'),
      name: _string(map, 'name'),
      type: type,
      price: price,
      change: _number(map, 'change'),
      changePercent: _number(map, 'changePercent'),
      currency: _string(map, 'currency'),
      market: map['market']?.toString(),
    );
  }

  InvestmentQuote _quote(Object? value) {
    final map = _map(value, '行情');
    final timestamp = DateTime.tryParse(_string(map, 'timestamp'));
    final price = _number(map, 'price');
    if (timestamp == null || price <= 0) {
      throw const FormatException('行情时间或价格无效');
    }
    return InvestmentQuote(
      symbol: _string(map, 'symbol'),
      name: _string(map, 'name'),
      price: price,
      change: _number(map, 'change'),
      changePercent: _number(map, 'changePercent'),
      currency: _string(map, 'currency'),
      timestamp: timestamp,
      type: _type(map),
    );
  }

  InvestmentAssetType _type(Map<String, dynamic> map) {
    final raw = _string(map, 'type');
    return InvestmentAssetType.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => throw const FormatException('未知投资类型'),
    );
  }

  Map<String, dynamic> _map(Object? value, String label) {
    if (value is! Map) throw FormatException('$label 响应格式无效');
    return value.cast<String, dynamic>();
  }

  String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('行情字段 $key 无效');
    }
    return value.trim();
  }

  double _number(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('行情字段 $key 无效');
    }
    return value.toDouble();
  }

  String _key(String symbol, InvestmentAssetType type) =>
      'quote:${type.name}:${type.market}:${symbol.toUpperCase()}';
}

/// Debug/test safety net only. Release builds never use mock data as a silent
/// fallback, otherwise a provider outage could be shown as a fabricated price.
class DevelopmentMarketDataProvider implements MarketDataProvider {
  DevelopmentMarketDataProvider({
    required this.primary,
    required this.fallback,
  });

  final MarketDataProvider primary;
  final MarketDataProvider fallback;

  @override
  String get name => primary.name;

  Future<T> _run<T>(
    Future<T> Function(MarketDataProvider provider) operation,
  ) async {
    try {
      return await operation(primary);
    } on MarketDataException {
      return operation(fallback);
    }
  }

  @override
  Future<List<MarketSearchResult>> search(
    String query, {
    InvestmentAssetType? type,
    int limit = 20,
  }) => _run(
    (provider) => provider.search(query, type: type, limit: limit),
  );

  @override
  Future<InvestmentQuote?> getQuote(
    String symbol,
    InvestmentAssetType type,
  ) => _run((provider) => provider.getQuote(symbol, type));

  @override
  Future<Map<String, InvestmentQuote>> getQuotes(
    List<({String symbol, InvestmentAssetType type})> requests,
  ) => _run((provider) => provider.getQuotes(requests));

  @override
  Future<List<InvestmentHistoryPoint>> getHistory(
    String symbol,
    InvestmentAssetType type,
    InvestmentRange range,
  ) => _run((provider) => provider.getHistory(symbol, type, range));
}
