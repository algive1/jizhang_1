import 'package:flutter/services.dart';
import '../../core/database/app_database.dart';
import 'auto_bookkeeping_repository.dart';

Future<void> startAutoBookkeepingBackground() async {
  const channel = MethodChannel('jizhang/autobookkeeping_worker');
  final database = AppDatabase();
  final repository = AutoBookkeepingRepository(database);
  channel.setMethodCallHandler((call) async {
    final data = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    switch (call.method) {
      case 'catalog': return repository.catalog(data['merchant'] as String);
      case 'duplicate': return repository.possibleDuplicate(data);
      case 'save': return repository.save(data);
      default: throw MissingPluginException();
    }
  });
  await channel.invokeMethod<void>('ready');
}
