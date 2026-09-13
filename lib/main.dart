import 'features/autobookkeeping/auto_bookkeeping_background.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/database/database_seeder.dart';
import 'features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'features/installments/data/installment_plan_repository.dart';
import 'features/recurring/data/recurring_bill_repository.dart';
import 'features/settings/data/app_settings_repository.dart';
import 'features/transactions/data/transactions_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
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
  try {
    database = AppDatabase();
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
      await DriftInstallmentPlanRepository(
        database,
        bookId: book.id,
      ).processDueRepayments();
    }
    await channel.invokeMethod<void>('completed');
  } catch (error) {
    try {
      await channel.invokeMethod<void>('failed', error.toString());
    } on Object {
      // There is no foreground UI to receive a second error here.
    }
  } finally {
    await database?.close();
  }
}
