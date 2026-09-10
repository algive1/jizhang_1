import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database_seeder.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final databaseBootstrapProvider = FutureProvider<void>((ref) async {
  await DatabaseSeeder(ref.watch(databaseProvider)).seedIfNeeded();
});

AppDatabase createMemoryDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}
