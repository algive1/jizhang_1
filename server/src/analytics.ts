import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Store } from './store.js';
import { requireAdminPrincipal } from './admin_auth.js';

const eventName = z.enum([
  'app_open',
  'app_foreground',
  'screen_view',
  'bookkeeping_saved',
  'bookkeeping_updated',
]);

const propertyValue = z.union([
  z.string().max(64),
  z.number().finite(),
  z.boolean(),
  z.null(),
]);

const properties = z
  .record(
    z.string().regex(/^[a-zA-Z][a-zA-Z0-9_]{0,31}$/),
    propertyValue,
  )
  .refine((value) => Object.keys(value).length <= 12, '统计字段过多')
  .refine(
    (value) =>
      Object.keys(value).every(
        (key) =>
          !/(amount|merchant|note|transaction|account|card|phone|path|attachment|token|password|category)/i.test(
            key,
          ),
      ),
    '统计数据包含受限字段',
  );

const analyticsEvent = z.strictObject({
  eventId: z.string().regex(/^[a-f0-9]{32}$/),
  occurredAt: z.number().int().nonnegative(),
  name: eventName,
  screen: z.string().trim().min(1).max(100).optional(),
  properties: properties.optional().default({}),
});

const analyticsBody = z.strictObject({
  installationId: z.string().regex(/^[a-f0-9]{32}$/),
  events: z.array(analyticsEvent).min(1).max(50),
});

export function registerAnalyticsRoutes(app: FastifyInstance, store: Store) {
  app.post(
    '/api/v1/analytics/events',
    { config: { rateLimit: { max: 60, timeWindow: '1 minute' } } },
    async (request) => {
      const body = analyticsBody.parse(request.body);
      const insert = store.db.prepare(`
        INSERT INTO analytics_events(
          installation_id,event_id,occurred_at,event_name,screen,properties_json,created_at
        ) VALUES(?,?,?,?,?,?,?)
        ON CONFLICT(installation_id,event_id) DO NOTHING
      `);
      const now = store.now();
      let accepted = 0;
      store.db.transaction(() => {
        for (const event of body.events) {
          const result = insert.run(
            body.installationId,
            event.eventId,
            event.occurredAt,
            event.name,
            event.screen ?? null,
            JSON.stringify(event.properties),
            now,
          );
          accepted += result.changes;
        }
      })();
      return {
        accepted,
        duplicates: body.events.length - accepted,
      };
    },
  );

  app.get('/api/v1/analytics/summary', async (request) => {
    requireAdminPrincipal(request.headers['x-admin-token'],'dashboard.read');
    const { days } = z
      .strictObject({
        days: z.coerce.number().int().min(1).max(90).default(7),
      })
      .parse(request.query);
    const now = store.now();
    const since = now - days * 86400;

    const totals = store.db
      .prepare(
        'SELECT COUNT(*) AS totalEvents, '
          + 'COUNT(DISTINCT installation_id) AS activeInstallations '
          + 'FROM analytics_events WHERE occurred_at>=?',
      )
      .get(since) as { totalEvents: number; activeInstallations: number };

    const eventsByName = store.db
      .prepare(
        'SELECT event_name AS name,COUNT(*) AS count '
          + 'FROM analytics_events WHERE occurred_at>=? '
          + 'GROUP BY event_name ORDER BY count DESC,event_name ASC',
      )
      .all(since) as Array<{ name: string; count: number }>;

    const dailyActive = store.db
      .prepare(
        "SELECT strftime('%Y-%m-%d',occurred_at,'unixepoch') AS day,"
          + 'COUNT(DISTINCT installation_id) AS installations '
          + 'FROM analytics_events WHERE occurred_at>=? '
          + 'GROUP BY day ORDER BY day ASC',
      )
      .all(since) as Array<{ day: string; installations: number }>;

    return {
      days,
      since,
      until: now,
      activeInstallations: totals.activeInstallations,
      totalEvents: totals.totalEvents,
      eventsByName,
      dailyActive,
    };
  });
}
