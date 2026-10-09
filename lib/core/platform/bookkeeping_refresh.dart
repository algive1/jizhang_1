import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../database/app_database.dart';

/// Writes in another Flutter engine share SQLite, but not Drift's stream notifications.
void refreshExternalBookkeepingData(AppDatabase database) {
  database.notifyUpdates({
    for (final table in database.allTables) TableUpdate.onTable(table),
  });
}

class BookkeepingRefreshBridge {
  BookkeepingRefreshBridge(this.onChanged);
  final Future<void> Function() onChanged;
  static const _channel = MethodChannel('jizhang/bookkeeping_changes');
  int? _revision;

  void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await _refresh(call.arguments);
    });
  }

  Future<void> check() async {
    try {
      await _refresh(await _channel.invokeMethod<int>('revision'));
    } on MissingPluginException {
      // Other platforms have a single foreground connection.
    }
  }

  Future<void> _refresh(Object? value) async {
    if (value is! int || value == _revision) return;
    await onChanged();
    _revision = value;
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
