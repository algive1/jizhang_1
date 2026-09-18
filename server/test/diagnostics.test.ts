import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createApp } from '../src/app.js';

test('诊断事件需要登录、支持批量并按用户幂等', async t => {
  const { app, store } = await createApp(':memory:');
  const base = await app.listen({ host: '127.0.0.1', port: 0 });
  t.after(() => app.close());
  const request = async (path: string, token = '', body?: unknown) => {
    const response = await fetch(`${base}/api/v1${path}`, {
      method: body === undefined ? 'GET' : 'POST',
      headers: {
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, data: await response.json() as Record<string, unknown> };
  };

  assert.equal((await request('/diagnostics/events', '', { events: [{ event_id: 'unauthorized', occurred_at: 1, level: 'info', kind: 'test' }] })).status, 401);
  const registered = await request('/auth/register', '', { username: 'diagnostic_test', password: 'local-test-password' });
  const token = registered.data.token as string;
  const body = {
    events: [
      { event_id: 'startup-1', occurred_at: 100, level: 'info', kind: 'app_started', screen: '/', data: { durationMs: 12 } },
      { event_id: 'bookkeeping-1', occurred_at: 101, level: 'warn', kind: 'bookkeeping_queued', message: '待确认', data: { count: 1 } },
    ],
  };
  assert.deepEqual(await request('/diagnostics/events', token, body), {
    status: 200,
    data: { accepted: 2, duplicates: 0 },
  });
  assert.deepEqual(await request('/diagnostics/events', token, body), {
    status: 200,
    data: { accepted: 0, duplicates: 2 },
  });
  assert.equal((store.db.prepare('SELECT COUNT(*) AS count FROM diagnostic_events').get() as { count: number }).count, 2);
  assert.equal((await request('/diagnostics/events', token, { events: [{ event_id: 'raw', occurred_at: 1, level: 'info', kind: 'test', data: { notificationText: 'secret' } }] })).status, 400);
});
