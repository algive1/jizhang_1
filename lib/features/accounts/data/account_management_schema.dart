import '../../../core/database/app_database.dart';

Future<void> ensureAccountManagementSchema(AppDatabase database) async {
  await database.customStatement(
    'CREATE TABLE IF NOT EXISTS account_management_meta ('
    'account_id TEXT PRIMARY KEY NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,'
    'fund_category TEXT NOT NULL DEFAULT "available",'
    'platform TEXT,'
    'restricted_status TEXT,'
    'expected_return_at INTEGER,'
    'include_in_total INTEGER NOT NULL DEFAULT 1,'
    'note TEXT,'
    'updated_at INTEGER NOT NULL'
    ')',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_account_management_meta_category '
    'ON account_management_meta(fund_category)',
  );
  await database.customStatement(
    'CREATE TABLE IF NOT EXISTS receivables ('
    'id TEXT PRIMARY KEY NOT NULL,'
    'book_id TEXT NOT NULL,'
    'name TEXT NOT NULL,'
    'type TEXT NOT NULL,'
    'counterparty TEXT NOT NULL,'
    'total_amount_in_cents INTEGER NOT NULL,'
    'received_amount_in_cents INTEGER NOT NULL DEFAULT 0,'
    'occurred_at INTEGER NOT NULL,'
    'expected_at INTEGER,'
    'status TEXT NOT NULL DEFAULT "pending",'
    'business_status TEXT NOT NULL DEFAULT "",'
    'remark TEXT,'
    'created_at INTEGER NOT NULL,'
    'updated_at INTEGER NOT NULL'
    ')',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_receivables_book_status '
    'ON receivables(book_id, status, expected_at)',
  );
  await database.customStatement(
    'CREATE TABLE IF NOT EXISTS receivable_events ('
    'id TEXT PRIMARY KEY NOT NULL,'
    'receivable_id TEXT NOT NULL REFERENCES receivables(id) ON DELETE CASCADE,'
    'event_type TEXT NOT NULL,'
    'title TEXT NOT NULL,'
    'description TEXT,'
    'created_at INTEGER NOT NULL'
    ')',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_receivable_events_receivable '
    'ON receivable_events(receivable_id, created_at DESC)',
  );
}
