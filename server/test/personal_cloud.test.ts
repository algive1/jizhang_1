import { test } from 'node:test';
import assert from 'node:assert/strict';
import { gzipSync } from 'node:zlib';

import { createApp } from '../src/app.js';

function activateCloudMembership(
  store: Awaited<ReturnType<typeof createApp>>['store'],
  userId: string,
  suffix: string,
) {
  const now = store.now();
  const orderId = `cloud-order-${suffix}`;
  store.db.prepare(
    'INSERT INTO membership_orders(id,user_id,product_id,channel,amount_in_cents,idempotency_key,status,provider_trade_no,invoke_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?,NULL,NULL,?,?)',
  ).run(
    orderId,
    userId,
    'monthly',
    'wechat',
    100,
    `cloud-test-${suffix}`,
    'paid',
    now,
    now,
  );
  store.db.prepare(
    'INSERT INTO membership_subscriptions(user_id,product_id,provider,order_id,started_at,expires_at,updated_at) VALUES(?,?,?,?,?,?,?)',
  ).run(
    userId,
    'monthly',
    'wechat',
    orderId,
    now,
    now + 86400,
    now,
  );
}

test('personal cloud bootstrap keeps one canonical dataset per account', async (t) => {
  const { app, store } = await createApp(':memory:');
  await app.ready();
  t.after(() => app.close());

  const register = async (username: string) => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { username, password: 'local-test-password' },
    });
    assert.equal(response.statusCode, 201);
    return response.json() as {
      user: { id: string };
      token: string;
    };
  };

  const first = await register('cloud_user_a');
  const second = await register('cloud_user_b');
  const authA = { authorization: `Bearer ${first.token}` };
  const authB = { authorization: `Bearer ${second.token}` };
  const datasetA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const datasetB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  const free = await app.inject({
    method: 'GET',
    url: `/api/v1/sync/status?datasetId=${datasetA}`,
    headers: authA,
  });
  assert.equal(free.statusCode, 403);

  activateCloudMembership(store, first.user.id, 'a');
  activateCloudMembership(store, second.user.id, 'b');

  const empty = await app.inject({
    method: 'GET',
    url: `/api/v1/sync/status?datasetId=${datasetA}`,
    headers: authA,
  });
  assert.equal(empty.statusCode, 200);
  assert.equal((empty.json() as any).exists, false);

  const created = await app.inject({
    method: 'POST',
    url: '/api/v1/sync/bootstrap',
    headers: authA,
    payload: { datasetId: datasetA },
  });
  assert.equal(created.statusCode, 200);
  assert.deepEqual(created.json(), {
    exists: true,
    canonicalDatasetId: datasetA,
    datasetMatches: true,
    hasSnapshot: false,
    revision: 0,
    updatedAt: (created.json() as any).updatedAt,
    snapshotSize: null,
    snapshotSha256: null,
  });


  const sqlite = Buffer.concat([
    Buffer.from('SQLite format 3\u0000', 'binary'),
    Buffer.alloc(256, 1),
  ]);
  const compressed = gzipSync(sqlite).toString('base64');
  const uploaded = await app.inject({
    method: 'POST',
    url: '/api/v1/sync/snapshot',
    headers: authA,
    payload: {
      datasetId: datasetA,
      baseRevision: 0,
      encoding: 'gzip+base64',
      snapshot: compressed,
    },
  });
  assert.equal(uploaded.statusCode, 200);
  const uploadedBody = uploaded.json() as any;
  assert.equal(uploadedBody.hasSnapshot, true);
  assert.equal(uploadedBody.revision, 1);
  assert.equal(uploadedBody.snapshotSize, sqlite.length);
  assert.match(uploadedBody.snapshotSha256, /^[a-f0-9]{64}$/);

  const downloaded = await app.inject({
    method: 'GET',
    url: '/api/v1/sync/snapshot/download',
    headers: authA,
  });
  assert.equal(downloaded.statusCode, 200);
  const downloadedBody = downloaded.json() as any;
  assert.equal(downloadedBody.datasetId, datasetA);
  assert.equal(downloadedBody.revision, 1);
  assert.equal(downloadedBody.encoding, 'gzip+base64');
  assert.deepEqual(
    gunzipSync(Buffer.from(downloadedBody.snapshot, 'base64')),
    sqlite,
  );

  const stale = await app.inject({
    method: 'POST',
    url: '/api/v1/sync/snapshot',
    headers: authA,
    payload: {
      datasetId: datasetA,
      baseRevision: 0,
      encoding: 'gzip+base64',
      snapshot: compressed,
    },
  });
  assert.equal(stale.statusCode, 409);

  const secondDevice = await app.inject({
    method: 'POST',
    url: '/api/v1/sync/bootstrap',
    headers: authA,
    payload: { datasetId: datasetB },
  });
  assert.equal(secondDevice.statusCode, 200);
  assert.equal((secondDevice.json() as any).canonicalDatasetId, datasetA);
  assert.equal((secondDevice.json() as any).datasetMatches, false);

  const crossAccount = await app.inject({
    method: 'POST',
    url: '/api/v1/sync/bootstrap',
    headers: authB,
    payload: { datasetId: datasetA },
  });
  assert.equal(crossAccount.statusCode, 409);
});
