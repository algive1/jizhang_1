import 'features/autobookkeeping/auto_bookkeeping_background.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/database/database_seeder.dart';
import 'core/models/recurring_bill.dart';
import 'features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'features/installments/data/installment_plan_repository.dart';
import 'features/investments/data/http_market_data_provider.dart';
import 'features/investments/data/investment_repository.dart';
import 'features/investments/data/quote_cache.dart';
import 'features/recurring/application/recurring_bill_notification_service.dart';
import 'features/recurring/data/recurring_bill_repository.dart';
import 'features/settings/data/app_settings_repository.dart';
import 'features/sharing/data/shared_api.dart';
import 'features/transactions/data/transactions_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  // A staged restore must be applied before runApp creates the foreground
  // database. Background FlutterEngine entrypoints deliberately skip this so
  // they can never replace a database that the foreground engine is using.
  final documents = await getApplicationDocumentsDirectory();
  await AppDatabase.applyPendingRestore(
    File(p.join(documents.path, AppDatabase.databaseFileName)),
  );
  runApp(const ProviderScope(child: JizhangApp()));
}

@pragma('vm:entry-point')
Future<void> autoBookkeepingMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await startAutoBookkeepingBackground();
}

/// Entry point used by Android's daily AlarmManager receiver. It deliberately
/// constructs the same repositories as the foreground app, then closes the
/// database before acknowledging the native receiver.
@pragma('vm:entry-point')
Future<void> scheduledFinanceMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('jizhang/finance_scheduler');
  AppDatabase? database;
  SharedApi? marketApi;
  try {
    database = AppDatabase();
    marketApi = SharedApi();
    await DatabaseSeeder(database).seedIfNeeded();
    final books = await (database.select(
      database.bookEntries,
    )..where((book) => book.isArchived.equals(false))).get();
    final accountBookByBook = {
      for (final book in books) book.id: book.assetSourceBookId,
    };
    final transactions = DriftTransactionRepository(
      database,
      accountBookIdForBook: (bookId) => accountBookByBook[bookId],
    );
    final settings = DriftAppSettingsRepository(database);
    final notifications = RecurringBillNotificationScheduler(
      channel: channel,
      background: true,
    );
    final allBills = <RecurringBill>[];
    for (final book in books) {
      final recurringRepository = DriftRecurringBillRepository(
        database,
        bookId: book.id,
      );
      await RecurringBillExecutionService(
        database,
        QuickBookkeepingService(transactions, settings),
        transactions,
        recurringRepository,
      ).processDueAutoRecords();
      allBills.addAll(await recurringRepository.getAll());
      await DriftInstallmentPlanRepository(
        database,
        bookId: book.id,
      ).processDueRepayments();
    }

    // Investment snapshots piggyback on the same daily isolate instead of
    // creating a second scheduler that could race the finance database. Books
    // that share a main asset book are collapsed to one idempotent write.
    final assetBookIds = <String>{
      for (final book in books) book.assetSourceBookId ?? book.id,
    };
    final market = HttpMarketDataProvider(marketApi);
    for (final assetBookId in assetBookIds) {
      await DriftInvestmentRepository(
        database,
        market,
        bookId: assetBookId,
        cache: MemoryQuoteCache(),
      ).ensureTodaySnapshot();
    }

    // Read the complete table for notification cleanup as well. This also
    // cancels reminders belonging to books archived since the last sync.
    allBills
      ..clear()
      ..addAll(
        await DriftRecurringBillRepository(
          database,
          bookId: '',
        ).getAllForNotification(),
      );
    await notifications.syncBills(allBills);
    await channel.invokeMethod<void>('completed');
  } catch (error) {
    try {
      await channel.invokeMethod<void>('failed', error.toString());
    } on Object {
      // There is no foreground UI to receive a second error here.
    }
  } finally {
    marketApi?.close();
    await database?.close();
  }
}
