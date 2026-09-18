import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Store } from './store.js';

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
}
