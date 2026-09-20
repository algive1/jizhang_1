import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';
import type { AssistantModelProvider } from '../src/assistant_ai.js';

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


class FakeInsightModel implements AssistantModelProvider {
  calls = 0;
  async complete() {
    this.calls++;
    return '这条洞察来自你自己的历史变化。当前证据支持这个趋势，但不代表每一笔消费都有问题。可以先查看相关流水，再决定是否调整。';
  }
}

function tx(
  id: string,
  occurredAt: number,
  amount = 35,
  extra: Record<string, unknown> = {},
) {
  return {
    id,
    type: 'expense',
    amount,
    currency: 'CNY',
    categoryId: 'food',
    categoryName: '餐饮',
    merchant: null,
    note: null,
    occurredAt,
    source: 'manual',
    aiConfidence: 0.95,
    userCorrected: true,
    duplicateConfidence: 0,
    reimbursementStatus: 'none',
    reimbursementAmount: null,
    refundAmount: null,
    isRecurring: false,
    ...extra,
  };
}

test('server insight analysis respects local timezone and excludes ambiguous transfer support', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  await app.inject({
    method: 'PUT',
    url: '/api/v1/insights/profile',
    headers: auth,
    payload: {
      intents: ['controlSpending', 'recordLife'],
      focus: ['dining', 'family'],
      tone: 'balanced',
      configured: true,
    },
  });

  const generatedAt = Date.parse('2026-09-20T15:00:00+08:00');
  const transactions = [];
  for (let month = 6; month <= 9; month++) {
    for (let index = 0; index < 14; index++) {
      transactions.push(
        tx(
          `m${month}-${index}`,
          Date.parse(
            `2026-${String(month).padStart(2, '0')}-${String(
              2 + (index % 10),
            ).padStart(2, '0')}T12:00:00+08:00`,
          ),
          month === 9 ? 52 : 32,
        ),
      );
    }
  }
  transactions.push(
    {
      ...tx('transfer-mom-1', Date.parse('2026-09-10T12:00:00+08:00'), 800),
      type: 'transfer',
      categoryId: null,
      categoryName: null,
      note: '给妈妈',
    },
    {
      ...tx('transfer-mom-2', Date.parse('2026-09-12T12:00:00+08:00'), 600),
      type: 'transfer',
      categoryId: null,
      categoryName: null,
      note: '给爸爸',
    },
  );

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt,
      timezoneOffsetMinutes: 480,
      transactions,
      accounts: [],
      budgets: [],
      goals: [],
      recurringBills: [],
    },
  });
  assert.equal(response.statusCode, 200);
  const result = response.json();
  assert.equal(result.origin, 'serverConfirmed');
  assert.equal(result.homeMinScore, 70);
  assert.equal(result.historyDays, 90);
  assert.equal(
    result.items.some((item: { id: string }) =>
      item.id === 'server:life:family-support'),
    false,
  );
  assert.equal(
    result.items.some((item: { id: string }) =>
      item.id.includes('category:food:increase')),
    true,
  );
});

test('member AI interpretation is cached and grounded behind server policy', async t => {
  const previous = process.env.ADMIN_TOKEN;
  process.env.ADMIN_TOKEN = 'insight-admin-token-with-at-least-32-chars';
  t.after(() => {
    if (previous == null) delete process.env.ADMIN_TOKEN;
    else process.env.ADMIN_TOKEN = previous;
  });
  const model = new FakeInsightModel();
  const { app, store } = await createApp(':memory:', model);
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  const me = await app.inject({
    method: 'GET',
    url: '/api/v1/auth/me',
    headers: auth,
  });
  const userId = me.json().user.id as string;
  store.db.prepare(
    'INSERT INTO assistant_memberships(user_id,expires_at) VALUES(?,?)',
  ).run(userId, store.now() + 86400);

  const current = await app.inject({
    method: 'GET',
    url: '/api/v1/admin/insights/policy',
    headers: { 'x-admin-token': process.env.ADMIN_TOKEN },
  });
  const policy = current.json();
  await app.inject({
    method: 'PUT',
    url: '/api/v1/admin/insights/policy',
    headers: {
      'x-admin-token': process.env.ADMIN_TOKEN,
      'content-type': 'application/json',
    },
    payload: { ...policy, aiEnabled: true },
  });

  const payload = {
    insightId: 'server:category:food:increase',
    kind: 'behavior',
    title: '餐饮支出明显增加',
    summary: '本期比上一可比周期多 ¥210。',
    analysis: '增长主要由消费次数增加带来。',
    meaning: '这是相对你自己的历史变化。',
    suggestion: '可以先看看增加发生在哪几天。',
    evidence: [
      { label: '餐饮', value: 560, baselineValue: 350, unit: 'CNY' },
    ],
  };
  for (let index = 0; index < 2; index++) {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/insights/interpret',
      headers: auth,
      payload,
    });
    assert.equal(response.statusCode, 200);
    assert.match(response.json().message, /历史变化/);
  }
  assert.equal(model.calls, 1);
});
