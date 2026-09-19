import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';
import { runRetention } from '../src/maintenance.js';

test('sync retention prunes old tombstones and forces stale cursors to snapshot reset', async t => {
  const previous = process.env.SYNC_TOMBSTONE_RETENTION_DAYS;
  process.env.SYNC_TOMBSTONE_RETENTION_DAYS = '1';
  t.after(() => {
    if (previous == null) delete process.env.SYNC_TOMBSTONE_RETENTION_DAYS;
    else process.env.SYNC_TOMBSTONE_RETENTION_DAYS = previous;
  });

  const { app, store } = await createApp(':memory:');
  t.after(() => app.close());

  const registered = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      username: 'retention_user',
      password: 'retention-password-123',
    },
  });
  assert.equal(registered.statusCode, 201);
  const account = registered.json() as any;
  const auth = { authorization: `Bearer ${account.token}` };

  const now = store.now();
  const old = now - 3 * 86400;
  const bookId = 'retention-book';
  store.db.prepare(
    'INSERT INTO books(id,name,type,owner_user_id,created_at,updated_at,is_archived,version,asset_source_book_id) '
      + 'VALUES(?,?,?,?,?,?,0,1,NULL)',
  ).run(bookId, 'Retention', 'family', account.user.id, old, now);
  store.db.prepare('INSERT INTO members VALUES(?,?,?,?)')
    .run(bookId, account.user.id, 'owner', old);

  for (const [id, seq] of [['old-a', 1], ['old-b', 2]] as const) {
    store.db.prepare(
      'INSERT INTO entities(book_id,kind,id,version,data_json,deleted) VALUES(?,?,?,?,?,1)',
    ).run(bookId, 'budgets', id, 1, JSON.stringify({ id, book_id: bookId }));
    store.db.prepare(
      'INSERT INTO changes(seq,book_id,kind,entity_id,version,deleted,data_json,actor_id,created_at) '
        + 'VALUES(?,?,?,?,1,1,?,?,?)',
    ).run(seq, bookId, 'budgets', id, JSON.stringify({ id, book_id: bookId }), account.user.id, old);
  }
  store.db.prepare(
    'INSERT INTO changes(seq,book_id,kind,entity_id,version,deleted,data_json,actor_id,created_at) '
      + 'VALUES(3,?,?,?,1,0,?,?,?)',
  ).run(
    bookId,
    'budgets',
    'current',
    JSON.stringify({ id: 'current', book_id: bookId }),
    account.user.id,
    now,
  );

  const result = runRetention(store);
  assert.equal(result.syncRetention.books, 1);
  assert.equal(result.syncRetention.changes, 2);
  assert.equal(result.syncRetention.tombstones, 2);

  const floor = store.db.prepare(
    'SELECT reset_before_cursor AS floor FROM sync_retention WHERE book_id=?',
  ).get(bookId) as { floor: number };
  assert.equal(floor.floor, 2);

  const stale = await app.inject({
    method: 'GET',
    url: `/api/v1/books/${bookId}/changes?cursor=1`,
    headers: auth,
  });
  assert.equal(stale.statusCode, 200);
  assert.equal(stale.json().resetRequired, true);
  assert.equal(stale.json().cursor, 3);

  const current = await app.inject({
    method: 'GET',
    url: `/api/v1/books/${bookId}/changes?cursor=2`,
    headers: auth,
  });
  assert.equal(current.statusCode, 200);
  assert.equal(current.json().resetRequired, false);
  assert.equal(current.json().changes.length, 1);
});
