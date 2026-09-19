import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/entity_id.dart';
import '../../books/data/book_repository.dart';
import '../../../core/models/transaction_record.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../domain/investment_asset.dart';
import '../domain/investment_holding.dart';
import '../domain/investment_portfolio.dart';
import '../domain/investment_quote.dart';
import 'http_market_data_provider.dart';
import 'investment_config.dart';
import 'market_data_provider.dart';
import 'quote_cache.dart';

/// Input for creating a holding from the 添加投资 page.
class AddInvestmentRequest {
  const AddInvestmentRequest({
    required this.type,
    required this.symbol,
    required this.name,
    required this.price,
    required this.quantity,
    required this.transactionDate,
    this.accountId,
    this.note,
    this.priceSource = PriceSource.market,
    this.currentPrice,
    this.market,
    this.currency = InvestmentConfig.defaultCurrency,
  });

  final InvestmentAssetType type;
  final String symbol;
  final String name;

  /// Purchase price per unit.
  final double price;
  final double quantity;
  final DateTime transactionDate;
  final String? accountId;
  final String? note;
  final PriceSource priceSource;

  /// Only for manual assets: the user-entered current valuation.
  final double? currentPrice;

  final String? market;
  final String currency;
}

/// Input for appending a transaction to an existing holding.
class AddTransactionRequest {
  const AddTransactionRequest({
    required this.type,
    required this.quantity,
    required this.price,
    required this.transactionDate,
    this.note,
  });

  final InvestmentTransactionType type;
  final double quantity;
  final double price;
  final DateTime transactionDate;
  final String? note;
}

/// The only data entry point for the investment module.
///
/// Pages never touch Drift, the quote cache or a market provider directly, so
/// moving from the local store to a remote API means adding one implementation
/// of this interface — the UI does not change.
abstract interface class InvestmentRepository {
  /// Portfolio stream that re-emits whenever a holding changes. Quotes are
  /// served stale-while-revalidate: cached values are emitted immediately and
  /// refreshed in the background.
  Stream<InvestmentPortfolio> watchPortfolio();

  Future<InvestmentPortfolio> getPortfolio();

  Future<List<InvestmentHolding>> getHoldings(InvestmentAssetType type);

  Future<InvestmentHolding?> getHolding(String id);

  /// Current market value of one holding, resolved through the quote cache.
  Future<ValuedHolding?> valueHolding(String id);

  Future<List<InvestmentTransaction>> getTransactions(String holdingId);

  /// Search market instruments by name, code or symbol.
  Future<List<MarketSearchResult>> searchAssets(
    String query, {
    InvestmentAssetType? type,
  });

  Future<List<InvestmentHistoryPoint>> getPriceHistory(
    String symbol,
    InvestmentAssetType type,
    InvestmentRange range,
  );

  /// Creates the asset when unknown, then the holding plus its opening BUY.
  Future<InvestmentHolding> addHolding(AddInvestmentRequest request);

  Future<InvestmentTransaction> addTransaction(
    String holdingId,
    AddTransactionRequest request,
  );

  /// Once-per-day portfolio snapshot, written on first open of the day.
  Future<List<InvestmentSnapshot>> getSnapshots({int days});

  Future<void> ensureTodaySnapshot();

  /// Updates the user-entered valuation of a manual asset.
  Future<void> updateManualPrice(String holdingId, double price);
}

class DriftInvestmentRepository implements InvestmentRepository {
  DriftInvestmentRepository(
    this._database,
    this._market, {
    required this.bookId,
    QuoteCache? cache,
    DateTime Function()? clock,
  }) : _cache = cache ?? MemoryQuoteCache(clock: clock),
       _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final MarketDataProvider _market;
  final QuoteCache _cache;
  final DateTime Function() _clock;
  final String bookId;

  InvestmentDao get _dao => _database.investmentDao;

  /// The main ledger. Trades are mirrored into it as asset conversions so
  /// account balances, asset history and the shared-ledger recomputation
  /// all agree.
  TransactionRepository get _transactions =>
      DriftTransactionRepository(_database);

  // ------------------------------------------------------------ portfolio

  @override
  Stream<InvestmentPortfolio> watchPortfolio() {
    return _dao.watchChanges().asyncMap((_) => _portfolioFromCache()).asyncExpand(
      (initial) async* {
        yield initial;
        final refreshed = await _revalidate(initial);
        if (refreshed != null) yield refreshed;
      },
    );
  }

  @override
  Future<InvestmentPortfolio> getPortfolio() async {
    final initial = await _portfolioFromCache();
    return await _revalidate(initial) ?? initial;
  }

  /// Phase 1 of stale-while-revalidate: value everything from the cache. A
  /// holding with no cached quote falls back to its average cost, which is
  /// better than showing a fabricated zero during an outage.
  Future<InvestmentPortfolio> _portfolioFromCache() async {
    final holdings = await _loadHoldings();
    if (holdings.isEmpty) return InvestmentPortfolio.empty;
    final quotes = await _cache.getMany([
      for (final holding in holdings) holding.asset.quoteKey,
    ]);
    final withManual = <String, InvestmentQuote>{
      for (final holding in holdings)
        if (holding.asset.priceSource == PriceSource.manual &&
            holding.asset.manualPrice != null)
          holding.asset.quoteKey: InvestmentQuote(
            symbol: holding.asset.symbol,
            name: holding.asset.name,
            price: holding.asset.manualPrice!,
            change: 0,
            changePercent: 0,
            currency: holding.asset.currency,
            timestamp: _clock(),
            type: holding.asset.type,
          ),
      ...quotes,
    };
    return buildPortfolio(holdings: holdings, quotes: withManual);
  }

  /// Phase 2: fetch anything missing or expired. Returns null when nothing
  /// needed refreshing or the refresh failed, so the caller keeps the cached
  /// portfolio rather than clearing the screen.
  Future<InvestmentPortfolio?> _revalidate(InvestmentPortfolio initial) async {
    final holdings = initial.positions
        .map((position) => position.holding)
        .where((holding) => holding.asset.priceSource == PriceSource.market)
        .toList(growable: false);
    if (holdings.isEmpty) return null;

    // One request per asset class so a mixed portfolio costs at most four
    // provider calls instead of one per holding.
    final byType = <InvestmentAssetType, List<String>>{};
    for (final holding in holdings) {
      byType
          .putIfAbsent(holding.asset.type, () => [])
          .add(holding.asset.symbol);
    }

    final fetched = <String, InvestmentQuote>{};
    var failed = false;
    for (final entry in byType.entries) {
      final symbols = entry.value
          .toSet()
          .take(InvestmentConfig.maxBatchSymbols)
          .toList(growable: false);
      try {
        final quotes = await _market.getQuotes([
          for (final symbol in symbols) (symbol: symbol, type: entry.key),
        ]);
        for (final quote in quotes.entries) {
          fetched[quote.key] = quote.value;
          await _cache.set(
            quote.key,
            quote.value,
            ttl: InvestmentConfig.ttlFor(entry.key, now: _clock()),
          );
        }
      } on Object {
        // Keep whatever the cache already had and flag it as stale.
        failed = true;
      }
    }
    if (fetched.isEmpty && !failed) return null;

    final cached = await _cache.getMany([
      for (final holding in holdings) holding.asset.quoteKey,
    ]);
    final merged = <String, InvestmentQuote>{
      for (final entry in cached.entries)
        entry.key: entry.value.copyWith(
          isStale: failed && !fetched.containsKey(entry.key),
        ),
      ...fetched,
    };
    for (final holding in holdings) {
      if (holding.asset.priceSource == PriceSource.manual &&
          holding.asset.manualPrice != null) {
        merged[holding.asset.quoteKey] = InvestmentQuote(
          symbol: holding.asset.symbol,
          name: holding.asset.name,
          price: holding.asset.manualPrice!,
          change: 0,
          changePercent: 0,
          currency: holding.asset.currency,
          timestamp: _clock(),
          type: holding.asset.type,
        );
      }
    }
    final next = buildPortfolio(
      holdings: initial.positions
          .map((position) => position.holding)
          .toList(growable: false),
      quotes: merged,
    );
    return _samePortfolio(initial, next) ? null : next;
  }

  /// True when the refresh changed nothing the UI renders.
  ///
  /// Staleness is part of the comparison: a failed refresh over an unchanged
  /// cached price must still reach the UI so “行情更新失败” can appear.
  bool _samePortfolio(InvestmentPortfolio a, InvestmentPortfolio b) {
    if (a.positions.length != b.positions.length) return false;
    if (a.hasStaleQuote != b.hasStaleQuote) return false;
    for (var i = 0; i < a.positions.length; i++) {
      if (a.positions[i].price != b.positions[i].price) return false;
      if (a.positions[i].isStale != b.positions[i].isStale) return false;
    }
    return true;
  }

  // ------------------------------------------------------------- holdings

  @override
  Future<List<InvestmentHolding>> getHoldings(InvestmentAssetType type) async {
    final holdings = await _loadHoldings();
    return holdings
        .where((holding) => holding.asset.type == type)
        .toList(growable: false);
  }

  @override
  Future<InvestmentHolding?> getHolding(String id) async {
    final row = await _dao.findHoldingById(id);
    if (row == null) return null;
    final holdings = await _mapHoldings([row]);
    return holdings.isEmpty ? null : holdings.first;
  }

  @override
  Future<ValuedHolding?> valueHolding(String id) async {
    final holding = await getHolding(id);
    if (holding == null) return null;
    final portfolio = await getPortfolio();
    for (final position in portfolio.positions) {
      if (position.holding.id == id) return position;
    }
    // The repository guarantees a valuation even when the holding was filtered
    // out of the portfolio, so callers never handle a null price.
    return ValuedHolding(holding: holding, price: holding.averageCost);
  }

  /// Every live holding in the active ledger, resolved with its asset.
  Future<List<InvestmentHolding>> _loadHoldings() async {
    final rows = await _dao.getHoldings(bookId: bookId);
    final holdings = await _mapHoldings(rows);
    return holdings.where((holding) => !holding.isArchived).toList(
      growable: false,
    );
  }

  Future<List<InvestmentHolding>> _mapHoldings(
    List<InvestmentHoldingEntity> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final assets = <String, InvestmentAssetEntity>{
      for (final asset in await _dao.getAssetsByIds(
        rows.map((row) => row.assetId).toSet().toList(growable: false),
      ))
        asset.id: asset,
    };
    final holdings = <InvestmentHolding>[];
    for (final row in rows) {
      final entity = assets[row.assetId];
      if (entity == null) continue;
      holdings.add(
        InvestmentHolding(
          id: row.id,
          bookId: row.bookId,
          asset: _mapAsset(entity),
          quantity: row.quantity,
          averageCost: row.averageCost,
          accountId: row.accountId,
          note: row.note,
          isArchived: row.isArchived,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
      );
    }
    return holdings;
  }

  InvestmentAsset _mapAsset(InvestmentAssetEntity entity) => InvestmentAsset(
    id: entity.id,
    type: InvestmentAssetTypeX.fromName(entity.type),
    symbol: entity.symbol,
    name: entity.name,
    market: entity.market,
    currency: entity.currency,
    priceSource: PriceSourceX.fromName(entity.priceSource),
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
    manualPrice: entity.manualPrice,
  );

  // --------------------------------------------------------- transactions

  @override
  Future<List<InvestmentTransaction>> getTransactions(String holdingId) async {
    final rows = await _dao.getTransactions(holdingId);
    return [for (final row in rows) _mapTransaction(row)];
  }

  InvestmentTransaction _mapTransaction(InvestmentTransactionEntity row) =>
      InvestmentTransaction(
        id: row.id,
        bookId: row.bookId,
        holdingId: row.holdingId,
        type: InvestmentTransactionTypeX.fromName(row.type),
        quantity: row.quantity,
        price: row.price,
        transactionDate: row.transactionDate,
        note: row.note,
        createdAt: row.createdAt,
      );

  // --------------------------------------------------------------- search

  @override
  Future<List<MarketSearchResult>> searchAssets(
    String query, {
    InvestmentAssetType? type,
  }) => _market.search(query, type: type);

  @override
  Future<List<InvestmentHistoryPoint>> getPriceHistory(
    String symbol,
    InvestmentAssetType type,
    InvestmentRange range,
  ) => _market.getHistory(symbol, type, range);

  // ---------------------------------------------------------------- writes

  @override
  Future<InvestmentHolding> addHolding(AddInvestmentRequest request) async {
    _validateRequest(request);
    final now = _clock();
    late String holdingId;
    await _database.transaction(() async {
      final asset = await _ensureAsset(request, now);
      holdingId = 'holding-${newEntityId()}';
      final initialTradeId = 'investment-tx-${newEntityId()}';
      await _dao.insertHolding(
        InvestmentHoldingEntriesCompanion.insert(
          id: holdingId,
          bookId: Value(bookId),
          assetId: asset.id,
          accountId: Value(request.accountId),
          quantity: request.quantity,
          averageCost: request.price,
          note: Value(request.note),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _dao.insertTransaction(
        InvestmentTransactionEntriesCompanion.insert(
          id: initialTradeId,
          bookId: Value(bookId),
          holdingId: holdingId,
          type: InvestmentTransactionType.buy.name,
          price: request.price,
          quantity: request.quantity,
          amount: -(request.price * request.quantity),
          transactionDate: request.transactionDate,
          note: Value(request.note),
          createdAt: now,
        ),
      );
      await _mirrorTrade(
        holdingId: holdingId,
        accountId: request.accountId,
        type: InvestmentTransactionType.buy,
        price: request.price,
        quantity: request.quantity,
        occurredAt: request.transactionDate,
        note: request.note,
        currency: request.currency,
        sourceTransactionId: initialTradeId,
      );
    });
    // Warm the cache so the new holding renders a live price immediately.
    await _warmQuoteFloor(request, now);
    final holding = await getHolding(holdingId);
    if (holding == null) throw StateError('持仓创建失败');
    return holding;
  }

  Future<InvestmentAssetEntity> _ensureAsset(
    AddInvestmentRequest request,
    DateTime now,
  ) async {
    final type = request.type;
    final market = request.market ?? type.market;
    final symbol = request.symbol.trim().toUpperCase();
    final existing = await _dao.findAssetBySymbol(
      type: type.name,
      market: market,
      symbol: symbol,
    );
    if (existing != null) {
      // A manual asset the user just re-valued keeps the newer price.
      if (request.priceSource == PriceSource.manual &&
          request.currentPrice != null) {
        await _dao.writeAssetPrice(existing.id, request.currentPrice);
        return (await _dao.findAssetById(existing.id))!;
      }
      return existing;
    }
    final id = 'investment-asset-${newEntityId()}';
    await _dao.upsertAsset(
      InvestmentAssetEntriesCompanion.insert(
        id: id,
        type: type.name,
        symbol: symbol,
        name: request.name.trim(),
        market: Value(market),
        currency: Value(request.currency),
        priceSource: Value(request.priceSource.name),
        manualPrice: Value(
          request.priceSource == PriceSource.manual
              ? (request.currentPrice ?? request.price)
              : null,
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await _dao.findAssetById(id))!;
  }

  Future<void> _warmQuoteFloor(
    AddInvestmentRequest request,
    DateTime now,
  ) async {
    if (request.priceSource == PriceSource.manual) return;
    try {
      final symbol = request.symbol.trim().toUpperCase();
      final quotes = await _market.getQuotes([
        (symbol: symbol, type: request.type),
      ]);
      for (final entry in quotes.entries) {
        await _cache.set(
          entry.key,
          entry.value,
          ttl: InvestmentConfig.ttlFor(request.type, now: now),
        );
      }
    } on Object {
      // A cold cache only means the first render shows the cost basis; the
      // overview retries on its own.
    }
  }

  @override
  Future<InvestmentTransaction> addTransaction(
    String holdingId,
    AddTransactionRequest request,
  ) async {
    if (request.quantity <= 0) throw ArgumentError('数量必须大于 0');
    if (request.price < 0) throw ArgumentError('价格不能为负');
    final holding = await getHolding(holdingId);
    if (holding == null) throw StateError('未找到该持仓');

    final next = applyTransaction(
      type: request.type,
      quantity: holding.quantity,
      averageCost: holding.averageCost,
      transactionQuantity: request.quantity,
      price: request.price,
    );
    if (request.type == InvestmentTransactionType.sell &&
        request.quantity > holding.quantity + 1e-9) {
      throw ArgumentError('卖出数量不能超过当前持有数量');
    }

    final now = _clock();
    final id = 'investment-tx-${newEntityId()}';
    final amount = request.type == InvestmentTransactionType.buy
        ? -(request.price * request.quantity)
        : request.price * request.quantity;
    await _database.transaction(() async {
      await _dao.insertTransaction(
        InvestmentTransactionEntriesCompanion.insert(
          id: id,
          bookId: Value(holding.bookId),
          holdingId: holdingId,
          type: request.type.name,
          price: request.price,
          quantity: request.quantity,
          amount: amount,
          transactionDate: request.transactionDate,
          note: Value(request.note),
          createdAt: now,
        ),
      );
      await _dao.writeHoldingFields(
        holdingId,
        InvestmentHoldingEntriesCompanion(
          quantity: Value(next.quantity),
          averageCost: Value(next.averageCost),
          updatedAt: Value(now),
        ),
      );
      await _mirrorTrade(
        holdingId: holdingId,
        accountId: holding.accountId,
        type: request.type,
        price: request.price,
        quantity: request.quantity,
        occurredAt: request.transactionDate,
        note: request.note ?? holding.note,
        currency: holding.asset.currency,
        sourceTransactionId: id,
      );
    });
    final rows = await _dao.getTransactions(holdingId);
    final created = rows.where((row) => row.id == id).firstOrNull;
    if (created == null) throw StateError('交易记录创建失败');
    return _mapTransaction(created);
  }

  /// Mirrors one investment trade into the main ledger.
  ///
  /// A trade is an asset conversion, never consumption: cash leaves the
  /// funding account and the position moves the other way. Keeping a row in
  /// `transactions` is what makes the account balance, the asset history and
  /// the shared-ledger recomputation agree. The deterministic id keeps a
  /// retry from double-posting.
  ///
  /// Trades without a funding account stay unmirrored on purpose. Dividends
  /// and interest are income rather than conversions, so they are not
  /// handled here.
  Future<void> _mirrorTrade({
    required String holdingId,
    required String? accountId,
    required InvestmentTransactionType type,
    required double price,
    required double quantity,
    required DateTime occurredAt,
    required String? note,
    required String currency,
    required String sourceTransactionId,
  }) async {
    if (accountId == null) return;
    // An archived or missing account means there is nothing to move the money
    // from. The trade stays unmirrored instead of failing the whole entry.
    if (await _database.accountDao.findById(accountId) == null) return;
    final amount = price * quantity;
    if (!amount.isFinite || amount <= 0) return;
    final transactionType = switch (type) {
      InvestmentTransactionType.buy => TransactionType.assetPurchase,
      InvestmentTransactionType.sell => TransactionType.assetSale,
      InvestmentTransactionType.dividend ||
      InvestmentTransactionType.interest => null,
    };
    if (transactionType == null) return;
    final id = 'investment-mirror-$sourceTransactionId';
    if (await _database.transactionDao.findById(id) != null) return;
    final now = _clock();
    await _transactions.create(
      TransactionRecord(
        id: id,
        bookId: bookId,
        type: transactionType,
        amount: amount,
        accountId: accountId,
        occurredAt: occurredAt,
        createdAt: now,
        updatedAt: now,
        currency: currency,
        note: note,
        source: TransactionSource.manual,
        metadataJson: jsonEncode({
          'autoType': 'investmentTrade',
          'investmentTransactionId': sourceTransactionId,
          'holdingId': holdingId,
        }),
      ),
    );
  }

  @override
  Future<void> updateManualPrice(String holdingId, double price) async {
    if (price < 0) throw ArgumentError('估值不能为负');
    final holding = await getHolding(holdingId);
    if (holding == null) throw StateError('未找到该持仓');
    if (holding.asset.priceSource != PriceSource.manual) {
      throw StateError('该资产使用行情自动更新，无法手动修改估值');
    }
    await _dao.writeAssetPrice(holding.asset.id, price);
  }

  // ------------------------------------------------------------ snapshots

  @override
  Future<List<InvestmentSnapshot>> getSnapshots({int days = 365}) async {
    final today = _clock();
    final floor = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: days));
    final rows = await _dao.getSnapshots(
      bookId: bookId,
      fromDate: InvestmentSnapshot.dateKey(floor),
    );
    return [
      for (final row in rows)
        InvestmentSnapshot(
          date:
              _parseSnapshotDate(row.date) ??
              DateTime(today.year, today.month, today.day),
          investmentValue: row.investmentValue,
          stockValue: row.stockValue,
          fundValue: row.fundValue,
          bondValue: row.bondValue,
          cryptoValue: row.cryptoValue,
        ),
    ];
  }

  DateTime? _parseSnapshotDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  @override
  Future<void> ensureTodaySnapshot() async {
    final now = _clock();
    final key = InvestmentSnapshot.dateKey(now);
    // Check first: an existing row means today is already recorded and no
    // quote refresh is needed for the snapshot alone.
    final existing = await _dao.findSnapshot(bookId: bookId, date: key);
    if (existing != null) return;
    final portfolio = await getPortfolio();
    if (portfolio.isEmpty) return;
    final marketPositions = portfolio.positions.where(
      (position) => position.holding.asset.priceSource == PriceSource.market,
    );
    // A daily history point must never be fabricated from average cost when
    // the real provider is unavailable. Manual assets are allowed because
    // their current price is explicitly user-entered.
    if (marketPositions.any(
      (position) => position.quote == null || position.quote!.isStale,
    )) {
      return;
    }
    await _dao.upsertSnapshot(
      InvestmentSnapshotEntriesCompanion.insert(
        bookId: bookId,
        date: key,
        investmentValue: portfolio.investmentValue,
        stockValue: portfolio.categoryOf(InvestmentAssetType.stock).value,
        fundValue: portfolio.categoryOf(InvestmentAssetType.fund).value,
        bondValue: portfolio.categoryOf(InvestmentAssetType.bond).value,
        cryptoValue: portfolio.categoryOf(InvestmentAssetType.crypto).value,
      ),
    );
  }

  void _validateRequest(AddInvestmentRequest request) {
    if (request.name.trim().isEmpty) throw ArgumentError('请输入投资名称');
    if (request.symbol.trim().isEmpty) throw ArgumentError('请输入投资代码');
    if (request.price <= 0) throw ArgumentError('买入价格必须大于 0');
    if (request.quantity <= 0) throw ArgumentError('买入数量必须大于 0');
  }
}

/// Remote implementation seam.
///
/// When the 投资管理 backend endpoints exist, implement this class against them
/// and switch [investmentRepositoryProvider]. No page, widget or domain model
/// changes, because they already depend only on [InvestmentRepository].
class ApiInvestmentRepository implements InvestmentRepository {
  const ApiInvestmentRepository({required this.baseUrl, this.authToken});

  final String baseUrl;
  final String? authToken;

  Never _unimplemented() => throw UnimplementedError(
    'ApiInvestmentRepository 尚未接入。请实现 /investment/* 接口后，在 '
    'investmentRepositoryProvider 中替换 DriftInvestmentRepository。',
  );

  @override
  Future<InvestmentHolding> addHolding(AddInvestmentRequest request) async =>
      _unimplemented();

  @override
  Future<InvestmentTransaction> addTransaction(
    String holdingId,
    AddTransactionRequest request,
  ) async => _unimplemented();

  @override
  Future<void> ensureTodaySnapshot() async => _unimplemented();

  @override
  Future<List<InvestmentHolding>> getHoldings(InvestmentAssetType type) async =>
      _unimplemented();

  @override
  Future<InvestmentPortfolio> getPortfolio() async => _unimplemented();

  @override
  Future<List<InvestmentHistoryPoint>> getPriceHistory(
    String symbol,
    InvestmentAssetType type,
    InvestmentRange range,
  ) async => _unimplemented();

  @override
  Future<InvestmentHolding?> getHolding(String id) async => _unimplemented();

  @override
  Future<List<InvestmentSnapshot>> getSnapshots({int days = 365}) async =>
      _unimplemented();

  @override
  Future<List<InvestmentTransaction>> getTransactions(
    String holdingId,
  ) async => _unimplemented();

  @override
  Future<List<MarketSearchResult>> searchAssets(
    String query, {
    InvestmentAssetType? type,
  }) async => _unimplemented();

  @override
  Future<void> updateManualPrice(String holdingId, double price) async =>
      _unimplemented();

  @override
  Future<ValuedHolding?> valueHolding(String id) async => _unimplemented();

  @override
  Stream<InvestmentPortfolio> watchPortfolio() => Stream.error(
    UnimplementedError('ApiInvestmentRepository 尚未接入'),
  );
}

// ------------------------------------------------------------------ providers

/// Device-local stale-while-revalidate cache. Shared Redis caching lives on
/// the server; the mobile app never receives Redis credentials.
final quoteCacheProvider = Provider<QuoteCache>((ref) => MemoryQuoteCache());

/// Release builds always use the app server's real-market proxy. Debug and test
/// builds retain the deterministic mock only as an explicit development
/// fallback when no local server is running.
final marketDataProviderProvider = Provider<MarketDataProvider>((ref) {
  final real = HttpMarketDataProvider(ref.watch(sharedApiProvider));
  if (kReleaseMode) return real;
  return DevelopmentMarketDataProvider(
    primary: real,
    fallback: MockMarketDataProvider(),
  );
});

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  return DriftInvestmentRepository(
    ref.watch(databaseProvider),
    ref.watch(marketDataProviderProvider),
    bookId:
        ref.watch(activeBookProvider)?.assetBookId ??
        ref.watch(activeBookIdProvider),
    cache: ref.watch(quoteCacheProvider),
  );
});

/// Portfolio stream backing 投资管理总览 and every 分类持仓页.
///
/// Created lazily so a user who never opens 投资管理 pays nothing, and it
/// lazily writes today's snapshot the first time it is built.
final investmentPortfolioProvider = StreamProvider<InvestmentPortfolio>((
  ref,
) async* {
  await ref.watch(databaseBootstrapProvider.future);
  final repository = ref.watch(investmentRepositoryProvider);
  yield* repository.watchPortfolio();
  unawaited(repository.ensureTodaySnapshot());
});

/// Market value of every investment position, grouped by currency.
///
/// Net worth folds these in through AssetOverview. Positions are not accounts,
/// so they are never faked as an account row.
final investmentValueByCurrencyProvider = Provider<Map<String, double>>((ref) {
  final positions = ref.watch(investmentPortfolioProvider).value?.positions;
  if (positions == null || positions.isEmpty) return const {};
  final totals = <String, double>{};
  for (final position in positions) {
    final currency = position.holding.asset.currency.toUpperCase();
    final value = position.marketValue;
    totals.update(currency, (v) => v + value, ifAbsent: () => value);
  }
  return totals;
});

/// Stored once-per-day snapshots for the 投资资产趋势 chart.
///
/// Keyed by the number of days so the three ranges do not share a cache entry.
final investmentSnapshotsProvider =
    FutureProvider.family<List<InvestmentSnapshot>, int>((ref, days) async {
      await ref.watch(databaseBootstrapProvider.future);
      return ref.watch(investmentRepositoryProvider).getSnapshots(days: days);
    });

/// Identifies one price-history request.
class PriceHistoryKey {
  const PriceHistoryKey(this.symbol, this.type, this.range);

  final String symbol;
  final InvestmentAssetType type;
  final InvestmentRange range;

  @override
  bool operator ==(Object other) =>
      other is PriceHistoryKey &&
      other.symbol == symbol &&
      other.type == type &&
      other.range == range;

  @override
  int get hashCode => Object.hash(symbol, type, range);
}

/// Price / net-value trend for one holding's 走势图.
final investmentHistoryProvider =
    FutureProvider.family<List<InvestmentHistoryPoint>, PriceHistoryKey>((
      ref,
      key,
    ) async {
      return ref
          .watch(investmentRepositoryProvider)
          .getPriceHistory(key.symbol, key.type, key.range);
    });

/// Search results for the 搜索添加 tab. Kept as a provider so the debounced
/// query, not the widget, owns the in-flight request.
final investmentSearchProvider = FutureProvider.family
    .autoDispose<List<MarketSearchResult>, ({String query, InvestmentAssetType? type})>(
      (ref, key) async {
        if (key.query.trim().isEmpty) return const [];
        return ref
            .watch(investmentRepositoryProvider)
            .searchAssets(key.query, type: key.type);
      },
    );

/// Transactions of one holding.
final investmentTransactionsProvider =
    FutureProvider.family<List<InvestmentTransaction>, String>((
      ref,
      holdingId,
    ) async {
      await ref.watch(databaseBootstrapProvider.future);
      return ref
          .watch(investmentRepositoryProvider)
          .getTransactions(holdingId);
    });

/// One holding with its current valuation, for 单个投资详情.
final investmentHoldingProvider =
    FutureProvider.family<ValuedHolding?, String>((ref, holdingId) async {
      await ref.watch(databaseBootstrapProvider.future);
      // Re-evaluate whenever the portfolio changes so the detail page follows
      // a refresh triggered elsewhere.
      ref.watch(investmentPortfolioProvider);
      return ref.watch(investmentRepositoryProvider).valueHolding(holdingId);
    });
