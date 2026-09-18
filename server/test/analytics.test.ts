import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';

test('anonymous analytics accepts safe events without login and deduplicates', async t => {
  const { app, store } = await createApp(':memory:');
  t.after(() => app.close());

  const payload = {
    installationId: '0123456789abcdef0123456789abcdef',
    events: [
      {
        eventId: '11111111111111111111111111111111',
        occurredAt: 1700000000,
        name: 'app_open',
        properties: {},
      },
      {
        eventId: '22222222222222222222222222222222',
        occurredAt: 1700000001,
        name: 'screen_view',
        screen: '/profile/data',
        properties: {},
      },
      {
        eventId: '33333333333333333333333333333333',
        occurredAt: 1700000002,
        name: 'bookkeeping_saved',
        properties: { source: 'manual', count: 1 },
      },
    ],
  };

  const first = await app.inject({
    method: 'POST',
    url: '/api/v1/analytics/events',
    payload,
  });
  assert.equal(first.statusCode, 200);
  assert.deepEqual(first.json(), { accepted: 3, duplicates: 0 });

  const second = await app.inject({
    method: 'POST',
    url: '/api/v1/analytics/events',
    payload,
  });
  assert.equal(second.statusCode, 200);
  assert.deepEqual(second.json(), { accepted: 0, duplicates: 3 });

  const rows = store.db
    .prepare(
      'SELECT event_name,screen,properties_json FROM analytics_events ORDER BY occurred_at',
    )
    .all() as Array<{ event_name: string; screen: string | null; properties_json: string }>;
  assert.equal(rows.length, 3);
  assert.equal(rows[0]?.event_name, 'app_open');
  assert.equal(rows[1]?.screen, '/profile/data');
  assert.deepEqual(JSON.parse(rows[2]!.properties_json), {
    source: 'manual',
    count: 1,
  });
});

test('anonymous analytics rejects financial or unapproved event fields', async t => {
  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const financial = await app.inject({
    method: 'POST',
    url: '/api/v1/analytics/events',
    payload: {
      installationId: '0123456789abcdef0123456789abcdef',
      events: [
        {
          eventId: '44444444444444444444444444444444',
          occurredAt: 1700000000,
          name: 'bookkeeping_saved',
          properties: { amount: 99.9 },
        },
      ],
    },
  });
  assert.equal(financial.statusCode, 400);

  const unknown = await app.inject({
    method: 'POST',
    url: '/api/v1/analytics/events',
    payload: {
      installationId: '0123456789abcdef0123456789abcdef',
      events: [
        {
          eventId: '55555555555555555555555555555555',
          occurredAt: 1700000000,
          name: 'merchant_clicked',
          properties: {},
        },
      ],
    },
  });
  assert.equal(unknown.statusCode, 400);
});

test('server schema keeps analytics storage after later migrations', async t => {
  const { app, store } = await createApp(':memory:');
  t.after(() => app.close());
  assert.ok((store.db.pragma('user_version', { simple: true }) as number) >= 8);
  const table = store.db
    .prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='analytics_events'",
    )
    .get();
  assert.ok(table);
});


test('analytics summary requires admin key and returns aggregates only', async t => {
  const previous = process.env.ANALYTICS_ADMIN_KEY;
  process.env.ANALYTICS_ADMIN_KEY = 'analytics-admin-key-1234567890';
  t.after(() => {
    if (previous == null) delete process.env.ANALYTICS_ADMIN_KEY;
    else process.env.ANALYTICS_ADMIN_KEY = previous;
  });

  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const installationA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const installationB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const now = Math.floor(Date.now() / 1000);
  for (const [installationId, eventId, name] of [
    [installationA, '11111111111111111111111111111111', 'app_open'],
    [installationA, '22222222222222222222222222222222', 'screen_view'],
    [installationB, '33333333333333333333333333333333', 'app_open'],
  ] as const) {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/analytics/events',
      payload: {
        installationId,
        events: [
          {
            eventId,
            occurredAt: now,
            name,
            ...(name === 'screen_view' ? { screen: '/profile' } : {}),
            properties: {},
          },
        ],
      },
    });
    assert.equal(response.statusCode, 200);
  }

  const denied = await app.inject({
    method: 'GET',
    url: '/api/v1/analytics/summary?days=7',
  });
  assert.equal(denied.statusCode, 401);

  const summary = await app.inject({
    method: 'GET',
    url: '/api/v1/analytics/summary?days=7',
    headers: {
      'x-analytics-admin-key': process.env.ANALYTICS_ADMIN_KEY,
    },
  });
  assert.equal(summary.statusCode, 200);
  const body = summary.json() as any;
  assert.equal(body.activeInstallations, 2);
  assert.equal(body.totalEvents, 3);
  assert.deepEqual(body.eventsByName, [
    { name: 'app_open', count: 2 },
    { name: 'screen_view', count: 1 },
  ]);
  assert.equal(body.dailyActive.length, 1);
  assert.equal(body.dailyActive[0].installations, 2);
  assert.equal('events' in body, false);
});
