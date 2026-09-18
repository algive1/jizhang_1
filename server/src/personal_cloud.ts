import type { FastifyInstance } from 'fastify';
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
};

const datasetId = z.string().regex(/^[a-f0-9]{32}$/);

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
    };
  }
  return {
    exists: true,
    canonicalDatasetId: row.dataset_id,
    datasetMatches: row.dataset_id === localDatasetId,
    hasSnapshot: row.has_snapshot === 1,
    revision: row.revision,
    updatedAt: row.updated_at,
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
