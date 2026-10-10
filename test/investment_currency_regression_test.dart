import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/features/investments/data/investment_repository.dart';
import 'package:jizhang_app/features/investments/data/market_data_provider.dart';
import 'package:jizhang_app/features/investments/data/quote_cache.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';
import 'package:jizhang_app/features/investments/domain/investment_quote.dart';

class ForeignMarket extends MockMarketDataProvider {
  ForeignMarket() : super(clock: () => DateTime(2026, 10, 9));
  @override
  Future<Map<String, InvestmentQuote>> getQuotes(
    List<({String symbol, InvestmentAssetType type})> requests,
  ) async => {
    for (final r in requests)
      'quote:${r.type.name}:${r.type.market}:${r.symbol}': InvestmentQuote(
        symbol: r.symbol,
        name: 'Apple',
        type: r.type,
        currency: 'USD',
        price: 250,
        change: 2,
        changePercent: .8,
        timestamp: DateTime(2026, 10, 9),
      ),
  };
}

void main() {
  test('exchange-qualified quotes value foreign holdings without losing manual valuations or mixing currencies', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftInvestmentRepository(
      db,
      ForeignMarket(),
      bookId: 'book-personal',
      cache: MemoryQuoteCache(),
      clock: () => DateTime(2026, 10, 9),
    );
    await repo.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: 'AAPL:NASDAQ',
        name: 'Apple',
        market: 'NASDAQ',
        currency: 'USD',
        price: 200,
        quantity: 2,
        transactionDate: DateTime(2026, 10, 1),
      ),
    );
    await repo.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.bond,
        symbol: 'MANUAL',
        name: '手动资产',
        priceSource: PriceSource.manual,
        currentPrice: 120,
        price: 100,
        quantity: 3,
        transactionDate: DateTime(2026, 10, 1),
      ),
    );
    final portfolio = await repo.getPortfolio();
    expect(portfolio.positions.length, 2);
    expect(portfolio.investmentValue, 360);
    expect(portfolio.inCurrency('USD').investmentValue, 500);
    expect(portfolio.inCurrency('USD').totalProfit, 100);
    expect(
      portfolio.positions
          .firstWhere((p) => p.holding.asset.symbol == 'AAPL:NASDAQ')
          .quote,
      isNotNull,
    );
    await repo.ensureTodaySnapshot();
    expect((await repo.getSnapshots()).single.investmentValue, 360);
  });
}
