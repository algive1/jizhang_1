import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { requireCondition as check } from './contract.js';
import type { Store } from './store.js';

type User = { id: string; username: string };
type Authenticate = (header: string | undefined) => User;

export type AnnouncementInput = {
  title: string;
  body: string;
  route?: string | null;
  expiresAt?: number | null;
};

export function ensureMessageCenterSchema(store: Store) {
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS announcements(
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      route TEXT,
      published_at INTEGER NOT NULL,
      expires_at INTEGER,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_announcements_active
      ON announcements(published_at,expires_at);
    CREATE TABLE IF NOT EXISTS announcement_reads(
      user_id TEXT NOT NULL REFERENCES users(id),
      announcement_id TEXT NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
      read_at INTEGER NOT NULL,
      PRIMARY KEY(user_id,announcement_id)
    );
    CREATE INDEX IF NOT EXISTS idx_announcement_reads_user
      ON announcement_reads(user_id,read_at DESC);
  `);
}

export function createAnnouncement(store: Store, input: AnnouncementInput) {
  ensureMessageCenterSchema(store);
  const now = store.now();
  const row = {
    id: randomUUID(),
    title: input.title.trim(),
    body: input.body.trim(),
    route: input.route?.trim() || null,
    publishedAt: now,
    expiresAt: input.expiresAt ?? null,
    createdAt: now,
  };
  store.db.prepare(
    'INSERT INTO announcements(id,title,body,route,published_at,expires_at,created_at) '
      + 'VALUES(?,?,?,?,?,?,?)',
  ).run(
    row.id,
    row.title,
    row.body,
    row.route,
    row.publishedAt,
    row.expiresAt,
    row.createdAt,
  );
  return row;
}

export function registerMessageCenterRoutes(
  app: FastifyInstance,
  store: Store,
  authenticate: Authenticate,
) {
  ensureMessageCenterSchema(store);

  app.get('/api/v1/messages', async (request) => {
    const user = authenticate(request.headers.authorization);
    const { limit } = z.strictObject({
      limit: z.coerce.number().int().min(1).max(100).default(50),
    }).parse(request.query);
    const now = store.now();
    const messages = store.db.prepare(
      'SELECT a.id,a.title,a.body,a.route,a.published_at AS publishedAt,'
        + 'a.expires_at AS expiresAt,'
        + 'CASE WHEN r.read_at IS NULL THEN 0 ELSE 1 END AS isRead,'
        + 'r.read_at AS readAt '
        + 'FROM announcements a '
        + 'LEFT JOIN announcement_reads r '
        + 'ON r.announcement_id=a.id AND r.user_id=? '
        + 'WHERE a.published_at<=? AND (a.expires_at IS NULL OR a.expires_at>?) '
        + 'ORDER BY a.published_at DESC LIMIT ?',
    ).all(user.id, now, now, limit);
    const unread = store.db.prepare(
      'SELECT COUNT(*) AS n FROM announcements a '
        + 'LEFT JOIN announcement_reads r '
        + 'ON r.announcement_id=a.id AND r.user_id=? '
        + 'WHERE a.published_at<=? AND (a.expires_at IS NULL OR a.expires_at>?) '
        + 'AND r.read_at IS NULL',
    ).get(user.id, now, now) as { n: number };
    return { messages, unread: unread.n };
  });

  app.post('/api/v1/messages/:id/read', async (request) => {
    const user = authenticate(request.headers.authorization);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const exists = store.db.prepare(
      'SELECT 1 FROM announcements WHERE id=? AND published_at<=?',
    ).get(id, store.now());
    check(exists, '消息不存在', 404);
    store.db.prepare(
      'INSERT INTO announcement_reads(user_id,announcement_id,read_at) VALUES(?,?,?) '
        + 'ON CONFLICT(user_id,announcement_id) DO UPDATE SET read_at=excluded.read_at',
    ).run(user.id, id, store.now());
    return { ok: true };
  });

  app.post('/api/v1/messages/read-all', async (request) => {
    const user = authenticate(request.headers.authorization);
    const now = store.now();
    store.db.prepare(
      'INSERT INTO announcement_reads(user_id,announcement_id,read_at) '
        + 'SELECT ?,id,? FROM announcements '
        + 'WHERE published_at<=? AND (expires_at IS NULL OR expires_at>?) '
        + 'ON CONFLICT(user_id,announcement_id) DO UPDATE SET read_at=excluded.read_at',
    ).run(user.id, now, now, now);
    return { ok: true };
  });
}
