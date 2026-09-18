import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';

test('push device registration is session-bound and token is never listed', async t => {
  const { app, store } = await createApp(':memory:');
  t.after(() => app.close());

  const registered = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      username: 'push_user',
      password: 'push-password-123',
      displayName: 'Push User',
      deviceName: 'Test phone',
    },
  });
  assert.equal(registered.statusCode, 201);
  const account = registered.json() as any;
  const auth = { authorization: `Bearer ${account.token}` };

  const deviceId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const deviceToken = 'provider-token-1234567890';
  const push = await app.inject({
    method: 'POST',
    url: '/api/v1/push/devices',
    headers: auth,
    payload: {
      deviceId,
      platform: 'android',
      provider: 'fcm',
      token: deviceToken,
    },
  });
  assert.equal(push.statusCode, 200);
  assert.deepEqual(push.json(), {
    registered: true,
    deviceId,
    platform: 'android',
    provider: 'fcm',
  });

  const list = await app.inject({
    method: 'GET',
    url: '/api/v1/push/devices',
    headers: auth,
  });
  assert.equal(list.statusCode, 200);
  const listed = list.json() as any;
  assert.equal(listed.devices.length, 1);
  assert.equal(listed.devices[0].deviceId, deviceId);
  assert.equal(listed.devices[0].currentSession, true);
  assert.equal('token' in listed.devices[0], false);

  const stored = store.db
    .prepare(
      'SELECT user_id,device_id,session_id,provider,token FROM push_devices',
    )
    .get() as any;
  assert.equal(stored.device_id, deviceId);
  assert.equal(stored.provider, 'fcm');
  assert.equal(stored.token, deviceToken);
  assert.ok(stored.session_id);

  const logout = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/logout',
    headers: auth,
  });
  assert.equal(logout.statusCode, 200);

  const remaining = store.db
    .prepare('SELECT COUNT(*) AS n FROM push_devices')
    .get() as { n: number };
  assert.equal(remaining.n, 0);
});

test('push device registration requires login and validates provider data', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const unauthorized = await app.inject({
    method: 'POST',
    url: '/api/v1/push/devices',
    payload: {
      deviceId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      platform: 'android',
      provider: 'fcm',
      token: 'provider-token-1234567890',
    },
  });
  assert.equal(unauthorized.statusCode, 401);
});

test('server schema includes push device registry at version 9', async t => {
  const { app, store } = await createApp(':memory:');
  t.after(() => app.close());

  assert.equal(store.db.pragma('user_version', { simple: true }), 9);
  const table = store.db
    .prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='push_devices'",
    )
    .get();
  assert.ok(table);
});
