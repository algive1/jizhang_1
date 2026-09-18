part of 'app_database.dart';

/// Forward-only v9 conversion. Cached balances include future-dated entries.
extension BookScopeMigration on AppDatabase {
  Future<void> _migrateBookScopes() async {
    final needsSplit = !await _hasColumn('accounts', 'book_id');
    for (final table in [
      'accounts',
      'categories',
      'budgets',
      'merchant_rules',
      'inbox_items',
    ]) {
      if (!await _hasColumn(table, 'book_id')) {
        await customStatement(
          "ALTER TABLE $table ADD COLUMN book_id TEXT NOT NULL DEFAULT 'book-personal'",
        );
      }
    }
    if (!await _hasColumn('accounts', 'opening_balance_in_cents')) {
      await customStatement(
        'ALTER TABLE accounts ADD COLUMN opening_balance_in_cents INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!needsSplit) return;
    final records = (await customSelect(
      'SELECT * FROM transactions',
    ).get()).map((r) => r.data).toList();
    final books = (await customSelect(
      'SELECT id FROM books',
    ).get()).map((r) => r.read<String>('id')).toSet();
    // Older schemas are seeded after migration, but the default identity is fixed.
    books.add('book-personal');
    if (records.any((r) => !books.contains(r['book_id']))) {
      throw StateError('迁移中止：流水引用了不存在的账本，请保留原数据库检查');
    }
    final accounts = (await customSelect(
      'SELECT * FROM accounts',
    ).get()).map((r) => r.data).toList();
    final accountIds = accounts.map((a) => a['id']).toSet();
    if (records.any(
      (r) =>
          !accountIds.contains(r['account_id']) ||
          (r['destination_account_id'] != null &&
              !accountIds.contains(r['destination_account_id'])),
    )) {
      throw StateError('迁移中止：流水引用了不存在的账户');
    }
    const knownTypes = {
      'expense',
      'income',
      'transfer',
      'refund',
      'reimbursement',
      'borrow',
      'lend',
      'repayment',
      'assetPurchase',
      'assetSale',
      'adjustment',
    };
    if (records.any(
      (r) =>
          !knownTypes.contains(r['type']) ||
          (r['type'] == 'transfer' && r['destination_account_id'] == null),
    ))
      throw StateError('迁移中止：无法解释流水类型或转账引用');
    final beforeByCurrency = <String, int>{};
    for (final account in accounts) {
      final currency = account['currency'] as String;
      beforeByCurrency[currency] =
          (beforeByCurrency[currency] ?? 0) +
          (account['balance_in_cents'] as int);
    }
    final effects = <String, Map<String, int>>{};
    void add(String account, String book, int amount) {
      final values = effects.putIfAbsent(account, () => {});
      values[book] = (values[book] ?? 0) + amount;
    }

    for (final row in records.where((r) => r['deleted_at'] == null)) {
      final amount = row['amount_in_cents'] as int;
      final type = row['type'] as String;
      final book = row['book_id'] as String;
      const outgoing = {
        'expense',
        'lend',
        'repayment',
        'assetPurchase',
        'transfer',
      };
      add(
        row['account_id'] as String,
        book,
        outgoing.contains(type) ? -amount : amount,
      );
      if (type == 'transfer')
        add(row['destination_account_id'] as String, book, amount);
    }
    for (final account in accounts) {
      final id = account['id'] as String;
      final delta = effects[id] ?? {};
      final opening =
          (account['balance_in_cents'] as int) -
          delta.values.fold(0, (a, b) => a + b);
      await customStatement(
        'UPDATE accounts SET opening_balance_in_cents = ?, balance_in_cents = ? WHERE id = ?',
        [opening, opening + (delta['book-personal'] ?? 0), id],
      );
      final usedBooks =
          records
              .where(
                (r) =>
                    r['account_id'] == id || r['destination_account_id'] == id,
              )
              .map((r) => r['book_id'] as String)
              .toSet()
            ..remove('book-personal');
      for (final book in usedBooks) {
        final newId = '$book::$id';
        await _insertMigrationRow('accounts', {
          ...account,
          'id': newId,
          'book_id': book,
          'opening_balance_in_cents': 0,
          'balance_in_cents': delta[book] ?? 0,
        });
        await customStatement(
          'UPDATE transactions SET account_id = ? WHERE book_id = ? AND account_id = ?',
          [newId, book, id],
        );
        await customStatement(
          'UPDATE transactions SET destination_account_id = ? WHERE book_id = ? AND destination_account_id = ?',
          [newId, book, id],
        );
      }
    }
    final categories = (await customSelect(
      'SELECT * FROM categories',
    ).get()).map((r) => r.data).toList();
    for (final book in books.where((b) => b != 'book-personal')) {
      // Root categories first, then children, retaining archived references.
      for (final row in [
        ...categories.where((r) => r['parent_id'] == null),
        ...categories.where((r) => r['parent_id'] != null),
      ]) {
        await _insertMigrationRow('categories', {
          ...row,
          'id': '$book::${row['id']}',
          'book_id': book,
          'parent_id': row['parent_id'] == null
              ? null
              : '$book::${row['parent_id']}',
        });
      }
      for (final column in ['category_id', 'subcategory_id']) {
        await customStatement(
          'UPDATE transactions SET $column = ? || $column WHERE book_id = ? AND $column IS NOT NULL',
          ['$book::', book],
        );
      }
    }
    await customStatement(
      "UPDATE inbox_items SET book_id = COALESCE((SELECT book_id FROM transactions WHERE transactions.id = inbox_items.transaction_id), 'book-personal')",
    );
    // Replace the old month/category UNIQUE constraint, including NULL totals.
    await customStatement('ALTER TABLE budgets RENAME TO budgets_v8');
    await customStatement(
      'CREATE TABLE budgets (id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL DEFAULT \'book-personal\', month_key TEXT NOT NULL, category_id TEXT REFERENCES categories(id), amount_in_cents INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
    );
    await customStatement(
      'INSERT INTO budgets SELECT id, book_id, month_key, category_id, amount_in_cents, created_at, updated_at FROM budgets_v8',
    );
    await customStatement('DROP TABLE budgets_v8');
    await customStatement(
      "INSERT OR REPLACE INTO app_settings(key,value,updated_at) VALUES ('migration.book_scopes', '账户按账本流水拆分，期初差额及旧预算保留在默认个人账本', strftime('%s','now'))",
    );
    final afterTotals = await customSelect(
      'SELECT currency,SUM(balance_in_cents) AS balance FROM accounts GROUP BY currency',
    ).get();
    if (afterTotals.any(
      (r) =>
          beforeByCurrency[r.read<String>('currency')] !=
          r.read<int>('balance'),
    ))
      throw StateError('迁移中止：分币种余额守恒校验失败');
    final violations = await customSelect('PRAGMA foreign_key_check').get();
    if (violations.isNotEmpty) throw StateError('迁移后引用校验失败，已中止升级');
  }

  Future<void> _insertMigrationRow(
    String table,
    Map<String, Object?> row,
  ) => customStatement(
    'INSERT INTO $table (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
    row.values.toList(),
  );

  Future<void> _createScopeIndexes() async {
    for (final table in [
      'accounts',
      'categories',
      'merchant_rules',
      'inbox_items',
    ]) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_${table}_book ON $table(book_id)',
      );
    }
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_budget_scope ON budgets(book_id,month_key,COALESCE(category_id,''))",
    );
  }
}
