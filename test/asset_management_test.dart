import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/accounts/domain/asset_overview.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';

void main() {
  test(
    'credit expense, repayment, calibration and archive preserve ledger totals',
    () async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      final accounts = DriftAccountRepository(db);
      final transactions = DriftTransactionRepository(db);
      await accounts.create(_account('bank', 2000));
      await accounts.create(
        _account('credit', -1000, type: AccountType.creditCard),
      );
      await transactions.create(
        _record('expense', TransactionType.expense, 100, 'credit'),
      );
      expect(
        (await accounts.getAll()).firstWhere((a) => a.id == 'credit').balance,
        -1100,
      );
      await transactions.create(
        _record(
          'repay',
          TransactionType.transfer,
          500,
          'bank',
          destination: 'credit',
        ),
      );
      var total = AssetOverview.group(await accounts.getAll()).single;
      expect(total.assets, 1500);
      expect(total.liabilities, 600);
      expect(total.netAssets, 900);
      await accounts.reconcileBalance('bank', 1200.25);
      await accounts.reconcileBalance('bank', 1200.25);
      await accounts.reconcileBalance('bank', 1400.50);
      final records = await transactions.getAll();
      expect(
        records.where((r) => r.type == TransactionType.adjustment).length,
        2,
      );
      final analysis = const StatisticalAnalysisService().analyze(records);
      expect(analysis.totalIncome, 0);
      expect(analysis.totalExpense, 100);
      total = AssetOverview.group(await accounts.getAll()).single;
      expect(total.netAssets, 800.50);
      await accounts.archive('bank');
      expect(
        AssetOverview.group(await accounts.getAll()).single.netAssets,
        800.50,
      );
      expect((await accounts.getActive()).length, 1);
      await accounts.restore('bank');
      expect(
        AssetOverview.group(await accounts.getAll()).single.netAssets,
        800.50,
      );
      expect((await accounts.getActive()).length, 2);
    },
  );

  test('currency groups and deposit forms do not mix balances', () {
    final groups = AssetOverview.group([
      _account('fixed', 100.01, form: AssetForm.termDeposit),
      _account('current', 20.02, form: AssetForm.demandDeposit),
      _account('usd', 99, currency: 'USD'),
      _account('wallet', -10),
    ]);
    expect(groups.map((g) => g.currency), ['CNY', 'USD']);
    expect(groups.first.assets, 120.03);
    expect(groups.first.netAssets, 110.03);
    expect(groups.first.byForm[AssetForm.termDeposit], 100.01);
    expect(groups.first.hasUnverifiedNegativeBalance, isTrue);
    expect(groups.last.assets, 99);
  });

  test(
    'v6 accounts migrate to unspecified form without changing signed balances',
    () async {
      final dir = await Directory.systemTemp.createTemp('asset-migration-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/ledger.sqlite');
      // Reconstruct v6 by removing every field added after that version.
      final current = AppDatabase.forTesting(NativeDatabase(file));
      await DriftAccountRepository(current).create(_account('kept', -123.45));
      await current.close();
      final old = sqlite.sqlite3.open(file.path);
      for (final row in old.select(
        "SELECT name FROM sqlite_master WHERE type='trigger'",
      )) {
        old.execute('DROP TRIGGER ${row['name']}');
      }
      old.execute('ALTER TABLE accounts DROP COLUMN asset_form');
      old.execute('ALTER TABLE goals DROP COLUMN sort_order');
      old.execute('ALTER TABLE goals DROP COLUMN monthly_reservation_in_cents');
      old.userVersion = 6;
      old.close();
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(migrated.close);
      final account = (await DriftAccountRepository(migrated).getAll()).single;
      expect(account.balance, -123.45);
      expect(account.assetForm, AssetForm.unspecified);
      expect(migrated.schemaVersion, 10);
    },
  );
}

Account _account(
  String id,
  double balance, {
  AccountType type = AccountType.debitCard,
  AssetForm form = AssetForm.unspecified,
  String currency = 'CNY',
}) => Account(
  id: id,
  name: id,
  type: type,
  balance: balance,
  currency: currency,
  icon: 'wallet',
  color: 0xff73963b,
  sortOrder: 0,
  isArchived: false,
  assetForm: form,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TransactionRecord _record(
  String id,
  TransactionType type,
  double amount,
  String account, {
  String? destination,
}) => TransactionRecord(
  id: id,
  bookId: 'book-personal',
  type: type,
  amount: amount,
  accountId: account,
  destinationAccountId: destination,
  occurredAt: DateTime.now(),
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
