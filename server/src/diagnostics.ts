import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from './store.js';

type AuthenticatedUser = { id: string; username: string };
type Authenticate = (header: string | undefined) => AuthenticatedUser;

const diagnosticValue = z.union([
  z.string().max(160),
  z.number().finite(),
  z.boolean(),
  z.null(),
]);
const diagnosticData = z
  .record(z.string().regex(/^[a-zA-Z][a-zA-Z0-9_]{0,31}$/), diagnosticValue)
  .refine((data) => Object.keys(data).length <= 24, '诊断字段过多')
  .refine(
    (data) =>
      Object.keys(data).every(
        (key) =>
          !/(token|password|notification|account|card|phone|path|stack)/i.test(
            key,
          ),
      ),
    '诊断数据包含受限字段',
  );
const diagnosticEvent = z.strictObject({
  event_id: z.string().regex(/^[A-Za-z0-9._:-]{1,160}$/),
  occurred_at: z.number().int().nonnegative(),
  level: z.enum(['info', 'warn', 'error']),
  kind: z.string().trim().min(1).max(64),
  screen: z.string().trim().max(120).optional(),
  message: z.string().trim().max(500).optional(),
  data: diagnosticData.optional().default({}),
});
const diagnosticsBody = z.strictObject({
  events: z.array(diagnosticEvent).min(1).max(200),
});

export function registerDiagnosticsRoutes(
  app: FastifyInstance,
  store: Store,
  authenticate: Authenticate,
) {
  app.post('/api/v1/diagnostics/events', async (request) => {
    const user = authenticate(request.headers.authorization);
    const body = diagnosticsBody.parse(request.body);
    const insert = store.db.prepare(`
      INSERT INTO diagnostic_events(
        user_id,event_id,occurred_at,level,kind,screen,message,data_json,created_at
      ) VALUES(?,?,?,?,?,?,?,?,?)
      ON CONFLICT(user_id,event_id) DO NOTHING
    `);
    let accepted = 0;
    const now = store.now();
    const write = store.db.transaction(() => {
      for (const event of body.events) {
        const result = insert.run(
          user.id,
          event.event_id,
          event.occurred_at,
          event.level,
          event.kind,
          event.screen ?? null,
          event.message ?? null,
          JSON.stringify(event.data),
          now,
        );
        accepted += result.changes;
      }
    });
    write();
    return { accepted, duplicates: body.events.length - accepted };
  });
}
