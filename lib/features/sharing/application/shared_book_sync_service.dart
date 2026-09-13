import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/entity_id.dart';
import '../../books/data/book_repository.dart';
import '../data/session_repository.dart';
import '../data/shared_api.dart';
import '../data/shared_id_map.dart';

typedef Json = Map<String, dynamic>;

class SharedBookSyncService {
  SharedBookSyncService(this.database, this.session);
  final AppDatabase database;
  final SessionRepository session;
  SharedApi get api => session.api;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  Timer? _timer;
  Timer? _debounce;
  StreamSubscription? _databaseChanges;
  StreamSubscription? _sessionChanges;
  Future<void>? _running;
  int _failures = 0;
  DateTime? _retryAfter;
  bool _foreground = false;
  bool _applying = false;
  bool _started = false;
  bool _disposed = false;
  String? lastError;
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await session.initialize();
    _sessionChanges = session.watch().listen((_) {
      requestSync();
    });
    _databaseChanges = database.tableUpdates().listen((_) {
      if (!_applying) {
        if (!_disposed) _changes.add(null);
        requestSync();
      }
    });
    setForeground(true);
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _timer?.cancel();
    _debounce?.cancel();
    if (foreground) {
      _timer = Timer.periodic(const Duration(seconds: 15), (_) {
        requestSync();
      });
      requestSync();
    }
  }

  void requestSync() {
    if (!_foreground || session.user == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (_retryAfter == null || DateTime.now().isAfter(_retryAfter!))
        unawaited(sync());
    });
  }

  Future<void> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);
  Future<void> _sync() async {
    await session.initialize();
    if (session.user == null) return;
    try {
      final userId = session.user!.id;
      _applying = true;
      await _flushPromotions(userId);
      final remote = await api.request('/books');
      final books = (remote['books'] as List).cast<Json>();
      final known = await states();
      _applying = true;
      for (final state in known.where((s) => s['user_id'] == userId)) {
        if (!books.any(
          (b) => b['id'] == state['remote_id'] && b['is_archived'] == 0,
        )) {
          await database.customStatement(
            'UPDATE sync_books SET access=0,last_error=? WHERE book_id=?',
            ['成员权限已撤销或账本已归档', state['book_id']],
          );
        }
      }
      for (final book in books) {
        if (book['is_archived'] == 1) continue;
        var state = known
            .where(
              (s) => s['remote_id'] == book['id'] && s['user_id'] == userId,
            )
            .firstOrNull;
        final local =
            state?['book_id'] as String? ?? 'shared:$userId:${book['id']}';
        if (state == null) {
          await database.customStatement(
            'INSERT INTO sync_books(book_id,remote_id,user_id,role,access) VALUES(?,?,?,?,0)',
            [local, book['id'], userId, book['role']],
          );
        }
        await database.customStatement(
          'UPDATE sync_books SET role=?,access=1 WHERE book_id=?',
          [book['role'], local],
        );
        state = {
          'book_id': local,
          'remote_id': book['id'],
          'user_id': userId,
          'role': book['role'],
        };
        try {
          await _syncBook(state);
        } on SharedApiException catch (e) {
          if (e.status == 401) rethrow;
          if (e.status == 403)
            await database.customStatement(
              'UPDATE sync_books SET access=0 WHERE book_id=?',
              [local],
            );
          await database.customStatement(
            'UPDATE sync_books SET last_error=? WHERE book_id=?',
            [e.message, local],
          );
        }
      }
      database.notifyUpdates({TableUpdate.onTable(database.bookEntries)});
      _failures = 0;
      _retryAfter = null;
      lastError = null;
    } on SharedApiException catch (e) {
      lastError = e.message;
      if (e.status == 401) await session.invalidate();
      _backoff();
    } catch (e) {
      lastError = '同步未完成：$e';
      _backoff();
    } finally {
      _applying = false;
      if (!_disposed) _changes.add(null);
    }
  }

  void _backoff() {
    _failures = (_failures + 1).clamp(1, 6);
    _retryAfter = DateTime.now().add(Duration(seconds: 5 * (1 << _failures)));
  }

  Future<List<Json>> states() async =>
      (await database.customSelect('SELECT * FROM sync_books').get())
          .map((r) => r.data)
          .toList();
  Future<List<Json>> pending(String book) async =>
      (await database
              .customSelect(
                'SELECT * FROM sync_outbox WHERE book_id=? ORDER BY seq',
                variables: [Variable(book)],
              )
              .get())
          .map((r) => r.data)
          .toList();
  Future<void> _syncBook(Json state) async {
    final local = state['book_id'] as String,
        remote = state['remote_id'] as String;
    // Always reconcile with the server before submitting restored/queued work.
    // Cursor endpoint avoids downloading an unchanged full snapshot.
    final stored =
        (await database
                .customSelect(
                  'SELECT cursor,access FROM sync_books WHERE book_id=?',
                  variables: [Variable(local)],
                )
                .getSingle())
            .data;
    final delta = await api.request(
      '/books/$remote/changes?cursor=${stored['cursor']}',
    );
    if ((delta['changes'] as List).isNotEmpty ||
        stored['cursor'] == 0 ||
        (await database.familyDao.findBook(local)) == null) {
      await _applySnapshot(
        local,
        remote,
        await api.request('/books/$remote/snapshot'),
      );
    }
    while (true) {
      final queue = await pending(local);
      if (queue.isEmpty || queue.first['status'] != 'pending') break;
      final batch = queue
          .takeWhile((r) => r['batch_id'] == queue.first['batch_id'])
          .toList();
      final map = await _idMap(local, remote);
      final operations = batch.map((r) {
        final kind = r['kind'] as String;
        return {
          'operationId': r['operation_id'],
          'kind': kind,
          'id': map.encode(kind, r['entity_id'] as String),
          'action': r['action'],
          'expectedVersion': r['expected_version'],
          if (r['expected_account_version'] != null)
            'expectedAccountVersion': r['expected_account_version'],
          if (r['expected_goal_version'] != null)
            'expectedGoalVersion': r['expected_goal_version'],
          'data': map.row(
            kind,
            _sanitize(kind, jsonDecode(r['data_json'] as String) as Json),
            upload: true,
          ),
        };
      }).toList();
      try {
        final result = await api.request(
          '/books/$remote/mutations',
          method: 'POST',
          body: {'operations': operations},
        );
        await database.withoutSyncJournal(() async {
          for (final row in batch) {
            await database.customStatement(
              'DELETE FROM sync_outbox WHERE operation_id=?',
              [row['operation_id']],
            );
          }
          // Only advance locally dependent edits after our own successful commit.
          final entities = (result['entities'] as List).cast<Json>();
          for (final ack in (result['applied'] as List).cast<Json>()) {
            final kind = ack['kind'] as String,
                id = map.decode(kind, ack['id'] as String);
            final version = kind == 'books'
                ? (result['book'] as Json)['version']
                : entities.firstWhere(
                    (e) => e['kind'] == kind && e['id'] == ack['id'],
                  )['version'];
            await database.customStatement(
              "UPDATE sync_outbox SET expected_version=? WHERE book_id=? AND kind=? AND entity_id=? AND status='pending'",
              [version, local, kind, id],
            );
          }
          await _applySnapshot(local, remote, result);
        });
      } on SharedApiException catch (e) {
        if (e.status == 409 || e.status == 400 || e.status == 403) {
          await database.customStatement(
            'UPDATE sync_outbox SET status=?,error=? WHERE book_id=? AND batch_id=?',
            [
              e.status == 409 ? 'conflict' : 'rejected',
              jsonEncode({'message': e.message, 'details': e.details}),
              local,
              batch.first['batch_id'],
            ],
          );
          await database.customStatement(
            'UPDATE sync_books SET last_error=? WHERE book_id=?',
            [e.message, local],
          );
        }
        rethrow;
      }
    }
    await database.customStatement(
      'UPDATE sync_books SET last_synced=?,last_error=CASE WHEN EXISTS(SELECT 1 FROM sync_outbox WHERE book_id=? AND status!=\'pending\') THEN last_error ELSE NULL END WHERE book_id=?',
      [DateTime.now().millisecondsSinceEpoch ~/ 1000, local, local],
    );
  }

  Json _sanitize(String kind, Json original) {
    final data = Json.of(original);
    if (kind == 'transactions') {
      data['visibility'] = 'shared';
      data['device_id'] = null;
      data['sync_status'] = 'synced';
      final metadata = data['metadata_json'] == null
          ? null
          : jsonDecode(data['metadata_json'] as String);
      data['metadata_json'] = metadata is Map && metadata['tags'] is List
          ? jsonEncode({'tags': metadata['tags']})
          : null;
    }
    if (kind == 'goals') data['cover_path'] = null;
    return data;
  }

  Future<List<Json>> _bookRows(String book) async {
    final result = <Json>[];
    for (final kind in SharedSyncSchema.syncKinds.where((k) => k != 'books')) {
      final where = kind.startsWith('goal_')
          ? 'goal_id IN (SELECT id FROM goals WHERE book_id=?)'
          : 'book_id=?';
      final rows = await database
          .customSelect(
            'SELECT * FROM $kind WHERE $where',
            variables: [Variable(book)],
          )
          .get();
      for (final row in rows) {
        result.add({'kind': kind, 'id': row.data['id'], 'data': row.data});
      }
    }
    return result;
  }

  Future<void> enableSharing(String local) async {
    await session.initialize();
    if (session.user == null) throw StateError('请先登录');
    await _reservePromotion(local);
    await sync();
    if ((await database
            .customSelect(
              'SELECT book_id FROM sync_promotions WHERE book_id=?',
              variables: [Variable(local)],
            )
            .get())
        .isNotEmpty)
      throw StateError(lastError ?? '首次共享尚未完成，已保存在本机，可点击同步重试');
  }

  Future<void> _reservePromotion(String local) =>
      database.withoutSyncJournal(() async {
        final existing = await database
            .customSelect(
              'SELECT book_id FROM sync_promotions WHERE book_id=?',
              variables: [Variable(local)],
            )
            .getSingleOrNull();
        if (existing != null) return;
        final book = await database.familyDao.findBook(local);
        if (book == null ||
            book.isArchived ||
            book.type == 'personal' ||
            book.familyId != null)
          throw StateError('仅本地家庭或企业账本可以启用共享');
        final setting = 'sharing.promotion.$local';
        final remote =
            await database.appSettingsDao.getValue(setting) ?? newEntityId();
        final bound = await database
            .customSelect(
              'SELECT book_id FROM sync_books WHERE user_id=? AND remote_id=?',
              variables: [Variable(session.user!.id), Variable(remote)],
            )
            .getSingleOrNull();
        if (bound != null) throw StateError('该共享账本已在书架中，请切换到现有共享账本，避免旧副本覆盖新账');
        await database.appSettingsDao.setValue(setting, remote, DateTime.now());
        // Reserve the local book before reading its rows.  From this point on,
        // the database triggers journal every concurrent local mutation into
        // the promotion outbox, so a write cannot fall through the snapshot
        // hand-off window.
        await database.customStatement(
          'INSERT INTO sync_books(book_id,remote_id,user_id,role,access,phase,last_error) VALUES(?,?,?,?,1,?,?)',
          [local, remote, session.user!.id, 'owner', 'promoting', '首次共享快照待上传'],
        );
        final map = await _idMap(local, remote);
        final rows = await _bookRows(local);
        final entities = rows.map((e) {
          final kind = e['kind'] as String;
          return {
            'kind': kind,
            'id': map.encode(kind, e['id'] as String),
            'data': map.row(
              kind,
              _sanitize(kind, e['data'] as Json),
              upload: true,
            ),
          };
        }).toList();
        final payload = {
          'id': remote,
          'name': book.name,
          'type': book.type,
          'asset_source_book_id': book.assetSourceBookId,
          'entities': entities,
        };
        await database.customStatement(
          'INSERT INTO sync_promotions VALUES(?,?,?)',
          [local, session.user!.id, jsonEncode(payload)],
        );
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await database.customStatement(
          'INSERT INTO families(id,name,owner_user_id,created_at,updated_at,version) VALUES(?,?,?,?,?,1)',
          [remote, book.name, session.user!.id, now, now],
        );
        await database.customStatement(
          'UPDATE books SET family_id=?,owner_user_id=? WHERE id=?',
          [remote, session.user!.id, local],
        );
        database.notifyUpdates({TableUpdate.onTable(database.bookEntries)});
      });
  Future<void> _flushPromotions(String userId) async {
    final rows = await database
        .customSelect(
          'SELECT p.*,s.remote_id FROM sync_promotions p JOIN sync_books s ON s.book_id=p.book_id WHERE p.user_id=?',
          variables: [Variable(userId)],
        )
        .get();
    for (final row in rows) {
      final local = row.read<String>('book_id'),
          remote = row.read<String>('remote_id');
      final snapshot = await api.request(
        '/books',
        method: 'POST',
        body: jsonDecode(row.read<String>('payload_json')),
      );
      await database.withoutSyncJournal(() async {
        final map = await _idMap(local, remote);
        for (final initial
            in (snapshot['initialVersions'] as List).cast<Json>()) {
          final kind = initial['kind'] as String,
              id = map.decode(kind, initial['id'] as String);
          await database.customStatement(
            'UPDATE sync_outbox SET expected_version=? WHERE book_id=? AND kind=? AND entity_id=? AND expected_version=0',
            [initial['version'], local, kind, id],
          );
          if (kind == 'accounts')
            await database.customStatement(
              "UPDATE sync_outbox SET expected_account_version=? WHERE book_id=? AND json_extract(data_json,'\$.account_id')=? AND expected_account_version IS NULL",
              [initial['version'], local, id],
            );
          if (kind == 'goals')
            await database.customStatement(
              "UPDATE sync_outbox SET expected_goal_version=? WHERE book_id=? AND json_extract(data_json,'\$.goal_id')=? AND expected_goal_version IS NULL",
              [initial['version'], local, id],
            );
        }
        await _applySnapshot(local, remote, snapshot);
        await database.customStatement(
          "UPDATE sync_books SET phase='ready',last_error=NULL WHERE book_id=?",
          [local],
        );
        await database.customStatement(
          'DELETE FROM sync_promotions WHERE book_id=?',
          [local],
        );
      });
    }
  }

  Future<SharedIdMap> _idMap(String local, String remote) async {
    final base = SharedIdMap(local, remote);
    for (final entity in await _bookRows(local)) {
      final kind = entity['kind'] as String, id = entity['id'] as String;
      await database.customStatement(
        'INSERT OR IGNORE INTO sync_id_map VALUES(?,?,?,?)',
        [local, kind, id, base.encode(kind, id)],
      );
    }
    final rows = await database
        .customSelect(
          'SELECT * FROM sync_id_map WHERE book_id=?',
          variables: [Variable(local)],
        )
        .get();
    return SharedIdMap(local, remote, {
      for (final r in rows)
        '${r.data['kind']}:${r.data['remote_id']}':
            r.data['local_id'] as String,
    });
  }

  Future<void> _upsert(String kind, Json data) async {
    if (!SharedSyncSchema.syncKinds.contains(kind))
      throw StateError('不支持的共享数据类型');
    final columns =
        (await database.customSelect('PRAGMA table_info($kind)').get())
            .map((r) => r.read<String>('name'))
            .toSet();
    if (data.keys.any((k) => !columns.contains(k)))
      throw StateError('共享数据包含不支持的字段');
    final row = Json.of(data);
    if (kind == 'books') row['family_id'] = data['family_id'];
    if (kind == 'goals' || kind == 'transactions') {
      final old = await database
          .customSelect(
            'SELECT * FROM $kind WHERE id=?',
            variables: [Variable(row['id'] as String)],
          )
          .getSingleOrNull();
      if (old != null) {
        if (kind == 'goals') row['cover_path'] = old.data['cover_path'];
        if (kind == 'transactions' && old.data['metadata_json'] != null) {
          final previous = jsonDecode(old.data['metadata_json'] as String);
          final incoming = row['metadata_json'] == null
              ? {}
              : jsonDecode(row['metadata_json'] as String);
          if (previous is Map && incoming is Map) {
            row['metadata_json'] = jsonEncode({...previous, ...incoming});
          }
        }
      }
    }
    await database.customStatement(
      'INSERT INTO $kind (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')}) ON CONFLICT(id) DO UPDATE SET ${row.keys.where((k) => k != 'id').map((k) => '$k=excluded.$k').join(',')}',
      row.values.toList(),
    );
  }

  Future<void> _applySnapshot(
    String local,
    String remote,
    Json snapshot,
  ) => database.withoutSyncJournal(() async {
    final map = await _idMap(local, remote);
    final book = map.row('books', snapshot['book'] as Json, upload: false);
    await database.customStatement(
      'INSERT INTO families(id,name,owner_user_id,created_at,updated_at,version) VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,updated_at=excluded.updated_at,version=excluded.version',
      [
        remote,
        book['name'],
        book['owner_user_id'],
        book['created_at'],
        book['updated_at'],
        book['version'],
      ],
    );
    await _upsert('books', book);
    final entities = (snapshot['entities'] as List).cast<Json>().toList();
    const rank = {
      'accounts': 0,
      'categories': 1,
      'goals': 2,
      'transactions': 3,
      'goal_milestones': 4,
      'goal_contributions': 5,
      'budgets': 6,
      'recurring_bills': 7,
      'installment_plans': 8,
    };
    entities.sort((a, b) {
      final order = rank[a['kind']]!.compareTo(rank[b['kind']]!);
      if (order != 0) return order;
      return ((a['data'] as Json)['parent_id'] == null ? 0 : 1).compareTo(
        (b['data'] as Json)['parent_id'] == null ? 0 : 1,
      );
    });
    for (final e in entities) {
      final kind = e['kind'] as String,
          id = map.decode(kind, e['id'] as String);
      final data = map.row(kind, e['data'] as Json, upload: false);
      await database.customStatement(
        'INSERT OR IGNORE INTO sync_id_map VALUES(?,?,?,?)',
        [local, kind, id, e['id']],
      );
      if (e['deleted'] == true) {
        await database.customStatement('DELETE FROM $kind WHERE id=?', [id]);
      } else {
        if (kind == 'budgets')
          await database.customStatement(
            'DELETE FROM budgets WHERE book_id=? AND month_key=? AND category_id IS ? AND id!=?',
            [local, data['month_key'], data['category_id'], id],
          );
        await _upsert(kind, data);
      }
      await database.customStatement(
        'INSERT INTO sync_versions VALUES(?,?,?,?) ON CONFLICT(book_id,kind,entity_id) DO UPDATE SET version=excluded.version',
        [local, kind, id, e['version']],
      );
    }
    await database.customStatement(
      'INSERT INTO sync_versions VALUES(?,?,?,?) ON CONFLICT(book_id,kind,entity_id) DO UPDATE SET version=excluded.version',
      [local, 'books', local, book['version']],
    );
    // Pending edits remain visible as local drafts and are never represented as
    // server-confirmed data. Their captured expected versions remain unchanged.
    for (final row in await pending(local)) {
      final kind = row['kind'] as String,
          data = jsonDecode(row['data_json'] as String) as Json;
      if (row['action'] == 'delete') {
        await database.customStatement('DELETE FROM $kind WHERE id=?', [
          row['entity_id'],
        ]);
      } else {
        if (kind == 'budgets')
          await database.customStatement(
            'DELETE FROM budgets WHERE book_id=? AND month_key=? AND category_id IS ? AND id!=?',
            [local, data['month_key'], data['category_id'], row['entity_id']],
          );
        await _upsert(kind, data);
      }
    }
    final keep = <String>{
      for (final e in entities)
        '${e['kind']}:${map.decode(e['kind'] as String, e['id'] as String)}',
    };
    for (final row in await pending(local)) {
      keep.add('${row['kind']}:${row['entity_id']}');
    }
    final localRows = await _bookRows(local);
    const deleteOrder = {
      'installment_plans': 0,
      'recurring_bills': 1,
      'goal_contributions': 2,
      'goal_milestones': 3,
      'budgets': 4,
      'transactions': 5,
      'goals': 6,
      'categories': 7,
      'accounts': 8,
    };
    localRows.sort((a, b) {
      final order = deleteOrder[a['kind']]!.compareTo(deleteOrder[b['kind']]!);
      return order != 0
          ? order
          : ((b['data'] as Json)['parent_id'] == null ? 0 : 1).compareTo(
              (a['data'] as Json)['parent_id'] == null ? 0 : 1,
            );
    });
    for (final entity in localRows) {
      if (!keep.contains('${entity['kind']}:${entity['id']}'))
        await database.customStatement(
          'DELETE FROM ${entity['kind']} WHERE id=?',
          [entity['id']],
        );
    }
    await _recalculate(local);
    await database.customStatement(
      'UPDATE sync_books SET cursor=?,role=?,access=? WHERE book_id=?',
      [
        snapshot['cursor'],
        snapshot['role'],
        book['is_archived'] == 1 ? 0 : 1,
        local,
      ],
    );
    database.notifyUpdates({
      for (final table in database.allTables) TableUpdate.onTable(table),
    });
  });
  Future<void> _recalculate(String book) async {
    await database.customStatement(
      "UPDATE accounts SET balance_in_cents=opening_balance_in_cents+COALESCE((SELECT SUM(CASE WHEN type IN ('expense','lend','repayment','assetPurchase','transfer') THEN -amount_in_cents ELSE amount_in_cents END) FROM transactions WHERE account_id=accounts.id AND deleted_at IS NULL),0)+COALESCE((SELECT SUM(amount_in_cents) FROM transactions WHERE destination_account_id=accounts.id AND type IN ('transfer','repayment') AND deleted_at IS NULL),0) WHERE book_id=?",
      [book],
    );
    await database.customStatement(
      "UPDATE goals SET current_amount_in_cents=COALESCE((SELECT SUM(CASE WHEN type='withdraw' THEN -amount_in_cents ELSE amount_in_cents END) FROM goal_contributions WHERE goal_id=goals.id),0) WHERE book_id=?",
      [book],
    );
    await database.customStatement(
      "UPDATE goals SET status=CASE WHEN current_amount_in_cents>=target_amount_in_cents THEN 'completed' ELSE 'active' END WHERE book_id=? AND status IN ('active','completed')",
      [book],
    );
  }

  Future<void> resolve(String book, {required bool useServer}) async {
    final state = (await states()).firstWhere(
      (s) => s['book_id'] == book && s['user_id'] == session.user?.id,
    );
    final remote = state['remote_id'] as String;
    final snapshot = await api.request('/books/$remote/snapshot');
    final queue = await pending(book);
    if (queue.isEmpty) return;
    final batch = queue
        .where((r) => r['batch_id'] == queue.first['batch_id'])
        .toList();
    if (!useServer && queue.first['status'] != 'conflict')
      throw StateError('请先处理被拒绝的数据或权限问题');
    final map = await _idMap(book, remote);
    final entities = (snapshot['entities'] as List).cast<Json>();
    await database.withoutSyncJournal(() async {
      if (useServer) {
        // Adopting a record also drops later edits of that same record. If a
        // new parent never reached the server, drop dependent drafts with it.
        final discarded = batch
            .map((r) => '${r['kind']}:${r['entity_id']}')
            .toSet();
        const refs = {
          'account_id': 'accounts',
          'destination_account_id': 'accounts',
          'category_id': 'categories',
          'subcategory_id': 'categories',
          'parent_id': 'categories',
          'goal_id': 'goals',
          'source_transaction_id': 'transactions',
          'original_transaction_id': 'transactions',
          'related_transaction_id': 'transactions',
          'credit_account_id': 'accounts',
          'repayment_account_id': 'accounts',
        };
        bool exists(String kind, String id) => entities.any(
          (e) => e['kind'] == kind && e['id'] == map.encode(kind, id),
        );
        var changed = true;
        while (changed) {
          changed = false;
          for (final row in queue) {
            final key = '${row['kind']}:${row['entity_id']}';
            if (discarded.contains(key)) continue;
            final data = jsonDecode(row['data_json'] as String) as Json;
            if (refs.entries.any(
              (ref) =>
                  data[ref.key] != null &&
                  discarded.contains('${ref.value}:${data[ref.key]}') &&
                  !exists(ref.value, data[ref.key] as String),
            )) {
              discarded.add(key);
              changed = true;
            }
          }
        }
        for (final row in queue) {
          if (discarded.contains('${row['kind']}:${row['entity_id']}'))
            await database.customStatement(
              'DELETE FROM sync_outbox WHERE seq=?',
              [row['seq']],
            );
        }
      } else {
        int version(String kind, String? id) => id == null
            ? 0
            : (entities
                          .where(
                            (e) =>
                                e['kind'] == kind &&
                                e['id'] == map.encode(kind, id),
                          )
                          .firstOrNull?['version']
                      as int? ??
                  0);
        for (final row in batch) {
          final kind = row['kind'] as String,
              data = jsonDecode(row['data_json'] as String) as Json;
          await database.customStatement(
            "UPDATE sync_outbox SET operation_id=?,expected_version=?,expected_account_version=?,expected_goal_version=?,status='pending',error=NULL WHERE seq=?",
            [
              newEntityId(),
              kind == 'books'
                  ? (snapshot['book'] as Json)['version']
                  : version(kind, row['entity_id'] as String),
              version('accounts', data['account_id'] as String?),
              version('goals', data['goal_id'] as String?),
              row['seq'],
            ],
          );
        }
      }
      await _applySnapshot(book, remote, snapshot);
    });
    await sync();
    if (!_disposed) _changes.add(null);
  }

  Future<List<Json>> unavailableDrafts() async {
    final user = session.user;
    if (user == null) return [];
    final results = <Json>[];
    for (final state in (await states()).where(
      (s) => s['user_id'] == user.id,
    )) {
      final book = await database.familyDao.findBook(
        state['book_id'] as String,
      );
      final queue = await pending(state['book_id'] as String);
      if (queue.isNotEmpty &&
          (state['access'] == 0 || book?.isArchived == true))
        results.add({...state, 'name': book?.name ?? '共享账本', 'pending': queue});
    }
    return results;
  }

  Future<void> discardUnavailableDrafts(String book) async {
    final state = (await unavailableDrafts())
        .where((s) => s['book_id'] == book)
        .firstOrNull;
    if (state == null || state['phase'] == 'promoting')
      throw StateError('请先确认该账本的共享状态');
    await database.transaction(() async {
      await database.customStatement(
        'DELETE FROM sync_outbox WHERE book_id=?',
        [book],
      );
      await database.customStatement(
        'UPDATE sync_books SET cursor=0 WHERE book_id=?',
        [book],
      );
    });
    if (!_disposed) _changes.add(null);
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _debounce?.cancel();
    await _databaseChanges?.cancel();
    await _sessionChanges?.cancel();
    await _changes.close();
  }
}

final sharedBookSyncProvider = Provider<SharedBookSyncService>((ref) {
  final service = SharedBookSyncService(
    ref.watch(databaseProvider),
    ref.watch(sessionRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
final activeSharedStateProvider = StreamProvider<Json?>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  final service = ref.watch(sharedBookSyncProvider),
      book = ref.watch(activeBookIdProvider);
  Future<Json?> current() async {
    final state = (await service.states())
        .where((s) => s['book_id'] == book)
        .firstOrNull;
    if (state == null) return null;
    return {
      ...state,
      'pending': await service.pending(book),
      'error': service.lastError ?? state['last_error'],
    };
  }

  yield await current();
  await for (final _ in service.changes) {
    yield await current();
  }
});

final unavailableSharedDraftsProvider = StreamProvider<List<Json>>((
  ref,
) async* {
  ref.watch(sessionProvider);
  final service = ref.watch(sharedBookSyncProvider);
  yield await service.unavailableDrafts();
  await for (final _ in service.changes) {
    yield await service.unavailableDrafts();
  }
});
