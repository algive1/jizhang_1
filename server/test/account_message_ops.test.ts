import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';

async function register(app: Awaited<ReturnType<typeof createApp>>['app'], username: string) {
  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      username,
      password: 'account-password-123',
      displayName: 'Test User',
      deviceName: 'Test device',
    },
  });
  assert.equal(response.statusCode, 201);
  return response.json() as { token: string; user: { id: string } };
}

test('message center supports admin announcement, unread state and read receipt', async t => {
  const previous = process.env.ADMIN_TOKEN;
  process.env.ADMIN_TOKEN = 'test-admin-token-that-is-long-enough';
  t.after(() => {
    if (previous == null) delete process.env.ADMIN_TOKEN;
    else process.env.ADMIN_TOKEN = previous;
  });

  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const account = await register(app, 'message_user');
  const auth = { authorization: `Bearer ${account.token}` };

  const publish = await app.inject({
    method: 'POST',
    url: '/api/v1/admin/announcements',
    headers: { 'x-admin-token': process.env.ADMIN_TOKEN },
    payload: {
      title: '版本公告',
      body: '新版本已经发布。',
      route: '/profile/data',
    },
  });
  assert.equal(publish.statusCode, 200);
  const id = publish.json().announcement.id as string;

  const messages = await app.inject({
    method: 'GET',
    url: '/api/v1/messages',
    headers: auth,
  });
  assert.equal(messages.statusCode, 200);
  assert.equal(messages.json().unread, 1);
  assert.equal(messages.json().messages[0].isRead, 0);

  const read = await app.inject({
    method: 'POST',
    url: `/api/v1/messages/${id}/read`,
    headers: auth,
  });
  assert.equal(read.statusCode, 200);

  const after = await app.inject({
    method: 'GET',
    url: '/api/v1/messages',
    headers: auth,
  });
  assert.equal(after.json().unread, 0);
  assert.equal(after.json().messages[0].isRead, 1);
});

test('support accepts guest ticket and admin can update its status', async t => {
  const previous = process.env.ADMIN_TOKEN;
  process.env.ADMIN_TOKEN = 'test-admin-token-that-is-long-enough';
  t.after(() => {
    if (previous == null) delete process.env.ADMIN_TOKEN;
    else process.env.ADMIN_TOKEN = previous;
  });

  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const created = await app.inject({
    method: 'POST',
    url: '/api/v1/support/tickets',
    payload: {
      installationId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      subject: '无法导出',
      message: '点击导出后没有生成文件，请协助检查。',
      appVersion: '1.0.0',
    },
  });
  assert.equal(created.statusCode, 201);
  const id = created.json().id as string;

  const list = await app.inject({
    method: 'GET',
    url: '/api/v1/admin/support-tickets',
    headers: { 'x-admin-token': process.env.ADMIN_TOKEN },
  });
  assert.equal(list.statusCode, 200);
  assert.equal(list.json().tickets[0].id, id);

  const update = await app.inject({
    method: 'PATCH',
    url: `/api/v1/admin/support-tickets/${id}`,
    headers: { 'x-admin-token': process.env.ADMIN_TOKEN },
    payload: { status: 'resolved' },
  });
  assert.equal(update.statusCode, 200);
});

test('account deletion removes private server data and anonymizes shared audit identity', async t => {
  const { app, store } = await createApp(':memory:');
  t.after(() => app.close());
  const account = await register(app, 'delete_me');
  const auth = { authorization: `Bearer ${account.token}` };

  const device = await app.inject({
    method: 'POST',
    url: '/api/v1/push/devices',
    headers: auth,
    payload: {
      deviceId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      platform: 'android',
      provider: 'fcm',
      token: 'provider-token-1234567890',
    },
  });
  assert.equal(device.statusCode, 200);

  const ticket = await app.inject({
    method: 'POST',
    url: '/api/v1/support/tickets',
    headers: auth,
    payload: {
      installationId: 'cccccccccccccccccccccccccccccccc',
      subject: '删除前工单',
      message: '这条工单应该随账号私有数据一起删除。',
    },
  });
  assert.equal(ticket.statusCode, 201);

  const deleted = await app.inject({
    method: 'DELETE',
    url: '/api/v1/account',
    headers: auth,
    payload: {
      password: 'account-password-123',
      confirmation: 'DELETE',
    },
  });
  assert.equal(deleted.statusCode, 200);
  assert.equal(deleted.json().deleted, true);

  const user = store.db.prepare(
    'SELECT username,display_name,recovery_key_hash FROM users WHERE id=?',
  ).get(account.user.id) as {
    username: string;
    display_name: string | null;
    recovery_key_hash: string | null;
  };
  assert.match(user.username, /^deleted_[a-f0-9]{30}$/);
  assert.equal(user.display_name, null);
  assert.equal(user.recovery_key_hash, null);
  assert.equal(
    (store.db.prepare('SELECT COUNT(*) AS n FROM sessions WHERE user_id=?').get(account.user.id) as { n: number }).n,
    0,
  );
  assert.equal(
    (store.db.prepare('SELECT COUNT(*) AS n FROM push_devices WHERE user_id=?').get(account.user.id) as { n: number }).n,
    0,
  );
  assert.equal(
    (store.db.prepare('SELECT COUNT(*) AS n FROM support_tickets WHERE user_id=?').get(account.user.id) as { n: number }).n,
    0,
  );

  const oldLogin = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: {
      username: 'delete_me',
      password: 'account-password-123',
    },
  });
  assert.equal(oldLogin.statusCode, 401);

  const reuse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      username: 'delete_me',
      password: 'new-account-password-123',
    },
  });
  assert.equal(reuse.statusCode, 201);
});
