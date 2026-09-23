import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';

void main() {
  test('database v21 creates account management extension tables', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final rows = await database.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name IN "
      "('account_management_meta','receivables','receivable_events')",
    ).get();

    expect(database.schemaVersion, 21);
    expect(
      rows.map((row) => row.read<String>('name')).toSet(),
      {
        'account_management_meta',
        'receivables',
        'receivable_events',
      },
    );

    final columns = await database
        .customSelect('PRAGMA table_info(receivable_events)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('amount_in_cents'),
    );
  });
}
