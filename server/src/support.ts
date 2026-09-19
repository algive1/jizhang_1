import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Store } from './store.js';

type User = { id: string; username: string };
type Authenticate = (header: string | undefined) => User;

export function ensureSupportSchema(store: Store) {
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS support_tickets(
      id TEXT PRIMARY KEY,
      user_id TEXT,
      installation_id TEXT NOT NULL,
      subject TEXT NOT NULL,
      message TEXT NOT NULL,
      contact TEXT,
      app_version TEXT,
      status TEXT NOT NULL DEFAULT 'open',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      resolved_at INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_support_tickets_status
      ON support_tickets(status,created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_support_tickets_user
      ON support_tickets(user_id,created_at DESC);
  `);
}

const createTicketSchema = z.strictObject({
  installationId: z.string().regex(/^[a-f0-9]{32}$/),
  subject: z.string().trim().min(2).max(80),
  message: z.string().trim().min(5).max(4000),
  contact: z.string().trim().max(120).optional(),
  appVersion: z.string().trim().max(40).optional(),
});

export function registerSupportRoutes(
  app: FastifyInstance,
  store: Store,
  authenticate: Authenticate,
) {
  ensureSupportSchema(store);

  app.post(
    '/api/v1/support/tickets',
    { config: { rateLimit: { max: 10, timeWindow: '1 hour' } } },
    async (request, reply) => {
      const input = createTicketSchema.parse(request.body);
      let user: User | null = null;
      if (request.headers.authorization) {
        user = authenticate(request.headers.authorization);
      }
      const now = store.now();
      const id = randomUUID();
      store.db.prepare(
        'INSERT INTO support_tickets('
          + 'id,user_id,installation_id,subject,message,contact,app_version,status,created_at,updated_at'
          + ') VALUES(?,?,?,?,?,?,?,\'open\',?,?)',
      ).run(
        id,
        user?.id ?? null,
        input.installationId,
        input.subject,
        input.message,
        input.contact?.trim() || null,
        input.appVersion?.trim() || null,
        now,
        now,
      );
      return reply.code(201).send({ id, status: 'open', createdAt: now });
    },
  );

  app.get('/api/v1/support/tickets', async (request) => {
    const user = authenticate(request.headers.authorization);
    const tickets = store.db.prepare(
      'SELECT id,subject,status,created_at AS createdAt,updated_at AS updatedAt,'
        + 'resolved_at AS resolvedAt FROM support_tickets '
        + 'WHERE user_id=? ORDER BY created_at DESC LIMIT 50',
    ).all(user.id);
    return { tickets };
  });
}
