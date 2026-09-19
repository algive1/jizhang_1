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
    CREATE TABLE IF NOT EXISTS support_ticket_messages(
      id TEXT PRIMARY KEY,
      ticket_id TEXT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
      author_type TEXT NOT NULL CHECK(author_type IN ('user','admin')),
      body TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_support_ticket_messages_ticket
      ON support_ticket_messages(ticket_id,created_at ASC);
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
      store.db.transaction(() => {
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
        store.db.prepare(
          'INSERT INTO support_ticket_messages(id,ticket_id,author_type,body,created_at) '
            + 'VALUES(?,?,\'user\',?,?)',
        ).run(randomUUID(), id, input.message, now);
      })();
      return reply.code(201).send({ id, status: 'open', createdAt: now });
    },
  );

  app.get('/api/v1/support/tickets', async (request) => {
    const user = authenticate(request.headers.authorization);
    const tickets = store.db.prepare(
      'SELECT t.id,t.subject,t.status,t.created_at AS createdAt,t.updated_at AS updatedAt,'
        + 't.resolved_at AS resolvedAt,'
        + '(SELECT MAX(m.created_at) FROM support_ticket_messages m WHERE m.ticket_id=t.id) AS lastMessageAt,'
        + '(SELECT COUNT(*) FROM support_ticket_messages m WHERE m.ticket_id=t.id) AS messageCount '
        + 'FROM support_tickets t WHERE t.user_id=? '
        + 'ORDER BY t.updated_at DESC,t.created_at DESC LIMIT 50',
    ).all(user.id);
    return { tickets };
  });

  app.get('/api/v1/support/tickets/:id', async (request) => {
    const user = authenticate(request.headers.authorization);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const ticket = store.db.prepare(
      'SELECT id,subject,status,contact,app_version AS appVersion,'
        + 'created_at AS createdAt,updated_at AS updatedAt,resolved_at AS resolvedAt '
        + 'FROM support_tickets WHERE id=? AND user_id=?',
    ).get(id, user.id);
    if (!ticket) {
      const error = new Error('工单不存在') as Error & { statusCode?: number };
      error.statusCode = 404;
      throw error;
    }
    const messages = store.db.prepare(
      'SELECT id,author_type AS authorType,body,created_at AS createdAt '
        + 'FROM support_ticket_messages WHERE ticket_id=? ORDER BY created_at ASC,id ASC',
    ).all(id);
    return { ticket, messages };
  });

  app.post(
    '/api/v1/support/tickets/:id/messages',
    { config: { rateLimit: { max: 20, timeWindow: '1 hour' } } },
    async (request, reply) => {
      const user = authenticate(request.headers.authorization);
      const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
      const { body } = z.strictObject({
        body: z.string().trim().min(1).max(4000),
      }).parse(request.body);
      const ticket = store.db.prepare(
        'SELECT id,status FROM support_tickets WHERE id=? AND user_id=?',
      ).get(id, user.id) as { id:string; status:string }|undefined;
      if (!ticket) {
        const error = new Error('工单不存在') as Error & { statusCode?: number };
        error.statusCode = 404;
        throw error;
      }
      const now = store.now();
      const messageId = randomUUID();
      store.db.transaction(() => {
        store.db.prepare(
          'INSERT INTO support_ticket_messages(id,ticket_id,author_type,body,created_at) '
            + 'VALUES(?,?,\'user\',?,?)',
        ).run(messageId, id, body, now);
        store.db.prepare(
          "UPDATE support_tickets SET status='open',updated_at=?,resolved_at=NULL WHERE id=?",
        ).run(now, id);
      })();
      return reply.code(201).send({
        id: messageId,
        authorType: 'user',
        body,
        createdAt: now,
      });
    },
  );
}
