import type { FastifyInstance } from 'fastify';
import { createHash } from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import { z } from 'zod';

import { requireCondition as check } from './contract.js';
import type { Store } from './store.js';

type User = { id: string; username: string };
type Authenticate = (header: string | undefined) => User;

type DatasetRow = {
  user_id: string;
  dataset_id: string;
  revision: number;
  has_snapshot: number;
  created_at: number;
  updated_at: number;
  snapshot_blob: Buffer | null;
  snapshot_sha256: string | null;
  snapshot_size: number | null;
};

const datasetId = z.string().regex(/^[a-f0-9]{32}$/);
const snapshotEncoding = z.enum(['gzip+base64', 'gzip+base64+json-v2']);
const snapshotPackageV2 = z.strictObject({
  format: z.literal('haohao-cloud-v2'),
  database: z.string().min(1),
  attachments: z.array(
    z.strictObject({
      id: z.string().min(1).max(200),
      name: z.string().max(255),
      content: z.string().nullable(),
    }),
  ).max(2000),
});

function unpackSnapshot(compressed: Buffer, encoding: z.infer<typeof snapshotEncoding>) {
  let unpacked: Buffer;
  try {
    unpacked = gunzipSync(compressed, { maxOutputLength: 64 * 1024 * 1024 });
  } catch {
    check(false, '云端备份内容无效', 400);
    throw new Error('unreachable');
  }

  if (encoding === 'gzip+base64') {
    check(
      unpacked.subarray(0, 16).toString('binary') === 'SQLite format 3\u0000',
      '云端备份不是有效的好好记账数据库',
      400,
    );
    return { sqlite: unpacked, totalSize: unpacked.length };
  }

  let rawPackage: unknown;
  try {
    rawPackage = JSON.parse(unpacked.toString('utf8'));
  } catch {
    check(false, '云端附件备份格式无效', 400);
    throw new Error('unreachable');
  }
  const packageV2 = snapshotPackageV2.parse(rawPackage);
  const sqlite = Buffer.from(packageV2.database, 'base64');
  check(
    sqlite.subarray(0, 16).toString('binary') === 'SQLite format 3\u0000',
    '云端备份不是有效的好好记账数据库',
    400,
  );
  let totalSize = sqlite.length;
  for (const attachment of packageV2.attachments) {
    if (attachment.content != null) {
      totalSize += Buffer.from(attachment.content, 'base64').length;
    }
  }
  check(totalSize <= 48 * 1024 * 1024, '账务与附件备份解压后过大', 413);
  return { sqlite, totalSize };
}

function detectSnapshotEncoding(compressed: Buffer): z.infer<typeof snapshotEncoding> {
  try {
    const unpacked = gunzipSync(compressed, { maxOutputLength: 64 * 1024 * 1024 });
    if (unpacked.subarray(0, 16).toString('binary') === 'SQLite format 3\u0000') {
      return 'gzip+base64';
    }
    const value = JSON.parse(unpacked.toString('utf8')) as { format?: unknown };
    if (value?.format === 'haohao-cloud-v2') return 'gzip+base64+json-v2';
  } catch {
    // Existing corrupt data is rejected below with a stable API message.
  }
  check(false, '云端备份内容无效', 500);
  throw new Error('unreachable');
}

function hasCloudEntitlement(store: Store, userId: string) {
  const row = store.db
    .prepare(
      'SELECT expires_at FROM membership_subscriptions WHERE user_id=? AND expires_at>?',
    )
    .get(userId, store.now()) as { expires_at: number } | undefined;
  return row != null;
}

function status(row: DatasetRow | undefined, localDatasetId: string) {
  if (!row) {
    return {
      exists: false,
      canonicalDatasetId: null,
      datasetMatches: false,
      hasSnapshot: false,
      revision: 0,
      updatedAt: null,
      snapshotSize: null,
      snapshotSha256: null,
    };
  }
  return {
    exists: true,
    canonicalDatasetId: row.dataset_id,
    datasetMatches: row.dataset_id === localDatasetId,
    hasSnapshot: row.has_snapshot === 1,
    revision: row.revision,
    updatedAt: row.updated_at,
    snapshotSize: row.snapshot_size,
    snapshotSha256: row.snapshot_sha256,
  };
}

export function registerPersonalCloudRoutes(
  app: FastifyInstance,
  store: Store,
  authenticate: Authenticate,
) {
  app.get('/api/v1/sync/status', async (req) => {
    const user = authenticate(req.headers.authorization);
    check(hasCloudEntitlement(store, user.id), '云同步需要有效会员', 403);
    const input = z.strictObject({ datasetId }).parse(req.query);
    const row = store.db
      .prepare('SELECT * FROM cloud_datasets WHERE user_id=?')
      .get(user.id) as DatasetRow | undefined;
    return status(row, input.datasetId);
  });

  app.get('/api/v1/sync/snapshot/download', async (req) => {
    const user = authenticate(req.headers.authorization);
    check(hasCloudEntitlement(store, user.id), '云同步需要有效会员', 403);
    const row = store.db
      .prepare('SELECT * FROM cloud_datasets WHERE user_id=?')
      .get(user.id) as DatasetRow | undefined;
    check(row && row.has_snapshot === 1 && row.snapshot_blob, '云端还没有可恢复的备份', 404);
    return {
      datasetId: row.dataset_id,
      revision: row.revision,
      encoding: detectSnapshotEncoding(row.snapshot_blob),
      snapshot: row.snapshot_blob.toString('base64'),
      snapshotSize: row.snapshot_size,
      snapshotSha256: row.snapshot_sha256,
      updatedAt: row.updated_at,
    };
  });

  app.post('/api/v1/sync/snapshot', async (req) => {
    const user = authenticate(req.headers.authorization);
    check(hasCloudEntitlement(store, user.id), '云同步需要有效会员', 403);
    const input = z.strictObject({
      datasetId,
      baseRevision: z.number().int().nonnegative(),
      encoding: snapshotEncoding,
      snapshot: z.string().min(1).max(14_000_000),
    }).parse(req.body);

    const row = store.db
      .prepare('SELECT * FROM cloud_datasets WHERE user_id=?')
      .get(user.id) as DatasetRow | undefined;
    check(row, '请先建立云同步通道', 409);
    check(row.dataset_id === input.datasetId, '本地数据集与云端数据集不一致', 409);
    check(row.revision === input.baseRevision, '云端数据已更新，请先检查最新状态', 409);

    const compressed = Buffer.from(input.snapshot, 'base64');
    check(compressed.length <= 10 * 1024 * 1024, '云端备份暂时不能超过 10MB（压缩后）', 413);
    const unpacked = unpackSnapshot(compressed, input.encoding);
    const sha256 = createHash('sha256').update(unpacked.sqlite).digest('hex');
    const revision = row.revision + 1;
    const now = store.now();
    store.db.prepare(
      'UPDATE cloud_datasets SET revision=?,has_snapshot=1,snapshot_blob=?,snapshot_sha256=?,snapshot_size=?,updated_at=? WHERE user_id=?',
    ).run(revision, compressed, sha256, unpacked.totalSize, now, user.id);

    const updated = store.db
      .prepare('SELECT * FROM cloud_datasets WHERE user_id=?')
      .get(user.id) as DatasetRow;
    return status(updated, input.datasetId);
  });

  app.post('/api/v1/sync/bootstrap', async (req) => {
    const user = authenticate(req.headers.authorization);
    check(hasCloudEntitlement(store, user.id), '云同步需要有效会员', 403);
    const input = z.strictObject({ datasetId }).parse(req.body);

    const ownedByOther = store.db
      .prepare('SELECT user_id FROM cloud_datasets WHERE dataset_id=?')
      .get(input.datasetId) as { user_id: string } | undefined;
    check(
      !ownedByOther || ownedByOther.user_id === user.id,
      '该本地数据集已属于其他账号',
      409,
    );

    let row = store.db
      .prepare('SELECT * FROM cloud_datasets WHERE user_id=?')
      .get(user.id) as DatasetRow | undefined;
    if (!row) {
      const now = store.now();
      store.db
        .prepare(
          'INSERT INTO cloud_datasets(user_id,dataset_id,revision,has_snapshot,created_at,updated_at) VALUES(?,?,0,0,?,?)',
        )
        .run(user.id, input.datasetId, now, now);
      row = store.db
        .prepare('SELECT * FROM cloud_datasets WHERE user_id=?')
        .get(user.id) as DatasetRow;
    }
    return status(row, input.datasetId);
  });
}
