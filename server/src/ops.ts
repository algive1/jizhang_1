import type { FastifyInstance } from 'fastify';

import type { Store } from './store.js';

export function registerOperationalRoutes(app: FastifyInstance, store: Store) {
  const startedAt = Date.now();
  let requests = 0;
  let failures = 0;

  app.addHook('onResponse', async (_request, reply) => {
    requests += 1;
    if (reply.statusCode >= 500) failures += 1;
  });

  app.get('/health', async () => ({
    status: 'ok',
    uptimeSeconds: Math.floor((Date.now() - startedAt) / 1000),
  }));

  app.get('/ready', async (_request, reply) => {
    try {
      const value = store.db.prepare('SELECT 1 AS ok').get() as { ok: number };
      if (value.ok !== 1) throw new Error('database readiness failed');
      return { status: 'ready', database: 'ok' };
    } catch {
      return reply.code(503).send({ status: 'not_ready', database: 'error' });
    }
  });

  app.get('/metrics', async (_request, reply) => {
    const users = (store.db.prepare('SELECT COUNT(*) AS n FROM users').get() as { n: number }).n;
    const activeSessions = (
      store.db.prepare('SELECT COUNT(*) AS n FROM sessions WHERE expires_at>?').get(store.now()) as { n: number }
    ).n;
    let pendingPush = 0;
    try {
      pendingPush = (
        store.db.prepare("SELECT COUNT(*) AS n FROM push_outbox WHERE status='pending'").get() as { n: number }
      ).n;
    } catch {
      // The outbox schema is optional during the earliest migration.
    }
    const body = [
      '# TYPE haohao_http_requests_total counter',
      `haohao_http_requests_total ${requests}`,
      '# TYPE haohao_http_failures_total counter',
      `haohao_http_failures_total ${failures}`,
      '# TYPE haohao_users gauge',
      `haohao_users ${users}`,
      '# TYPE haohao_active_sessions gauge',
      `haohao_active_sessions ${activeSessions}`,
      '# TYPE haohao_push_pending gauge',
      `haohao_push_pending ${pendingPush}`,
      '',
    ].join('\n');
    return reply.type('text/plain; version=0.0.4; charset=utf-8').send(body);
  });
}
