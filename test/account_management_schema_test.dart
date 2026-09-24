import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/features/investments/data/investment_repository.dart';
import 'package:jizhang_app/features/investments/data/market_data_provider.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('database v22 creates account management extension tables', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final rows = await database.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name IN "
      "('account_management_meta','receivables','receivable_events')",
    ).get();

    expect(database.schemaVersion, 22);
    expect(
      rows.map((row) => row.read<String>('name')).toSet(),
      {
        'account_management_meta',
        'receivables',
        'receivable_events',
      },
    );

    final eventColumns = await database
        .customSelect('PRAGMA table_info(receivable_events)')
        .get();
    expect(
      eventColumns.map((row) => row.read<String>('name')),
      containsAll(['book_id', 'amount_in_cents']),
    );
    final receivableColumns = await database
        .customSelect('PRAGMA table_info(receivables)')
        .get();
    expect(
      receivableColumns.map((row) => row.read<String>('name')),
      contains('reminder_at'),
    );
    final metaColumns = await database
        .customSelect('PRAGMA table_info(account_management_meta)')
        .get();
    expect(
      metaColumns.map((row) => row.read<String>('name')),
      containsAll(['id', 'book_id', 'account_id', 'include_in_total']),
    );
    final triggers = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type='trigger' "
      "AND name IN ('sync_account_management_meta_insert',"
      "'sync_receivables_insert','sync_receivable_events_insert')",
    ).get();
    expect(triggers, hasLength(3));
  });

  test(
    'v21 upgrade preserves holdings and defaults inclusion to false',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'investment-v21-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/upgrade.sqlite');
      final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
      final repository = DriftInvestmentRepository(
        firstDatabase,
        MockMarketDataProvider(),
        bookId: 'book-personal',
      );
      final enabledHolding = await repository.addHolding(
        AddInvestmentRequest(
          type: InvestmentAssetType.crypto,
          symbol: 'MIGRATE',
          name: '迁移持仓',
          price: 3,
          quantity: 10,
          transactionDate: DateTime(2026, 9, 1),
          priceSource: PriceSource.manual,
          currentPrice: 4,
          includeInHomeNetAssets: true,
        ),
      );
      expect(enabledHolding.includeInHomeNetAssets, isTrue);
      await firstDatabase.close();

      final oldDatabase = sqlite.sqlite3.open(file.path);
      oldDatabase.execute(
        'ALTER TABLE investment_holdings DROP COLUMN include_in_home_net_assets',
      );
      oldDatabase.userVersion = 21;
      oldDatabase.close();

      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);
      final upgradedRepository = DriftInvestmentRepository(
        upgraded,
        MockMarketDataProvider(),
        bookId: 'book-personal',
      );
      final migrated = await upgradedRepository.getHolding(enabledHolding.id);
      expect(migrated, isNotNull);
      expect(migrated!.includeInHomeNetAssets, isFalse);
      expect((await upgradedRepository.getPortfolio()).investmentValue, 40);
    },
  );
}
