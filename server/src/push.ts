import type { FastifyInstance } from 'fastify';
import { createHash } from 'node:crypto';
import { z } from 'zod';

import { requireCondition as check } from './contract.js';
import type { Store } from './store.js';

type AuthenticatedUser = { id: string; username: string };
type Authenticate = (header: string | undefined) => AuthenticatedUser;

const registration = z.strictObject({
  deviceId: z.string().regex(/^[a-f0-9]{32}$/),
  platform: z.enum(['android', 'ios']),
  provider: z.enum(['fcm', 'apns', 'vendor']),
  token: z.string().trim().min(16).max(4096),
});

const hashToken = (token: string) =>
  createHash('sha256').update(token).digest('hex');

function sessionIdFor(
  store: Store,
  header: string | undefined,
  userId: string,
) {
  check(header?.startsWith('Bearer '), '请先登录', 401);
  const row = store.db
    .prepare(
      'SELECT session_id FROM sessions '
        + 'WHERE token_hash=? AND user_id=? AND expires_at>?',
    )
    .get(hashToken(header!.slice(7)), userId, store.now()) as
    | { session_id: string | null }
    | undefined;
  check(row?.session_id, '登录已失效，请重新登录', 401);
  return row.session_id;
}

export function registerPushRoutes(
  app: FastifyInstance,
  store: Store,
  authenticate: Authenticate,
) {
  app.post('/api/v1/push/devices', async (request) => {
    const user = authenticate(request.headers.authorization);
    const sessionId = sessionIdFor(
      store,
      request.headers.authorization,
      user.id,
    );
    const input = registration.parse(request.body);
    const now = store.now();

    store.db.transaction(() => {
      // A provider token belongs to one app installation. If the same physical
      // app signs into another account, possession of the live token allows the
      // new authenticated session to claim it safely.
      store.db
        .prepare(
          'DELETE FROM push_devices '
            + 'WHERE provider=? AND token=? '
            + 'AND NOT (user_id=? AND device_id=?)',
        )
        .run(input.provider, input.token, user.id, input.deviceId);

      store.db
        .prepare(
          'INSERT INTO push_devices('
            + 'user_id,device_id,session_id,platform,provider,token,created_at,updated_at'
            + ') VALUES(?,?,?,?,?,?,?,?) '
            + 'ON CONFLICT(user_id,device_id) DO UPDATE SET '
            + 'session_id=excluded.session_id,'
            + 'platform=excluded.platform,'
            + 'provider=excluded.provider,'
            + 'token=excluded.token,'
            + 'updated_at=excluded.updated_at',
        )
        .run(
          user.id,
          input.deviceId,
          sessionId,
          input.platform,
          input.provider,
          input.token,
          now,
          now,
        );
    })();

    return {
      registered: true,
      deviceId: input.deviceId,
      platform: input.platform,
      provider: input.provider,
    };
  });

  app.get('/api/v1/push/devices', async (request) => {
    const user = authenticate(request.headers.authorization);
    const currentSessionId = sessionIdFor(
      store,
      request.headers.authorization,
      user.id,
    );
    const rows = store.db
      .prepare(
        'SELECT device_id AS deviceId,session_id AS sessionId,'
          + 'platform,provider,created_at AS createdAt,updated_at AS updatedAt '
          + 'FROM push_devices WHERE user_id=? ORDER BY updated_at DESC',
      )
      .all(user.id) as Array<{
      deviceId: string;
      sessionId: string;
      platform: string;
      provider: string;
      createdAt: number;
      updatedAt: number;
    }>;

    return {
      devices: rows.map(({ sessionId, ...row }) => ({
        ...row,
        currentSession: sessionId === currentSessionId,
      })),
    };
  });

  app.delete('/api/v1/push/devices/:deviceId', async (request) => {
    const user = authenticate(request.headers.authorization);
    const { deviceId } = z
      .object({ deviceId: z.string().regex(/^[a-f0-9]{32}$/) })
      .parse(request.params);
    store.db
      .prepare('DELETE FROM push_devices WHERE user_id=? AND device_id=?')
      .run(user.id, deviceId);
    return { ok: true };
  });
}
