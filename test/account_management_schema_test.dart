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
}
