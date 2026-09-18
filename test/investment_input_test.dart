import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/formatters/money_formatter.dart';
import 'package:jizhang_app/features/investments/data/market_data_provider.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';
import 'package:jizhang_app/features/investments/domain/investment_input.dart';

void main() {
  group('InvestmentInput.parsePrice', () {
    test('accepts the two-decimal cash shape too', () {
      expect(InvestmentInput.parsePrice('100'), 100);
      expect(InvestmentInput.parsePrice('36.78'), 36.78);
      expect(InvestmentInput.parsePrice(' 3.5 '), 3.5);
    });

    test('accepts the wider precision an investment price needs', () {
      // A fund NAV is quoted to three or four decimals.
      expect(InvestmentInput.parsePrice('2.3456'), 2.3456);
      expect(InvestmentInput.parsePrice('36.7859'), 36.7859);
      expect(InvestmentInput.parsePrice('100.1234'), 100.1234);
    });

    test('rejects malformed or out-of-range input', () {
      for (final bad in [
        '',
        'abc',
        '-5',
        '1.2.3',
        '1,000',
        '2.34567', // five decimals is beyond a quoted price
        '1000000000001',
      ]) {
        expect(
          InvestmentInput.parsePrice(bad),
          isNull,
          reason: '"$bad" must be rejected',
        );
      }
    });

    test(
      'is strictly wider than the cash parser it deliberately does not reuse',
      () {
        // The regression this guards: the app pre-fills a market price into the
        // 买入价格 field, and the cash parser would reject its own value,
        // leaving 保存 permanently blocked.
        const marketPrice = '36.7859';
        expect(MoneyFormatter.parseInput(marketPrice), isNull);
        expect(InvestmentInput.parsePrice(marketPrice), isNotNull);
      },
    );
  });

  group('InvestmentInput.parseQuantity', () {
    test('accepts fractional unit counts', () {
      expect(InvestmentInput.parseQuantity('100'), 100);
      expect(InvestmentInput.parseQuantity('0.5'), 0.5);
      // Crypto positions are routinely fractional.
      expect(InvestmentInput.parseQuantity('0.00012345'), 0.00012345);
      expect(InvestmentInput.parseQuantity('1234.5678'), 1234.5678);
    });

    test('rejects negatives and garbage', () {
      expect(InvestmentInput.parseQuantity('-1'), isNull);
      expect(InvestmentInput.parseQuantity('1.2.3'), isNull);
      expect(InvestmentInput.parseQuantity(''), isNull);
      expect(InvestmentInput.parseQuantity('0.000000001'), isNull);
    });
  });

  group('price formatting', () {
    test('trims to at least two decimals and keeps extra precision', () {
      expect(InvestmentInput.formatPriceLabel(100), '100.00');
      expect(InvestmentInput.formatPriceLabel(36.7859), '36.7859');
      expect(InvestmentInput.formatPriceLabel(2.3456), '2.3456');
      expect(InvestmentInput.formatPriceLabel(1234.5), '1,234.50');
      expect(InvestmentInput.formatPriceLabel(1234567.8912), '1,234,567.8912');
    });

    test('the editable form keeps every significant digit', () {
      expect(InvestmentInput.formatPrice(100), '100');
      expect(InvestmentInput.formatPrice(36.7859), '36.7859');
      expect(InvestmentInput.formatPrice(0.00012345), '0.00012345');
    });

    test('a formatted price round-trips through the parser', () {
      for (final value in [100.0, 36.7859, 2.3456, 0.5, 1234567.8912]) {
        expect(
          InvestmentInput.parsePrice(InvestmentInput.formatPrice(value)),
          value,
          reason: '$value must survive format → parse',
        );
      }
    });
  });

  group('every mock price is accepted by the add form', () {
    test('across all four asset classes', () async {
      final provider = MockMarketDataProvider(
        clock: () => DateTime(2026, 9, 17, 11),
      );
      // This is the real-device defect: whatever the market source returns must
      // pass the very validator the form applies to its own pre-filled value.
      for (final type in InvestmentAssetType.values) {
        final results = await provider.search('', type: type, limit: 50);
        expect(results, isNotEmpty, reason: '$type has a catalogue');
        for (final result in results) {
          final text = InvestmentInput.formatPrice(result.price);
          expect(
            InvestmentInput.parsePrice(text),
            isNotNull,
            reason:
                '$type ${result.symbol}: form pre-fills "$text" from a price of '
                '${result.price} and must accept it',
          );
        }
      }
    });
  });
}
