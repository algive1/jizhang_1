import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/investments/data/investment_config.dart';
import 'package:jizhang_app/features/investments/data/market_data_provider.dart';
import 'package:jizhang_app/features/investments/data/quote_cache.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';
import 'package:jizhang_app/features/investments/domain/investment_quote.dart';

InvestmentQuote _quote(String symbol, double price) => InvestmentQuote(
  symbol: symbol,
  name: symbol,
  price: price,
  change: 0,
  changePercent: 0,
  timestamp: DateTime(2026, 9, 17, 10),
  type: InvestmentAssetType.stock,
);

void main() {
  group('MemoryQuoteCache', () {
    test('stores and returns by key', () async {
      final cache = MemoryQuoteCache();
      await cache.set('quote:stock:CN:600519', _quote('600519', 100));
      final hit = await cache.get('quote:stock:CN:600519');
      expect(hit!.price, 100);
      expect(await cache.get('quote:stock:CN:000001'), isNull);
    });

    test('expires an entry once its ttl has elapsed', () async {
      var now = DateTime(2026, 9, 17, 10);
      final cache = MemoryQuoteCache(clock: () => now);
      await cache.set(
        'quote:stock:CN:600519',
        _quote('600519', 100),
        ttl: const Duration(minutes: 3),
      );
      now = now.add(const Duration(minutes: 2));
      expect((await cache.get('quote:stock:CN:600519'))!.price, 100);
      now = now.add(const Duration(minutes: 2));
      expect(await cache.get('quote:stock:CN:600519'), isNull);
      expect(cache.size, 0, reason: 'an expired entry is dropped, not kept');
    });

    test('getMany returns only live entries and drops expired ones', () async {
      var now = DateTime(2026, 9, 17, 10);
      final cache = MemoryQuoteCache(clock: () => now);
      await cache.set(
        'a',
        _quote('a', 1),
        ttl: const Duration(minutes: 1),
      );
      await cache.set(
        'b',
        _quote('b', 2),
        ttl: const Duration(hours: 5),
      );
      now = now.add(const Duration(minutes: 2));
      final found = await cache.getMany(['a', 'b', 'c']);
      expect(found.keys, ['b']);
      expect(cache.size, 1);
    });

    test('remove and clear drop entries', () async {
      final cache = MemoryQuoteCache();
      await cache.set('a', _quote('a', 1));
      await cache.set('b', _quote('b', 2));
      await cache.remove('a');
      expect(await cache.get('a'), isNull);
      expect(await cache.get('b'), isNotNull);
      await cache.clear();
      expect(cache.size, 0);
    });

  });

  group('InvestmentConfig ttl policy', () {
    test('crypto refreshes fastest, funds slowest', () {
      final trading = DateTime(2026, 9, 17, 10);
      expect(
        InvestmentConfig.ttlFor(InvestmentAssetType.crypto, now: trading),
        const Duration(minutes: 2),
      );
      expect(
        InvestmentConfig.ttlFor(InvestmentAssetType.stock, now: trading),
        const Duration(minutes: 4),
      );
      expect(
        InvestmentConfig.ttlFor(InvestmentAssetType.bond, now: trading),
        const Duration(minutes: 20),
      );
      expect(
        InvestmentConfig.ttlFor(InvestmentAssetType.fund, now: trading),
        const Duration(minutes: 60),
      );
    });

    test('stocks use a longer ttl outside trading hours', () {
      // 2026-09-17 is a Thursday, so only the clock decides.
      final afterHours = DateTime(2026, 9, 17, 21);
      expect(InvestmentConfig.isTradingHours(afterHours), isFalse);
      expect(
        InvestmentConfig.ttlFor(InvestmentAssetType.stock, now: afterHours),
        const Duration(hours: 2),
      );

      final weekend = DateTime(2026, 9, 19, 10);
      expect(InvestmentConfig.isTradingHours(weekend), isFalse);

      final lunch = DateTime(2026, 9, 17, 12);
      expect(InvestmentConfig.isTradingHours(lunch), isFalse);

      final morning = DateTime(2026, 9, 17, 10);
      expect(InvestmentConfig.isTradingHours(morning), isTrue);
      final afternoon = DateTime(2026, 9, 17, 14);
      expect(InvestmentConfig.isTradingHours(afternoon), isTrue);
    });

    test('crypto ignores the trading calendar', () {
      final weekend = DateTime(2026, 9, 19, 3);
      expect(
        InvestmentConfig.ttlFor(InvestmentAssetType.crypto, now: weekend),
        const Duration(minutes: 2),
      );
    });
  });

  group('MockMarketDataProvider', () {
    final fixed = DateTime(2026, 9, 17, 11);
    late MockMarketDataProvider provider;

    setUp(() => provider = MockMarketDataProvider(clock: () => fixed));

    test('prices are deterministic for a symbol on a given day', () async {
      final first = await provider.getQuote('600519', InvestmentAssetType.stock);
      final second = await provider.getQuote('600519', InvestmentAssetType.stock);
      expect(first!.price, second!.price);
      expect(first.name, '贵州茅台');
    });

    test('different symbols get different prices', () async {
      final a = await provider.getQuote('600519', InvestmentAssetType.stock);
      final b = await provider.getQuote('000858', InvestmentAssetType.stock);
      expect(a!.price, isNot(closeTo(b!.price, 1e-6)));
    });

    test('a price is never zero or negative', () async {
      for (final type in InvestmentAssetType.values) {
        final quotes = await provider.getQuotes([
          for (final symbol in ['600519', '510300', '230023', 'BTC'])
            (symbol: symbol, type: type),
        ]);
        for (final quote in quotes.values) {
          expect(quote.price, greaterThan(0));
        }
      }
    });

    test('getQuotes answers a batch under the shared security keys', () async {
      final quotes = await provider.getQuotes([
        (symbol: '600519', type: InvestmentAssetType.stock),
        (symbol: '510300', type: InvestmentAssetType.fund),
      ]);
      expect(quotes.keys, containsAll([
        'quote:stock:CN:600519',
        'quote:fund:CN:510300',
      ]));
    });

    test('an unknown symbol still resolves to a stable quote', () async {
      final quote = await provider.getQuote(
        'MYCOIN',
        InvestmentAssetType.crypto,
      );
      expect(quote, isNotNull);
      expect(quote!.price, greaterThan(0));
    });

    test('search matches code, name and type filter', () async {
      expect((await provider.search('600519')).single.name, '贵州茅台');
      expect((await provider.search('茅台')).single.symbol, '600519');
      expect(
        (await provider.search('BTC')).single.type,
        InvestmentAssetType.crypto,
      );
      final fundsOnly = await provider.search(
        'ETF',
        type: InvestmentAssetType.fund,
      );
      expect(fundsOnly, isNotEmpty);
      expect(
        fundsOnly.every((r) => r.type == InvestmentAssetType.fund),
        isTrue,
      );
    });

    test('history returns a point per sampled day inside the range', () async {
      final month = await provider.getHistory(
        '600519',
        InvestmentAssetType.stock,
        InvestmentRange.month,
      );
      expect(month.first.date.isBefore(month.last.date), isTrue);
      expect(month.length, greaterThan(25));

      final year = await provider.getHistory(
        '600519',
        InvestmentAssetType.stock,
        InvestmentRange.year,
      );
      // A year is sampled weekly so a phone chart stays legible.
      expect(year.length, lessThan(60));
      expect(year.length, greaterThan(45));
    });

    test('simulateFailure raises so callers keep stale data', () async {
      provider.simulateFailure = true;
      await expectLater(
        provider.getQuote('600519', InvestmentAssetType.stock),
        throwsA(isA<MarketDataException>()),
      );
      await expectLater(
        provider.search('600519'),
        throwsA(isA<MarketDataException>()),
      );
    });
  });
}
