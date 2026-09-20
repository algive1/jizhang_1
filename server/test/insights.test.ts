import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';

async function register(app: Awaited<ReturnType<typeof createApp>>['app']) {
  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/register',
    payload: {
      username: 'insight_user',
      password: 'local-test-password',
    },
  });
  assert.equal(response.statusCode, 201);
  return (response.json() as { token: string }).token;
}

test('insight profile and feedback are authenticated and persisted', async t => {
  const { app, store } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = { authorization: `Bearer ${token}` };

  const initial = await app.inject({
    method: 'GET',
    url: '/api/v1/insights/profile',
    headers: auth,
  });
  assert.equal(initial.statusCode, 200);
  assert.equal(initial.json().configured, false);

  const saved = await app.inject({
    method: 'PUT',
    url: '/api/v1/insights/profile',
    headers: { ...auth, 'content-type': 'application/json' },
    payload: {
      intents: ['controlSpending', 'saveForGoal'],
      focus: ['dining', 'credit'],
      tone: 'balanced',
      configured: true,
    },
  });
  assert.equal(saved.statusCode, 200);

  const feedback = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/life%3Afamily-support/feedback',
    headers: { ...auth, 'content-type': 'application/json' },
    payload: {
      action: 'helpful',
      kind: 'life',
      metadata: { source: 'detail' },
    },
  });
  assert.equal(feedback.statusCode, 201);

  const summary = await app.inject({
    method: 'GET',
    url: '/api/v1/insights/feedback/summary',
    headers: auth,
  });
  assert.equal(summary.statusCode, 200);
  assert.deepEqual(summary.json().feedback, [{ action: 'helpful', count: 1 }]);

  const row = store.db.prepare(
    'SELECT tone,configured FROM insight_profiles',
  ).get() as { tone: string; configured: number };
  assert.equal(row.tone, 'balanced');
  assert.equal(row.configured, 1);
});

test('insight policy is configurable from the admin API', async t => {
  const previous = process.env.ADMIN_TOKEN;
  process.env.ADMIN_TOKEN = 'insight-admin-token-with-at-least-32-chars';
  t.after(() => {
    if (previous == null) delete process.env.ADMIN_TOKEN;
    else process.env.ADMIN_TOKEN = previous;
  });
  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const denied = await app.inject({
    method: 'GET',
    url: '/api/v1/admin/insights/policy',
  });
  assert.equal(denied.statusCode, 401);

  const updated = await app.inject({
    method: 'PUT',
    url: '/api/v1/admin/insights/policy',
    headers: {
      'x-admin-token': process.env.ADMIN_TOKEN,
      'content-type': 'application/json',
    },
    payload: {
      homeMinScore: 76,
      minConfidence: 0.62,
      cooldownDays: 9,
      aiEnabled: true,
      freeHistoryDays: 120,
      proHistoryDays: 900,
      promptVersion: 'financial-insight-v2',
    },
  });
  assert.equal(updated.statusCode, 200);
  assert.equal(updated.json().homeMinScore, 76);
  assert.equal(updated.json().minConfidence, 0.62);
});
