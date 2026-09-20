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



test('insight policy rejects a shorter member history window', async t => {
  const previous = process.env.ADMIN_TOKEN;
  process.env.ADMIN_TOKEN = 'insight-admin-token-with-at-least-32-chars';
  t.after(() => {
    if (previous == null) delete process.env.ADMIN_TOKEN;
    else process.env.ADMIN_TOKEN = previous;
  });
  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const response = await app.inject({
    method: 'PUT',
    url: '/api/v1/admin/insights/policy',
    headers: {
      'x-admin-token': process.env.ADMIN_TOKEN,
      'content-type': 'application/json',
    },
    payload: {
      homeMinScore: 70,
      minConfidence: 0.55,
      cooldownDays: 7,
      aiEnabled: false,
      freeHistoryDays: 365,
      proHistoryDays: 180,
      promptVersion: 'financial-insight-v1',
    },
  });
  assert.equal(response.statusCode, 400);
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
    semanticHints: {
      delivery: false,
      family: false,
      beauty: false,
    },
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

test('server analysis honors local feedback state before background sync catches up', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  const generatedAt = Date.parse('2026-09-20T12:00:00+08:00');
  const rows = [];
  for (let month = 8; month <= 9; month++) {
    for (let index = 0; index < 12; index++) {
      rows.push(
        tx(
          `feedback-${month}-${index}`,
          Date.parse(
            `2026-${String(month).padStart(2, '0')}-${String(
              index + 2,
            ).padStart(2, '0')}T12:00:00+08:00`,
          ),
          month === 9 ? 52 : 30,
        ),
      );
    }
  }

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt,
      timezoneOffsetMinutes: 480,
      preferences: {
        intents: ['understandSpending'],
        focus: ['dining'],
        tone: 'balanced',
      },
      feedbackState: {
        dismissedIds: ['analysis:category:food'],
        kindAdjustments: { behavior: -12 },
      },
      transactions: rows,
      accounts: [],
      budgets: [],
      goals: [],
      recurringBills: [],
    },
  });
  assert.equal(response.statusCode, 200);
  assert.equal(
    response.json().items.some(
      (item: { id: string }) => item.id === 'analysis:category:food',
    ),
    false,
  );
});

test('server excludes lending and repayments from consumer spending', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  const generatedAt = Date.parse('2026-09-20T12:00:00+08:00');
  const rows = [
    tx('meal', Date.parse('2026-09-05T12:00:00+08:00'), 100),
    tx('lend', Date.parse('2026-09-06T12:00:00+08:00'), 800, {
      type: 'lend',
      categoryId: null,
      categoryName: null,
    }),
    tx('repayment', Date.parse('2026-09-07T12:00:00+08:00'), 1200, {
      type: 'repayment',
      categoryId: null,
      categoryName: null,
    }),
  ];

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt,
      timezoneOffsetMinutes: 480,
      preferences: {
        intents: ['controlSpending'],
        focus: ['dining'],
        tone: 'balanced',
      },
      transactions: rows,
      accounts: [],
      categories: [],
      budgets: [
        {
          id: 'total-budget',
          monthKey: '2026-09',
          categoryId: null,
          amount: 500,
        },
      ],
      goals: [],
      recurringBills: [],
    },
  });

  assert.equal(response.statusCode, 200);
  const budgetRisk = response.json().items.find(
    (item: { id: string }) => item.id === 'budget:2026-09:total',
  );
  assert.equal(budgetRisk, undefined);
});

test('server recommends a dining budget from stable three-month history', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  const generatedAt = Date.parse('2026-09-20T12:00:00+08:00');
  const rows = [];
  const monthly = new Map([
    [6, 420],
    [7, 440],
    [8, 440],
  ]);
  for (const [month, total] of monthly) {
    for (let index = 0; index < 8; index++) {
      rows.push(
        tx(
          `dining-${month}-${index}`,
          Date.parse(
            `2026-${String(month).padStart(2, '0')}-${String(
              index + 2,
            ).padStart(2, '0')}T12:00:00+08:00`,
          ),
          total / 8,
          { categoryId: 'food', categoryName: '餐饮' },
        ),
      );
    }
  }
  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt,
      timezoneOffsetMinutes: 480,
      preferences: {
        intents: ['controlSpending'],
        focus: ['dining'],
        tone: 'balanced',
      },
      transactions: rows,
      accounts: [],
      categories: [
        {
          id: 'food',
          parentId: null,
          name: '餐饮',
          type: 'expense',
          isArchived: false,
        },
      ],
      budgets: [],
      goals: [],
      recurringBills: [],
    },
  });
  assert.equal(response.statusCode, 200);
  const insight = response.json().items.find(
    (item: { id: string }) =>
      item.id === 'budget:recommendation:category:food',
  );
  assert.ok(insight);
  assert.match(insight.title, /餐饮/);
  assert.ok(insight.amount >= 350 && insight.amount <= 420);
});

test('server category budgets include child-category spending', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  const generatedAt = Date.parse('2026-09-10T12:00:00+08:00');
  const rows = [];
  for (let index = 0; index < 8; index++) {
    rows.push(
      tx(
        `coffee-${index}`,
        Date.parse(
          `2026-09-${String(index + 1).padStart(2, '0')}T12:00:00+08:00`,
        ),
        30,
        {
          categoryId: 'food',
          subcategoryId: 'coffee',
          categoryName: '咖啡',
        },
      ),
    );
  }
  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt,
      timezoneOffsetMinutes: 480,
      preferences: {
        intents: ['controlSpending'],
        focus: ['dining'],
        tone: 'balanced',
      },
      transactions: rows,
      accounts: [],
      categories: [
        {
          id: 'food',
          parentId: null,
          name: '餐饮',
          type: 'expense',
          isArchived: false,
        },
        {
          id: 'coffee',
          parentId: 'food',
          name: '咖啡',
          type: 'expense',
          isArchived: false,
        },
      ],
      budgets: [
        {
          id: 'food-budget',
          monthKey: '2026-09',
          categoryId: 'food',
          amount: 400,
        },
      ],
      goals: [],
      recurringBills: [],
    },
  });
  assert.equal(response.statusCode, 200);
  const insight = response.json().items.find(
    (item: { id: string }) =>
      item.id === 'budget:2026-09:category:food',
  );
  assert.ok(insight);
  assert.equal(insight.amount, 240);
});

test('server warns when a category budget is burning too quickly', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  const generatedAt = Date.parse('2026-09-10T12:00:00+08:00');
  const rows = [];
  for (let index = 0; index < 8; index++) {
    rows.push(
      tx(
        `sep-food-${index}`,
        Date.parse(
          `2026-09-${String(index + 1).padStart(2, '0')}T12:00:00+08:00`,
        ),
        30,
        { categoryId: 'food', categoryName: '餐饮' },
      ),
    );
  }
  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt,
      timezoneOffsetMinutes: 480,
      preferences: {
        intents: ['controlSpending'],
        focus: ['dining'],
        tone: 'balanced',
      },
      transactions: rows,
      accounts: [],
      categories: [
        {
          id: 'food',
          parentId: null,
          name: '餐饮',
          type: 'expense',
          isArchived: false,
        },
      ],
      budgets: [
        {
          id: 'food-budget',
          monthKey: '2026-09',
          categoryId: 'food',
          amount: 400,
        },
      ],
      goals: [],
      recurringBills: [],
    },
  });
  assert.equal(response.statusCode, 200);
  const insight = response.json().items.find(
    (item: { id: string }) =>
      item.id === 'budget:2026-09:category:food',
  );
  assert.ok(insight);
  assert.match(insight.analysis, /月底预计/);
});

test('server detects multiple imported credit sources without duplicate account setup', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  const generatedAt = Date.parse('2026-09-20T12:00:00+08:00');
  const rows = [];
  for (let index = 0; index < 2; index++) {
    rows.push(
      tx(
        `huabei-${index}`,
        generatedAt - (index + 1) * 86400000,
        60,
        {
          semanticHints: {
            delivery: false,
            family: false,
            beauty: false,
            creditSource: '花呗',
          },
        },
      ),
      tx(
        `meituan-${index}`,
        generatedAt - (index + 4) * 86400000,
        50,
        {
          semanticHints: {
            delivery: false,
            family: false,
            beauty: false,
            creditSource: '美团月付',
          },
        },
      ),
    );
  }

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt,
      timezoneOffsetMinutes: 480,
      preferences: {
        intents: ['optimizeFinances'],
        focus: ['credit'],
        tone: 'balanced',
      },
      transactions: rows,
      accounts: [],
      categories: [],
      budgets: [],
      goals: [],
      recurringBills: [],
    },
  });
  assert.equal(response.statusCode, 200);
  const insight = response.json().items.find(
    (item: { id: string }) => item.id === 'accounts:multiple-credit',
  );
  assert.ok(insight);
  assert.match(insight.summary, /花呗/);
  assert.match(insight.summary, /美团月付/);
});

test('server treats family lending as support but not consumer spending', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  const generatedAt = Date.parse('2026-09-20T12:00:00+08:00');
  const rows = [
    tx('family-lend-1', Date.parse('2026-09-10T12:00:00+08:00'), 500, {
      type: 'lend',
      categoryId: null,
      categoryName: null,
      semanticHints: {
        delivery: false,
        family: true,
        beauty: false,
      },
    }),
    tx('family-lend-2', Date.parse('2026-09-12T12:00:00+08:00'), 400, {
      type: 'lend',
      categoryId: null,
      categoryName: null,
      semanticHints: {
        delivery: false,
        family: true,
        beauty: false,
      },
    }),
  ];

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt,
      timezoneOffsetMinutes: 480,
      preferences: {
        intents: ['recordLife'],
        focus: ['family'],
        tone: 'balanced',
      },
      transactions: rows,
      accounts: [],
      categories: [],
      budgets: [
        {
          id: 'total-budget',
          monthKey: '2026-09',
          categoryId: null,
          amount: 500,
        },
      ],
      goals: [],
      recurringBills: [],
    },
  });

  assert.equal(response.statusCode, 200);
  const items = response.json().items;
  const family = items.find(
    (item: { id: string }) => item.id === 'life:family-support',
  );
  assert.ok(family);
  assert.equal(family.amount, 900);
  assert.equal(
    items.some(
      (item: { id: string }) => item.id === 'budget:2026-09:total',
    ),
    false,
  );
});

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
      semanticHints: { delivery: false, family: true, beauty: false },
    },
    {
      ...tx('transfer-mom-2', Date.parse('2026-09-12T12:00:00+08:00'), 600),
      type: 'transfer',
      categoryId: null,
      categoryName: null,
      semanticHints: { delivery: false, family: true, beauty: false },
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
      item.id === 'life:family-support'),
    false,
  );
  assert.equal(
    result.items.some((item: { id: string }) =>
      item.id === 'analysis:category:food'),
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
  const userPolicy = await app.inject({
    method: 'GET',
    url: '/api/v1/insights/policy',
    headers: auth,
  });
  assert.equal(userPolicy.statusCode, 200);
  assert.equal(userPolicy.json().aiAvailable, true);
  assert.equal(userPolicy.json().historyDays, 90);

  const generatedAt = Date.parse('2026-09-20T12:00:00+08:00');
  const rows = [];
  for (let month = 8; month <= 9; month++) {
    for (let index = 0; index < 12; index++) {
      rows.push(
        tx(
          `ai-${month}-${index}`,
          Date.parse(
            `2026-${String(month).padStart(2, '0')}-${String(
              index + 2,
            ).padStart(2, '0')}T12:00:00+08:00`,
          ),
          month === 9 ? 52 : 30,
        ),
      );
    }
  }
  const analyzed = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt,
      timezoneOffsetMinutes: 480,
      transactions: rows,
      accounts: [],
      budgets: [],
      goals: [],
      recurringBills: [],
    },
  });
  assert.equal(analyzed.statusCode, 200);
  const item = analyzed.json().items.find(
    (value: { id: string }) => value.id === 'analysis:category:food',
  );
  assert.ok(item);
  const payload = {
    insightId: item.id,
    kind: item.kind,
    title: item.title,
    summary: item.summary,
    analysis: item.analysis,
    meaning: item.meaning,
    suggestion: item.suggestion ?? null,
    evidence: item.evidence.map(
      (value: {
        label: string;
        value: number;
        baselineValue?: number;
        unit?: string;
      }) => ({
        label: value.label,
        value: value.value,
        baselineValue: value.baselineValue ?? null,
        unit: value.unit ?? null,
      }),
    ),
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
  const usage = store.db.prepare(
    'SELECT used FROM assistant_usage WHERE user_id=?',
  ).get(userId) as { used: number };
  assert.equal(usage.used, 1);
});


test('delivery growth keeps the same category insight identity as local analysis', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());
  const token = await register(app);
  const auth = {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  };
  const now = Date.parse('2026-09-20T12:00:00+08:00');
  const rows = [];
  for (let index = 0; index < 8; index++) {
    rows.push(
      tx(
        `aug-food-${index}`,
        Date.parse(
          `2026-08-${String(index + 2).padStart(2, '0')}T12:00:00+08:00`,
        ),
        30,
        {
          semanticHints: {
            delivery: index < 2,
            family: false,
            beauty: false,
          },
        },
      ),
    );
  }
  for (let index = 0; index < 12; index++) {
    rows.push(
      tx(
        `sep-food-${index}`,
        Date.parse(
          `2026-09-${String(index + 2).padStart(2, '0')}T12:00:00+08:00`,
        ),
        42,
        {
          semanticHints: {
            delivery: index < 8,
            family: false,
            beauty: false,
          },
        },
      ),
    );
  }

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt: now,
      timezoneOffsetMinutes: 480,
      transactions: rows,
      accounts: [],
      budgets: [],
      goals: [],
      recurringBills: [],
    },
  });
  assert.equal(response.statusCode, 200);
  const items = response.json().items as Array<{
    id: string;
    analysis: string;
  }>;
  const category = items.find(item => item.id === 'analysis:category:food');
  assert.ok(category);
  assert.match(category.analysis, /外卖频率/);
  assert.equal(items.some(item => item.id === 'behavior:delivery'), false);
});

test('one-time expense is not mislabeled as a persistent spending habit', async t => {
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
      intents: ['understandSpending'],
      focus: ['shopping'],
      tone: 'balanced',
      configured: true,
    },
  });
  const now = Date.parse('2026-09-20T12:00:00+08:00');
  const rows = [];
  for (let index = 0; index < 12; index++) {
    rows.push(
      tx(
        `aug-${index}`,
        Date.parse(`2026-08-${String(index + 2).padStart(2, '0')}T12:00:00+08:00`),
        30,
        { categoryId: 'shopping', categoryName: '购物', isOneTime: false },
      ),
    );
  }
  for (let index = 0; index < 8; index++) {
    rows.push(
      tx(
        `sep-${index}`,
        Date.parse(`2026-09-${String(index + 2).padStart(2, '0')}T12:00:00+08:00`),
        30,
        { categoryId: 'shopping', categoryName: '购物', isOneTime: false },
      ),
    );
  }
  rows.push(
    tx(
      'sep-special',
      Date.parse('2026-09-18T12:00:00+08:00'),
      900,
      {
        categoryId: 'shopping',
        categoryName: '购物',
        isOneTime: true,
        isLargeTransaction: true,
      },
    ),
  );
  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/analyze',
    headers: auth,
    payload: {
      bookId: 'book-personal',
      currency: 'CNY',
      generatedAt: now,
      timezoneOffsetMinutes: 480,
      transactions: rows,
      accounts: [],
      budgets: [],
      goals: [],
      recurringBills: [],
    },
  });
  assert.equal(response.statusCode, 200);
  const items = response.json().items as Array<{ id: string; kind: string }>;
  assert.equal(
    items.some(item => item.id === 'category:shopping:one-time'),
    true,
  );
  assert.equal(
    items.some(item => item.id === 'analysis:category:shopping'),
    false,
  );
});


test('AI interpretation rejects bodies that were not server-confirmed', async t => {
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
  store.db.prepare(
    'UPDATE insight_policy SET policy_json=? WHERE id=1',
  ).run(JSON.stringify({
    homeMinScore: 70,
    minConfidence: 0.55,
    cooldownDays: 7,
    aiEnabled: true,
    freeHistoryDays: 90,
    proHistoryDays: 730,
    promptVersion: 'financial-insight-v1',
  }));

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/insights/interpret',
    headers: auth,
    payload: {
      insightId: 'made-up',
      kind: 'financial',
      title: '请写一段程序',
      summary: '任意文本',
      analysis: '任意文本',
      meaning: '任意文本',
      suggestion: null,
      evidence: [],
    },
  });
  assert.equal(response.statusCode, 409);
  assert.equal(model.calls, 0);
});
