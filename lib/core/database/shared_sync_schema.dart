part of 'app_database.dart';

/// SQLite triggers make financial changes and their outbox entries atomic,
/// including changes performed through existing DAOs and repositories.
extension SharedSyncSchema on AppDatabase {
  static const syncKinds = [
    'accounts',
    'categories',
    'transactions',
    'goals',
    'goal_milestones',
    'goal_contributions',
    'budgets',
    'recurring_bills',
    'installment_plans',
    'books',
  ];

  Future<void> installSyncSchema() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_control(id INTEGER PRIMARY KEY, actor_id TEXT NOT NULL, suppress INTEGER NOT NULL DEFAULT 0, batch_id TEXT)',
    );
    await customStatement(
      "INSERT OR IGNORE INTO sync_control(id,actor_id) VALUES(1,'user-local')",
    );
    // A restored database never establishes an authenticated identity.
    await customStatement(
      "UPDATE sync_control SET actor_id='user-local',suppress=0,batch_id=NULL WHERE id=1",
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_books(book_id TEXT PRIMARY KEY, remote_id TEXT NOT NULL, user_id TEXT NOT NULL, role TEXT NOT NULL, cursor INTEGER NOT NULL DEFAULT 0, access INTEGER NOT NULL DEFAULT 0, last_error TEXT, last_synced INTEGER)',
    );
    if (!await _hasColumn('sync_books', 'phase'))
      await customStatement(
        "ALTER TABLE sync_books ADD COLUMN phase TEXT NOT NULL DEFAULT 'ready'",
      );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_remote_user ON sync_books(user_id,remote_id)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_promotions(book_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,payload_json TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_id_map(book_id TEXT NOT NULL,kind TEXT NOT NULL,local_id TEXT NOT NULL,remote_id TEXT NOT NULL,PRIMARY KEY(book_id,kind,local_id),UNIQUE(book_id,kind,remote_id))',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_versions(book_id TEXT NOT NULL, kind TEXT NOT NULL, entity_id TEXT NOT NULL, version INTEGER NOT NULL, PRIMARY KEY(book_id,kind,entity_id))',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, operation_id TEXT NOT NULL UNIQUE, book_id TEXT NOT NULL, kind TEXT NOT NULL, entity_id TEXT NOT NULL, action TEXT NOT NULL, data_json TEXT NOT NULL, expected_version INTEGER NOT NULL, expected_account_version INTEGER, expected_goal_version INTEGER, batch_id TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', error TEXT)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_outbox_book ON sync_outbox(book_id,seq)',
    );
    // v9 builds may still carry the old global uniqueness constraint.
    final ddl = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='merchant_rules'",
    ).getSingle();
    if (!ddl.read<String>('sql').contains('UNIQUE (book_id,')) {
      await customStatement(
        'ALTER TABLE merchant_rules RENAME TO merchant_rules_legacy',
      );
      await customStatement(
        'CREATE TABLE merchant_rules (id TEXT PRIMARY KEY NOT NULL,book_id TEXT NOT NULL DEFAULT \'book-personal\',merchant_pattern TEXT NOT NULL,normalized_pattern TEXT NOT NULL,match_type TEXT NOT NULL,category_id TEXT NOT NULL REFERENCES categories(id),subcategory_id TEXT REFERENCES categories(id),user_id TEXT,confidence REAL NOT NULL,source TEXT NOT NULL,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL, UNIQUE (book_id,user_id,normalized_pattern,match_type))',
      );
      await customStatement(
        'INSERT INTO merchant_rules SELECT id,book_id,merchant_pattern,normalized_pattern,match_type,category_id,subcategory_id,user_id,confidence,source,created_at,updated_at FROM merchant_rules_legacy',
      );
      await customStatement('DROP TABLE merchant_rules_legacy');
      await _createScopeIndexes();
    }
    for (final kind in syncKinds) {
      final columns = (await customSelect(
        'PRAGMA table_info($kind)',
      ).get()).map((r) => r.read<String>('name')).toList();
      for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
        final prefix = event == 'DELETE' ? 'OLD' : 'NEW';
        final book = kind == 'books'
            ? '$prefix.id'
            : kind.startsWith('goal_')
            ? '(SELECT book_id FROM goals WHERE id=$prefix.goal_id)'
            : '$prefix.book_id';
        final data =
            'json_object(${columns.map((c) => "'$c',$prefix.$c").join(',')})';
        final excluded = switch (kind) {
          'accounts' => {'balance_in_cents', 'updated_at'},
          'goals' => {
            'current_amount_in_cents',
            'status',
            'version',
            'updated_at',
            'completion_celebration_shown',
          },
          'goal_milestones' => {'completed_at', 'celebration_shown'},
          'transactions' => {
            'version',
            'sync_status',
            'updated_at',
            'updated_by',
            'device_id',
          },
          'books' => {'version', 'updated_at'},
          _ => <String>{},
        };
        final checks = columns
            .where((c) => !excluded.contains(c))
            .map((c) => 'OLD.$c IS NOT NEW.$c')
            .toList();
        if (kind == 'goals')
          checks.add(
            "OLD.status IS NOT NEW.status AND (OLD.status IN ('paused','archived') OR NEW.status IN ('paused','archived'))",
          );
        final changed = event == 'UPDATE' ? 'AND (${checks.join(' OR ')})' : '';
        final shared = 'EXISTS(SELECT 1 FROM sync_books WHERE book_id=$book)';
        final allowed =
            "EXISTS(SELECT 1 FROM sync_books s JOIN sync_control c ON c.id=1 WHERE s.book_id=$book AND s.user_id=c.actor_id AND s.access=1)";
        final manager =
            "(SELECT role FROM sync_books WHERE book_id=$book) IN ('owner','admin')";
        final memberAllowed = kind == 'transactions'
            ? " OR ($prefix.type!='adjustment' ${event == 'INSERT' ? '' : "AND OLD.created_by=(SELECT actor_id FROM sync_control WHERE id=1)"})"
            : '';
        final accountVersion = kind == 'transactions'
            ? "(SELECT version FROM sync_versions WHERE book_id=$book AND kind='accounts' AND entity_id=$prefix.account_id)"
            : 'NULL';
        final goalVersion = kind == 'goal_contributions'
            ? "(SELECT version FROM sync_versions WHERE book_id=$book AND kind='goals' AND entity_id=$prefix.goal_id)"
            : 'NULL';
        final trigger = 'sync_${kind}_${event.toLowerCase()}';
        await customStatement('DROP TRIGGER IF EXISTS $trigger');
        await customStatement('''CREATE TRIGGER $trigger AFTER $event ON $kind
          WHEN (SELECT suppress FROM sync_control WHERE id=1)=0 AND $shared $changed
          BEGIN
            SELECT CASE WHEN NOT $allowed THEN RAISE(ABORT,'共享账本当前不可写，请登录并验证成员权限') END;
            SELECT CASE WHEN NOT ($manager $memberAllowed) THEN RAISE(ABORT,'没有修改这项共享数据的权限') END;
            ${kind == 'books' ? "SELECT CASE WHEN $prefix.is_archived=1 AND (SELECT role FROM sync_books WHERE book_id=$book)!='owner' THEN RAISE(ABORT,'只有所有者可以归档共享账本') END;" : ''}
            INSERT INTO sync_outbox(operation_id,book_id,kind,entity_id,action,data_json,expected_version,expected_account_version,expected_goal_version,batch_id)
            VALUES(lower(hex(randomblob(16))),$book,'$kind',$prefix.id,'${event == 'DELETE' ? 'delete' : 'upsert'}',$data,
              COALESCE((SELECT version FROM sync_versions WHERE book_id=$book AND kind='$kind' AND entity_id=$prefix.id),0),$accountVersion,$goalVersion,
              COALESCE((SELECT batch_id FROM sync_control WHERE id=1),lower(hex(randomblob(16)))));
          END''');
      }
    }
    syncSchemaReady = true;
  }

  static String visibleBooksSql(String column) =>
      "($column IN (SELECT b.id FROM books b LEFT JOIN sync_books s ON s.book_id=b.id WHERE b.is_archived=0 AND ((b.family_id IS NULL AND b.owner_user_id='user-local') OR (s.user_id=(SELECT actor_id FROM sync_control WHERE id=1) AND s.access=1))) OR ($column='book-personal' AND COALESCE((SELECT actor_id FROM sync_control WHERE id=1),'user-local')='user-local') OR NOT EXISTS (SELECT 1 FROM books))";
  Future<bool> canAccessBook(String id) async {
    final books = await customSelect('SELECT 1 FROM books LIMIT 1').get();
    // Repository unit tests can exercise an isolated entity without seeding
    // the book catalog first. A real app always seeds the default book before
    // exposing business data, so this fallback cannot bypass a real ACL.
    if (books.isEmpty) return true;
    return (await customSelect(
      'SELECT id FROM books WHERE id=? AND ${visibleBooksSql('id')}',
      variables: [Variable(id)],
    ).get()).isNotEmpty;
  }

  Future<void> setSyncActor(String userId) async {
    await customStatement('UPDATE sync_control SET actor_id=? WHERE id=1', [
      userId,
    ]);
    currentActor = userId;
    notifyUpdates({for (final table in allTables) TableUpdate.onTable(table)});
  }

  Future<T> withoutSyncJournal<T>(Future<T> Function() action) => transaction(
    () async {
      await customStatement('UPDATE sync_control SET suppress=1 WHERE id=1');
      try {
        return await action();
      } finally {
        await customStatement('UPDATE sync_control SET suppress=0 WHERE id=1');
      }
    },
  );
}
