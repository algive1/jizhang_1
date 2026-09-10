// Visual QA entry point only. All demo data lives in memory, never in the user's ledger.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jizhang_app/app/app.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  final database = createMemoryDatabase();
  await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);
  final goals = await DriftGoalRepository(database).getAll();
  if (goals.isNotEmpty) {
    await DriftGoalRepository(database)
        .setMonthlyReservation(goals.first.id, 300);
  }
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const JizhangApp(),
    ),
  );
}
