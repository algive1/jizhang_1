import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/investments/data/investment_repository.dart';
import 'package:jizhang_app/features/investments/data/market_data_provider.dart';
import 'package:jizhang_app/features/investments/data/quote_cache.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';
import 'package:jizhang_app/features/investments/domain/investment_portfolio.dart';
import 'package:jizhang_app/features/investments/domain/investment_quote.dart';

/// A provider that always fails, to exercise the stale-quote path.
class _FailingMarketDataProvider implements MarketDataProvider {
  @override
  String get name => '失败行情';

  @override
  Future<List<MarketSearchResult>> search(
    String query, {
    InvestmentAssetType? type,
    int limit = 20,
  }) async => throw const MarketDataException('行情服务暂时不可用');

  @override
  Future<InvestmentQuote?> getQuote(
    String symbol,
    InvestmentAssetType type,
  ) async => throw const MarketDataException('行情服务暂时不可用');

  @override
  Future<Map<String, InvestmentQuote>> getQuotes(
    List<({String symbol, InvestmentAssetType type})> requests,
  ) async => throw const MarketDataException('行情服务暂时不可用');

  @override
  Future<List<InvestmentHistoryPoint>> getHistory(
    String symbol,
    InvestmentAssetType type,
    InvestmentRange range,
  ) async => throw const MarketDataException('行情服务暂时不可用');
}

void main() {
  late AppDatabase database;
  late MemoryQuoteCache cache;
  late DriftInvestmentRepository repository;
  final clock = DateTime(2026, 9, 17, 10);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    cache = MemoryQuoteCache(clock: () => clock);
    repository = DriftInvestmentRepository(
      database,
      MockMarketDataProvider(clock: () => clock),
      bookId: 'book-personal',
      cache: cache,
      clock: () => clock,
    );
  });

  tearDown(() => database.close());

  /// Seeds a real ledger account so a funded trade has somewhere to post.
  Future<void> seedAccount(String id, double balance) async {
    final now = DateTime(2026, 9, 1, 12);
    await database.accountDao.insertOne(
      AccountEntriesCompanion.insert(
        id: id,
        name: id,
        type: 'cash',
        balanceInCents: Value((balance * 100).round()),
        icon: 'wallet',
        color: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<double> balanceOf(String id) async {
    final account = await database.accountDao.findById(id);
    return account!.balanceInCents / 100;
  }

  Future<List<String>> mirroredTypes() async {
    final rows = await database
        .customSelect('SELECT type FROM transactions ORDER BY rowid')
        .get();
    return rows.map((row) => row.read<String>('type')).toList();
  }

  test('a purchase is never written into the consumption ledger', () async {
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );

    // The investment module keeps its own tables. A buy is an asset-to-asset
    // conversion, so it must not appear as an expense transaction and must not
    // be able to reduce net worth.
    final transactions = await database
        .customSelect('SELECT COUNT(*) AS c FROM transactions')
        .getSingle();
    expect(transactions.read<int>('c'), 0);

    final rows = await database
        .customSelect('SELECT COUNT(*) AS c FROM investment_transactions')
        .getSingle();
    expect(rows.read<int>('c'), 1);
  });

  test('addHolding persists the holding and its opening BUY', () async {
    await seedAccount('account-bank', 10000);
    final holding = await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.fund,
        symbol: '510300',
        name: '沪深300ETF',
        price: 3.5,
        quantity: 1000,
        transactionDate: DateTime(2026, 9, 1),
        accountId: 'account-bank',
        note: '定投',
      ),
    );

    expect(holding.quantity, 1000);
    expect(holding.averageCost, 3.5);
    expect(holding.accountId, 'account-bank');
    expect(holding.asset.type, InvestmentAssetType.fund);

    final records = await repository.getTransactions(holding.id);
    expect(records.length, 1);
    expect(records.first.type, InvestmentTransactionType.buy);
    expect(records.first.cashFlow, closeTo(-3500, 1e-9));

    // The cash leg is mirrored into the main ledger as an asset conversion,
    // so the money is not lost and the position is paid for.
    expect(await mirroredTypes(), ['assetPurchase']);
    expect(await balanceOf('account-bank'), closeTo(6500, 0.001));
  });

  test('a funded buy moves cash out of the funding account', () async {
    await seedAccount('account-bank', 10000);
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
        accountId: 'account-bank',
      ),
    );

    expect(await mirroredTypes(), ['assetPurchase']);
    expect(await balanceOf('account-bank'), closeTo(0, 0.001));
  });

  test('a sell returns cash without booking income', () async {
    await seedAccount('account-bank', 10000);
    final holding = await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
        accountId: 'account-bank',
      ),
    );
    await repository.addTransaction(
      holding.id,
      AddTransactionRequest(
        type: InvestmentTransactionType.sell,
        quantity: 100,
        price: 120,
        transactionDate: DateTime(2026, 9, 2),
      ),
    );

    expect(await mirroredTypes(), ['assetPurchase', 'assetSale']);
    // 10000 - 10000 + 12000
    expect(await balanceOf('account-bank'), closeTo(12000, 0.001));
  });

  test('an unfunded trade never touches the main ledger', () async {
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );

    expect(await mirroredTypes(), isEmpty);
  });

  test('a trade against a missing account stays unmirrored', () async {
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
        accountId: 'account-gone',
      ),
    );

    expect(await mirroredTypes(), isEmpty);
  });

  test('asset conversions are neither consumption nor income', () {
    TransactionRecord record(TransactionType type) => TransactionRecord(
      id: 'x',
      bookId: 'book-personal',
      type: type,
      amount: 100,
      accountId: 'account-bank',
      occurredAt: DateTime(2026, 9, 1),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

    final buy = record(TransactionType.assetPurchase);
    final sell = record(TransactionType.assetSale);
    expect(buy.isAssetTransfer, isTrue);
    expect(buy.isConsumptionExpense, isFalse);
    expect(sell.isAssetTransfer, isTrue);
    expect(sell.isExpense, isFalse);
    expect(sell.isIncome, isFalse);
  });

  test('a second buy blends the average cost', () async {
    final holding = await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );
    await repository.addTransaction(
      holding.id,
      AddTransactionRequest(
        type: InvestmentTransactionType.buy,
        quantity: 100,
        price: 200,
        transactionDate: DateTime(2026, 9, 2),
      ),
    );

    final updated = await repository.getHolding(holding.id);
    expect(updated!.quantity, 200);
    expect(updated.averageCost, closeTo(150, 1e-9));
  });

  test('a sell reduces quantity and cannot exceed what is held', () async {
    final holding = await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );
    await repository.addTransaction(
      holding.id,
      AddTransactionRequest(
        type: InvestmentTransactionType.sell,
        quantity: 40,
        price: 120,
        transactionDate: DateTime(2026, 9, 3),
      ),
    );
    var updated = await repository.getHolding(holding.id);
    expect(updated!.quantity, 60);
    expect(updated.averageCost, closeTo(100, 1e-9));

    await expectLater(
      repository.addTransaction(
        holding.id,
        AddTransactionRequest(
          type: InvestmentTransactionType.sell,
          quantity: 999,
          price: 120,
          transactionDate: DateTime(2026, 9, 4),
        ),
      ),
      throwsArgumentError,
    );
    updated = await repository.getHolding(holding.id);
    expect(updated!.quantity, 60);
  });

  test('a dividend leaves the position and records income', () async {
    final holding = await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.bond,
        symbol: '230023',
        name: '23附息国债10',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );
    final record = await repository.addTransaction(
      holding.id,
      AddTransactionRequest(
        type: InvestmentTransactionType.dividend,
        quantity: 1,
        price: 120,
        transactionDate: DateTime(2026, 8, 20),
      ),
    );
    expect(record.amount, closeTo(120, 1e-9));
    expect(record.cashFlow, closeTo(120, 1e-9));

    final updated = await repository.getHolding(holding.id);
    expect(updated!.quantity, 100);
  });

  test('a manual asset keeps the user valuation and ignores the market',
      () async {
    final holding = await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.crypto,
        symbol: 'MYCOIN',
        name: '我的币',
        price: 10,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
        priceSource: PriceSource.manual,
        currentPrice: 12,
      ),
    );
    expect(holding.asset.priceSource, PriceSource.manual);

    var valued = await repository.valueHolding(holding.id);
    expect(valued!.price, closeTo(12, 1e-9));
    expect(valued.profit, closeTo(200, 1e-9));

    await repository.updateManualPrice(holding.id, 15);
    valued = await repository.valueHolding(holding.id);
    expect(valued!.price, closeTo(15, 1e-9));
    expect(valued.profit, closeTo(500, 1e-9));
    expect(valued.profitPercent, closeTo(50, 1e-9));
  });

  test('a market asset refuses a manual valuation', () async {
    final holding = await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );
    await expectLater(
      repository.updateManualPrice(holding.id, 200),
      throwsStateError,
    );
  });

  test('the same symbol is stored once and shared across holdings', () async {
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 200,
        quantity: 10,
        transactionDate: DateTime(2026, 9, 2),
      ),
    );
    final assets = await database
        .customSelect('SELECT COUNT(*) AS c FROM investment_assets')
        .getSingle();
    expect(assets.read<int>('c'), 1);
    final holdings = await database
        .customSelect('SELECT COUNT(*) AS c FROM investment_holdings')
        .getSingle();
    expect(holdings.read<int>('c'), 2);
  });

  test('search returns instruments by code, name and symbol', () async {
    final byCode = await repository.searchAssets('600519');
    expect(byCode.single.name, '贵州茅台');

    final byName = await repository.searchAssets('贵州茅台');
    expect(byName.single.symbol, '600519');

    final crypto = await repository.searchAssets('BTC');
    expect(crypto.single.type, InvestmentAssetType.crypto);
  });

  test('a failing provider keeps the cached portfolio instead of clearing it',
      () async {
    final holding = await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );
    // Warm the cache with a good quote.
    await repository.getPortfolio();
    expect(cache.size, greaterThan(0));
    final warm = await repository.valueHolding(holding.id);
    expect(warm!.price, greaterThan(0));

    // Now make every provider call fail.
    final degraded = DriftInvestmentRepository(
      database,
      _FailingMarketDataProvider(),
      bookId: 'book-personal',
      cache: cache,
      clock: () => clock,
    );
    final portfolio = await degraded.getPortfolio();
    expect(portfolio.positions, isNotEmpty);
    // The previously cached price survives and is flagged stale.
    expect(portfolio.positions.first.price, closeTo(warm.price, 1e-9));
    expect(portfolio.hasStaleQuote, isTrue);
  });

  test('today snapshot is written once and re-read for the trend', () async {
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );
    await repository.ensureTodaySnapshot();
    await repository.ensureTodaySnapshot();

    final rows = await database
        .customSelect('SELECT COUNT(*) AS c FROM investment_snapshots')
        .getSingle();
    expect(rows.read<int>('c'), 1);

    final snapshots = await repository.getSnapshots(days: 30);
    expect(snapshots.length, 1);
    expect(snapshots.single.investmentValue, greaterThan(0));
    expect(InvestmentSnapshot.dateKey(snapshots.single.date), '2026-09-17');
  });

  test('an empty portfolio writes no snapshot at all', () async {
    await repository.ensureTodaySnapshot();
    final rows = await database
        .customSelect('SELECT COUNT(*) AS c FROM investment_snapshots')
        .getSingle();
    // An inactive user must not accumulate server work or rows.
    expect(rows.read<int>('c'), 0);
  });

  test('holdings are grouped by asset class', () async {
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.bond,
        symbol: '230023',
        name: '23附息国债10',
        price: 100,
        quantity: 100,
        transactionDate: DateTime(2026, 9, 1),
      ),
    );
    expect(
      (await repository.getHoldings(InvestmentAssetType.stock)).length,
      1,
    );
    expect(
      (await repository.getHoldings(InvestmentAssetType.bond)).length,
      1,
    );
    expect(
      (await repository.getHoldings(InvestmentAssetType.crypto)),
      isEmpty,
    );
  });

  test('invalid input is rejected before anything is written', () async {
    await expectLater(
      repository.addHolding(
        AddInvestmentRequest(
          type: InvestmentAssetType.stock,
          symbol: '600519',
          name: '贵州茅台',
          price: 0,
          quantity: 100,
          transactionDate: DateTime(2026, 9, 1),
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.addHolding(
        AddInvestmentRequest(
          type: InvestmentAssetType.stock,
          symbol: '600519',
          name: '贵州茅台',
          price: 100,
          quantity: 0,
          transactionDate: DateTime(2026, 9, 1),
        ),
      ),
      throwsArgumentError,
    );
    final holdings = await database
        .customSelect('SELECT COUNT(*) AS c FROM investment_holdings')
        .getSingle();
    expect(holdings.read<int>('c'), 0);
  });
}
