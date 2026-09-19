import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';

test('authenticated support ticket supports admin reply and user follow-up', async t => {
  const previous = process.env.ADMIN_TOKEN;
  process.env.ADMIN_TOKEN = 'test-admin-token-that-is-long-enough';
  t.after(() => {
    if (previous == null) delete process.env.ADMIN_TOKEN;
    else process.env.ADMIN_TOKEN = previous;
  });

  const { app, store } = await createApp(':memory:');
  t.after(() => app.close());

  const registered = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      username: 'support_user',
      password: 'support-password-123',
      deviceName: 'Test device',
    },
  });
  assert.equal(registered.statusCode, 201);
  const account = registered.json() as any;
  const auth = { authorization: `Bearer ${account.token}` };

  const push = await app.inject({
    method: 'POST',
    url: '/api/v1/push/devices',
    headers: auth,
    payload: {
      deviceId: 'dddddddddddddddddddddddddddddddd',
      platform: 'android',
      provider: 'fcm',
      token: 'provider-token-support-user',
    },
  });
  assert.equal(push.statusCode, 200);

  const created = await app.inject({
    method: 'POST',
    url: '/api/v1/support/tickets',
    headers: auth,
    payload: {
      installationId: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      subject: '同步异常',
      message: '家庭账本同步后少了一条记录。',
    },
  });
  assert.equal(created.statusCode, 201);
  const id = created.json().id as string;

  const adminReply = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/support-tickets/${id}/messages`,
    headers: { 'x-admin-token': process.env.ADMIN_TOKEN },
    payload: { body: '已经收到，请先不要重复创建账本。' },
  });
  assert.equal(adminReply.statusCode, 201);
  assert.equal(adminReply.json().queued, 1);

  const queued = store.db
    .prepare("SELECT COUNT(*) AS n FROM push_outbox WHERE user_id=? AND status='pending'")
    .get(account.user.id) as { n: number };
  assert.equal(queued.n, 1);

  const detail = await app.inject({
    method: 'GET',
    url: `/api/v1/support/tickets/${id}`,
    headers: auth,
  });
  assert.equal(detail.statusCode, 200);
  assert.equal(detail.json().messages.length, 2);
  assert.equal(detail.json().messages[1].authorType, 'admin');

  const userReply = await app.inject({
    method: 'POST',
    url: `/api/v1/support/tickets/${id}/messages`,
    headers: auth,
    payload: { body: '收到，我先保留现场。' },
  });
  assert.equal(userReply.statusCode, 201);

  const list = await app.inject({
    method: 'GET',
    url: '/api/v1/support/tickets',
    headers: auth,
  });
  assert.equal(list.statusCode, 200);
  assert.equal(list.json().tickets[0].messageCount, 3);
  assert.equal(list.json().tickets[0].status, 'open');
});
