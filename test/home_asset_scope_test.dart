import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/investments/data/investment_repository.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';
import 'package:jizhang_app/features/investments/domain/investment_holding.dart';
import 'package:jizhang_app/features/investments/domain/investment_portfolio.dart';

void main() {
  test(
    'homepage investment values include only opted-in holdings by currency',
    () async {
      final portfolio = InvestmentPortfolio(
        currency: 'CNY',
        categories: InvestmentPortfolio.empty.categories,
        positions: [
          _position('closed-cny', 'CNY', 100, included: false),
          _position('open-cny', 'CNY', 25, included: true),
          _position('closed-usd', 'USD', 9, included: false),
          _position('open-usd', 'USD', 3, included: true),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          investmentPortfolioProvider.overrideWith(
            (ref) => Stream.value(portfolio),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        investmentPortfolioProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(investmentValueByCurrencyProvider), {
        'CNY': 125,
        'USD': 12,
      });
      expect(container.read(includedInvestmentValueByCurrencyProvider), {
        'CNY': 25,
        'USD': 3,
      });
    },
  );

  test('new ledgers can opt into the primary ledger asset scope', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    );

    final shared = await repository.create(
      name: '旅行账本',
      type: BookType.personal,
      usePrimaryAssets: true,
    );
    final isolated = await repository.create(
      name: '装修账本',
      type: BookType.personal,
    );

    expect(shared.usesPrimaryAssets, isTrue);
    expect(shared.assetBookId, 'book-personal');
    expect(isolated.usesPrimaryAssets, isFalse);
    expect(isolated.assetBookId, isolated.id);
  });

  test(
    'account repository reads and writes the selected asset scope',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      );
      final shared = await repository.create(
        name: '共享资产账本',
        type: BookType.family,
        usePrimaryAssets: true,
      );
      final accounts = DriftAccountRepository(
        database,
        bookId: shared.assetBookId,
      );

      final primaryAccounts = await accounts.getAll();
      expect(primaryAccounts, isNotEmpty);
      expect(
        primaryAccounts.every((account) => account.bookId == 'book-personal'),
        isTrue,
      );
    },
  );

  test(
    'existing ledgers can switch between isolated and primary assets',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      );
      final book = await repository.create(
        name: '可切换账本',
        type: BookType.personal,
      );

      await repository.setUsePrimaryAssets(book.id, true);
      final sharedRow = await database.familyDao.findBook(book.id);
      expect(sharedRow?.assetSourceBookId, 'book-personal');

      await repository.setUsePrimaryAssets(book.id, false);
      final isolatedRow = await database.familyDao.findBook(book.id);
      expect(isolatedRow?.assetSourceBookId, isNull);
    },
  );
}

ValuedHolding _position(
  String id,
  String currency,
  double value, {
  required bool included,
}) => ValuedHolding(
  holding: InvestmentHolding(
    id: id,
    asset: InvestmentAsset(
      id: 'asset-$id',
      type: InvestmentAssetType.stock,
      symbol: id,
      name: id,
      market: currency == 'USD' ? 'NASDAQ' : 'CN',
      currency: currency,
    ),
    quantity: value,
    averageCost: 1,
    includeInHomeNetAssets: included,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  price: 1,
);
