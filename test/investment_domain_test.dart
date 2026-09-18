import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';
import 'package:jizhang_app/features/investments/domain/investment_holding.dart';
import 'package:jizhang_app/features/investments/domain/investment_portfolio.dart';
import 'package:jizhang_app/features/investments/domain/investment_quote.dart';

InvestmentHolding _holding({
  String id = 'h1',
  InvestmentAssetType type = InvestmentAssetType.stock,
  String symbol = '600519',
  double quantity = 100,
  double averageCost = 100,
  String? accountId,
  bool isArchived = false,
}) => InvestmentHolding(
  id: id,
  asset: InvestmentAsset(
    id: 'asset-$id',
    type: type,
    symbol: symbol,
    name: symbol,
    market: type.market,
  ),
  quantity: quantity,
  averageCost: averageCost,
  accountId: accountId,
  isArchived: isArchived,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

InvestmentQuote _quote({
  InvestmentAssetType type = InvestmentAssetType.stock,
  double price = 110,
  double change = 1.5,
}) => InvestmentQuote(
  symbol: '600519',
  name: '贵州茅台',
  price: price,
  change: change,
  changePercent: 1.4,
  timestamp: DateTime(2026, 9, 17, 10),
  type: type,
);

void main() {
  group('average cost maths', () {
    test('a buy blends the previous cost with the new purchase', () {
      final result = applyTransaction(
        type: InvestmentTransactionType.buy,
        quantity: 100,
        averageCost: 10,
        transactionQuantity: 100,
        price: 20,
      );
      expect(result.quantity, 200);
      // (100×10 + 100×20) / 200 = 15
      expect(result.averageCost, closeTo(15, 1e-9));
    });

    test('a sell keeps the average cost and only drops the quantity', () {
      final result = applyTransaction(
        type: InvestmentTransactionType.sell,
        quantity: 200,
        averageCost: 15,
        transactionQuantity: 50,
        price: 30,
      );
      expect(result.quantity, 150);
      expect(result.averageCost, closeTo(15, 1e-9));
    });

    test('a sell can never push the quantity below zero', () {
      final result = applyTransaction(
        type: InvestmentTransactionType.sell,
        quantity: 10,
        averageCost: 15,
        transactionQuantity: 999,
        price: 30,
      );
      expect(result.quantity, 0);
    });

    test('dividends and interest leave the position untouched', () {
      for (final type in [
        InvestmentTransactionType.dividend,
        InvestmentTransactionType.interest,
      ]) {
        final result = applyTransaction(
          type: type,
          quantity: 100,
          averageCost: 10,
          transactionQuantity: 1,
          price: 120,
        );
        expect(result.quantity, 100);
        expect(result.averageCost, 10);
      }
    });
  });

  group('holding profit', () {
    test('profit is (price − averageCost) × quantity', () {
      final holding = _holding(quantity: 100, averageCost: 100);
      expect(holding.profit(110), closeTo(1000, 1e-9));
      expect(holding.profitPercent(110), closeTo(10, 1e-9));
      expect(holding.marketValue(110), closeTo(11000, 1e-9));
      expect(holding.cost, closeTo(10000, 1e-9));
    });

    test('a loss is reported as negative', () {
      final holding = _holding(quantity: 100, averageCost: 100);
      expect(holding.profit(90), closeTo(-1000, 1e-9));
      expect(holding.profitPercent(90), closeTo(-10, 1e-9));
    });

    test('a zero cost basis has no comparable return rate', () {
      final holding = _holding(quantity: 0, averageCost: 0);
      expect(holding.profitPercent(110), isNull);
    });
  });

  group('cash-flow direction', () {
    test('a buy is money out, a sell is money in', () {
      final buy = InvestmentTransaction(
        id: 't1',
        holdingId: 'h1',
        type: InvestmentTransactionType.buy,
        quantity: 100,
        price: 100,
        transactionDate: DateTime(2026, 9, 1),
      );
      final sell = InvestmentTransaction(
        id: 't2',
        holdingId: 'h1',
        type: InvestmentTransactionType.sell,
        quantity: 100,
        price: 120,
        transactionDate: DateTime(2026, 9, 2),
      );
      expect(buy.cashFlow, closeTo(-10000, 1e-9));
      expect(sell.cashFlow, closeTo(12000, 1e-9));
      expect(buy.amount, closeTo(10000, 1e-9));
      expect(sell.amount, closeTo(12000, 1e-9));
    });

    test('a cash distribution reports the income, not quantity × price', () {
      final dividend = InvestmentTransaction(
        id: 't3',
        holdingId: 'h1',
        type: InvestmentTransactionType.dividend,
        quantity: 1,
        price: 120,
        transactionDate: DateTime(2026, 9, 3),
      );
      expect(dividend.amount, closeTo(120, 1e-9));
      expect(dividend.cashFlow, closeTo(120, 1e-9));
    });
  });

  group('portfolio aggregation', () {
    test('totals, per-class values and returns add up', () {
      final holdings = [
        _holding(id: 'a', quantity: 100, averageCost: 100),
        _holding(
          id: 'b',
          type: InvestmentAssetType.fund,
          symbol: '510300',
          quantity: 1000,
          averageCost: 3,
        ),
      ];
      final portfolio = buildPortfolio(
        holdings: holdings,
        quotes: {
          'quote:stock:CN:600519': _quote(price: 110, change: 1.5),
          'quote:fund:CN:510300': _quote(
            type: InvestmentAssetType.fund,
            price: 3.5,
            change: 0.01,
          ),
        },
      );

      expect(portfolio.positions.length, 2);
      expect(portfolio.investmentValue, closeTo(11000 + 3500, 1e-9));
      expect(portfolio.cost, closeTo(10000 + 3000, 1e-9));
      expect(portfolio.totalProfit, closeTo(1500, 1e-9));
      expect(portfolio.totalProfitPercent, closeTo(1500 / 13000 * 100, 1e-9));
      expect(
        portfolio.categoryOf(InvestmentAssetType.stock).value,
        closeTo(11000, 1e-9),
      );
      expect(
        portfolio.categoryOf(InvestmentAssetType.bond).value,
        closeTo(0, 1e-9),
      );
      expect(
        portfolio.categoryOf(InvestmentAssetType.bond).profitPercent,
        isNull,
      );
    });

    test('today profit uses the quote change times the quantity held', () {
      final portfolio = buildPortfolio(
        holdings: [_holding(quantity: 100, averageCost: 100)],
        quotes: {'quote:stock:CN:600519': _quote(price: 110, change: 1.5)},
      );
      expect(portfolio.todayProfit, closeTo(150, 1e-9));
    });

    test('a holding without a quote falls back to its cost basis', () {
      final portfolio = buildPortfolio(
        holdings: [_holding(quantity: 100, averageCost: 100)],
        quotes: const {},
      );
      // Never a fabricated zero during a market-data outage.
      expect(portfolio.investmentValue, closeTo(10000, 1e-9));
      expect(portfolio.totalProfit, closeTo(0, 1e-9));
    });

    test('archived holdings are excluded from every total', () {
      final portfolio = buildPortfolio(
        holdings: [
          _holding(id: 'live', quantity: 100, averageCost: 100),
          _holding(id: 'gone', quantity: 900, averageCost: 100, isArchived: true),
        ],
        quotes: {'quote:stock:CN:600519': _quote(price: 110)},
      );
      expect(portfolio.positions.length, 1);
      expect(portfolio.investmentValue, closeTo(11000, 1e-9));
    });

    test('scoping to one class keeps the same maths', () {
      final portfolio = buildPortfolio(
        holdings: [
          _holding(id: 'a', quantity: 100, averageCost: 100),
          _holding(
            id: 'b',
            type: InvestmentAssetType.crypto,
            symbol: 'BTC',
            quantity: 2,
            averageCost: 50000,
          ),
        ],
        quotes: {
          'quote:stock:CN:600519': _quote(price: 110),
          'quote:crypto:GLOBAL:BTC': _quote(
            type: InvestmentAssetType.crypto,
            price: 60000,
          ),
        },
      );
      final crypto = portfolio.scopedTo(InvestmentAssetType.crypto);
      expect(crypto.positions.length, 1);
      expect(crypto.investmentValue, closeTo(120000, 1e-9));
      expect(crypto.totalProfit, closeTo(20000, 1e-9));
      expect(crypto.totalProfitPercent, closeTo(20, 1e-9));
    });
  });

  group('quote cache keys', () {
    test('are shared per security, never per user', () {
      const asset = InvestmentAsset(
        id: 'a',
        type: InvestmentAssetType.stock,
        symbol: '600519',
        name: '贵州茅台',
        market: 'CN',
      );
      expect(asset.quoteKey, 'quote:stock:CN:600519');
      expect(asset.quoteKey.contains('user'), isFalse);

      const crypto = InvestmentAsset(
        id: 'b',
        type: InvestmentAssetType.crypto,
        symbol: 'BTC',
        name: '比特币',
        market: 'GLOBAL',
      );
      expect(crypto.quoteKey, 'quote:crypto:GLOBAL:BTC');
    });
  });

  group('daily snapshots', () {
    test('trend keeps only dates inside the requested window', () {
      final now = DateTime(2026, 9, 17);
      final trend = InvestmentTrend.from(
        [
          InvestmentSnapshot(
            date: DateTime(2026, 9, 17),
            investmentValue: 120,
            stockValue: 120,
            fundValue: 0,
            bondValue: 0,
            cryptoValue: 0,
          ),
          InvestmentSnapshot(
            date: DateTime(2026, 9, 10),
            investmentValue: 100,
            stockValue: 100,
            fundValue: 0,
            bondValue: 0,
            cryptoValue: 0,
          ),
          InvestmentSnapshot(
            date: DateTime(2025, 1, 1),
            investmentValue: 50,
            stockValue: 50,
            fundValue: 0,
            bondValue: 0,
            cryptoValue: 0,
          ),
          // A future-dated row must never enter the chart.
          InvestmentSnapshot(
            date: DateTime(2026, 10, 1),
            investmentValue: 999,
            stockValue: 999,
            fundValue: 0,
            bondValue: 0,
            cryptoValue: 0,
          ),
        ],
        now: now,
        days: 30,
      );
      expect(trend.points.length, 2);
      expect(trend.points.first.value, 100);
      expect(trend.points.last.value, 120);
    });

    test('date keys are calendar-day strings', () {
      expect(
        InvestmentSnapshot.dateKey(DateTime(2026, 9, 7)),
        '2026-09-07',
      );
    });
  });
}
