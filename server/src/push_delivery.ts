import { createSign, randomUUID } from 'node:crypto';
import { connect } from 'node:http2';

import type { Store } from './store.js';

export type PushPayload = {
  title: string;
  body: string;
  route?: string | null;
};

type PushDevice = {
  user_id: string;
  device_id: string;
  platform: 'android' | 'ios';
  provider: 'fcm' | 'apns' | 'vendor';
  token: string;
};

type OutboxRow = PushDevice & {
  id: string;
  title: string;
  body: string;
  route: string | null;
  attempts: number;
};

let cachedFcmToken: { token: string; expiresAt: number } | null = null;

function requiredEnv(name: string): string {
  const value = (process.env[name] ?? '').trim();
  if (!value) throw new Error(`${name} is not configured`);
  return value.replaceAll('\\n', '\n');
}

function base64Url(value: string | Buffer) {
  return Buffer.from(value).toString('base64url');
}

function jwt(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  privateKey: string,
  algorithm: 'RSA-SHA256' | 'SHA256',
  p1363 = false,
) {
  const unsigned = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(payload))}`;
  const signer = createSign(algorithm);
  signer.update(unsigned);
  signer.end();
  const signature = p1363
    ? signer.sign({ key: privateKey, dsaEncoding: 'ieee-p1363' })
    : signer.sign(privateKey);
  return `${unsigned}.${signature.toString('base64url')}`;
}

async function fcmAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedFcmToken && cachedFcmToken.expiresAt - 60 > now) {
    return cachedFcmToken.token;
  }
  const clientEmail = requiredEnv('FCM_CLIENT_EMAIL');
  const privateKey = requiredEnv('FCM_PRIVATE_KEY');
  const assertion = jwt(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: clientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    privateKey,
    'RSA-SHA256',
  );
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
    signal: AbortSignal.timeout(15_000),
  });
  const data = await response.json() as { access_token?: string; expires_in?: number };
  if (!response.ok || !data.access_token) {
    throw new Error(`FCM OAuth failed (${response.status})`);
  }
  cachedFcmToken = {
    token: data.access_token,
    expiresAt: now + Math.max(300, data.expires_in ?? 3600),
  };
  return data.access_token;
}

async function sendFcm(token: string, payload: PushPayload) {
  const projectId = requiredEnv('FCM_PROJECT_ID');
  const accessToken = await fcmAccessToken();
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: payload.title, body: payload.body },
          data: payload.route ? { route: payload.route } : {},
          android: { priority: 'high' },
          apns: {
            payload: { aps: { sound: 'default' } },
          },
        },
      }),
      signal: AbortSignal.timeout(15_000),
    },
  );
  if (!response.ok) {
    const raw = (await response.text()).slice(0, 500);
    throw new Error(`FCM send failed (${response.status}): ${raw}`);
  }
}

function apnsAuthorization() {
  const keyId = requiredEnv('APNS_KEY_ID');
  const teamId = requiredEnv('APNS_TEAM_ID');
  const privateKey = requiredEnv('APNS_PRIVATE_KEY');
  const now = Math.floor(Date.now() / 1000);
  return jwt(
    { alg: 'ES256', kid: keyId },
    { iss: teamId, iat: now },
    privateKey,
    'SHA256',
    true,
  );
}

async function sendApns(token: string, payload: PushPayload) {
  const bundleId = requiredEnv('APNS_BUNDLE_ID');
  const host =
    (process.env.APNS_ENV ?? 'production').trim().toLowerCase() === 'sandbox'
      ? 'https://api.sandbox.push.apple.com'
      : 'https://api.push.apple.com';
  const client = connect(host);
  try {
    await new Promise<void>((resolve, reject) => {
      const request = client.request({
        ':method': 'POST',
        ':path': `/3/device/${token}`,
        'apns-topic': bundleId,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        authorization: `bearer ${apnsAuthorization()}`,
        'content-type': 'application/json',
      });
      let status = 0;
      let raw = '';
      request.setEncoding('utf8');
      request.on('response', (headers) => {
        status = Number(headers[':status'] ?? 0);
      });
      request.on('data', (chunk) => {
        raw += chunk;
      });
      request.on('end', () => {
        if (status >= 200 && status < 300) resolve();
        else reject(new Error(`APNs send failed (${status}): ${raw.slice(0, 500)}`));
      });
      request.on('error', reject);
      request.end(JSON.stringify({
        aps: {
          alert: { title: payload.title, body: payload.body },
          sound: 'default',
        },
        ...(payload.route ? { route: payload.route } : {}),
      }));
    });
  } finally {
    client.close();
  }
}

async function sendVendor(token: string, payload: PushPayload) {
  const endpoint = requiredEnv('VENDOR_PUSH_URL');
  const key = requiredEnv('VENDOR_PUSH_TOKEN');
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${key}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ token, ...payload }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) {
    throw new Error(`Vendor push failed (${response.status})`);
  }
}

async function sendToDevice(device: PushDevice, payload: PushPayload) {
  if (device.provider === 'fcm') return sendFcm(device.token, payload);
  if (device.provider === 'apns') return sendApns(device.token, payload);
  return sendVendor(device.token, payload);
}

export function ensurePushDeliverySchema(store: Store) {
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS push_outbox(
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      platform TEXT NOT NULL,
      provider TEXT NOT NULL,
      token TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      route TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      next_attempt_at INTEGER NOT NULL,
      last_error TEXT,
      created_at INTEGER NOT NULL,
      sent_at INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_push_outbox_pending
      ON push_outbox(status,next_attempt_at,created_at);
    CREATE INDEX IF NOT EXISTS idx_push_outbox_user
      ON push_outbox(user_id,created_at DESC);
  `);
}

export function queuePushForUser(
  store: Store,
  userId: string,
  payload: PushPayload,
) {
  ensurePushDeliverySchema(store);
  const devices = store.db.prepare(
    'SELECT user_id,device_id,platform,provider,token FROM push_devices WHERE user_id=?',
  ).all(userId) as PushDevice[];
  const now = store.now();
  const insert = store.db.prepare(
    'INSERT INTO push_outbox('
      + 'id,user_id,device_id,platform,provider,token,title,body,route,status,attempts,next_attempt_at,created_at'
      + ') VALUES(?,?,?,?,?,?,?,?,?,\'pending\',0,?,?)',
  );
  store.db.transaction(() => {
    for (const device of devices) {
      insert.run(
        randomUUID(),
        device.user_id,
        device.device_id,
        device.platform,
        device.provider,
        device.token,
        payload.title,
        payload.body,
        payload.route ?? null,
        now,
        now,
      );
    }
  })();
  return devices.length;
}

export function queuePushForAllRegisteredUsers(store: Store, payload: PushPayload) {
  ensurePushDeliverySchema(store);
  const users = store.db.prepare(
    'SELECT DISTINCT user_id FROM push_devices',
  ).all() as Array<{ user_id: string }>;
  let queued = 0;
  for (const row of users) queued += queuePushForUser(store, row.user_id, payload);
  return queued;
}

export async function dispatchPushOutbox(store: Store, limit = 50) {
  ensurePushDeliverySchema(store);
  const now = store.now();
  const rows = store.db.prepare(
    'SELECT * FROM push_outbox '
      + 'WHERE status=\'pending\' AND next_attempt_at<=? '
      + 'ORDER BY created_at ASC LIMIT ?',
  ).all(now, limit) as OutboxRow[];
  let sent = 0;
  let failed = 0;
  for (const row of rows) {
    const stillRegistered = store.db.prepare(
      'SELECT 1 FROM push_devices WHERE user_id=? AND device_id=? AND provider=? AND token=?',
    ).get(row.user_id, row.device_id, row.provider, row.token);
    if (!stillRegistered) {
      store.db.prepare(
        "UPDATE push_outbox SET status='cancelled',last_error='device removed' WHERE id=?",
      ).run(row.id);
      continue;
    }
    try {
      await sendToDevice(row, {
        title: row.title,
        body: row.body,
        route: row.route,
      });
      store.db.prepare(
        "UPDATE push_outbox SET status='sent',sent_at=?,last_error=NULL WHERE id=?",
      ).run(store.now(), row.id);
      sent += 1;
    } catch (error) {
      const attempts = row.attempts + 1;
      const terminal = attempts >= 20;
      const delay = Math.min(6 * 3600, 60 * 2 ** Math.min(attempts, 8));
      store.db.prepare(
        'UPDATE push_outbox SET status=?,attempts=?,next_attempt_at=?,last_error=? WHERE id=?',
      ).run(
        terminal ? 'failed' : 'pending',
        attempts,
        store.now() + delay,
        String(error).slice(0, 500),
        row.id,
      );
      failed += 1;
    }
  }
  return { processed: rows.length, sent, failed };
}

export function startPushWorker(store: Store) {
  ensurePushDeliverySchema(store);
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      await dispatchPushOutbox(store);
    } catch (error) {
      console.error('push worker failed', error);
    } finally {
      running = false;
    }
  };
  const timer = setInterval(() => { void tick(); }, 30_000);
  timer.unref();
  void tick();
  return () => clearInterval(timer);
}
