import type { Store } from './store.js';

function days(name: string, fallback: number) {
  const raw = Number(process.env[name] ?? fallback);
  return Number.isFinite(raw) && raw >= 0 ? Math.floor(raw) : fallback;
}

export type RetentionPolicy = ReturnType<typeof retentionPolicy>;

export function retentionPolicy() {
  return {
    diagnosticDays: days('DIAGNOSTIC_RETENTION_DAYS', 30),
    resolvedSupportDays: days('SUPPORT_RESOLVED_RETENTION_DAYS', 365),
    adminAuditDays: days('ADMIN_AUDIT_RETENTION_DAYS', 365),
    pushOutboxDays: days('PUSH_OUTBOX_RETENTION_DAYS', 30),
    analyticsDays: days('ANALYTICS_RETENTION_DAYS', 180),
    syncTombstoneDays: days('SYNC_TOMBSTONE_RETENTION_DAYS', 90),
  };
}

function cutoff(now: number, retentionDays: number) {
  return now - retentionDays * 86400;
}

export function runRetention(store: Store) {
  const policy = retentionPolicy();
  const now = store.now();
  const deleted: Record<string, number> = {};

  const safeRun = (key: string, sql: string, value: number) => {
    try {
      deleted[key] = store.db.prepare(sql).run(value).changes;
    } catch {
      deleted[key] = 0;
    }
  };

  if (policy.diagnosticDays > 0) {
    safeRun(
      'diagnosticEvents',
      'DELETE FROM diagnostic_events WHERE occurred_at<?',
      cutoff(now, policy.diagnosticDays),
    );
  }
  if (policy.analyticsDays > 0) {
    safeRun(
      'analyticsEvents',
      'DELETE FROM analytics_events WHERE occurred_at<?',
      cutoff(now, policy.analyticsDays),
    );
  }
  if (policy.resolvedSupportDays > 0) {
    safeRun(
      'supportTickets',
      "DELETE FROM support_tickets WHERE status IN ('resolved','closed') AND updated_at<?",
      cutoff(now, policy.resolvedSupportDays),
    );
  }
  if (policy.adminAuditDays > 0) {
    safeRun(
      'adminAudit',
      'DELETE FROM admin_audit_log WHERE created_at<?',
      cutoff(now, policy.adminAuditDays),
    );
  }
  if (policy.pushOutboxDays > 0) {
    safeRun(
      'pushOutbox',
      "DELETE FROM push_outbox WHERE status IN ('sent','failed','cancelled') AND created_at<?",
      cutoff(now, policy.pushOutboxDays),
    );
  }

  let syncRetention: {
    books: number;
    changes: number;
    tombstones: number;
  } = { books: 0, changes: 0, tombstones: 0 };
  if (policy.syncTombstoneDays > 0) {
    const syncCutoff = cutoff(now, policy.syncTombstoneDays);
    const floors = store.db.prepare(
      'SELECT book_id,MAX(seq) AS floor FROM changes '
        + 'WHERE created_at<? GROUP BY book_id'
    ).all(syncCutoff) as Array<{book_id:string;floor:number|null}>;
    const upsertFloor = store.db.prepare(
      'INSERT INTO sync_retention(book_id,reset_before_cursor,updated_at) '
        + 'VALUES(?,?,?) ON CONFLICT(book_id) DO UPDATE SET '
        + 'reset_before_cursor=MAX(sync_retention.reset_before_cursor,excluded.reset_before_cursor),'
        + 'updated_at=excluded.updated_at'
    );
    const pruneTombstones = store.db.prepare(
      'DELETE FROM entities WHERE book_id=? AND deleted=1 AND EXISTS ('
        + 'SELECT 1 FROM changes c WHERE c.book_id=entities.book_id '
        + 'AND c.kind=entities.kind AND c.entity_id=entities.id '
        + 'AND c.deleted=1 AND c.created_at<?'
        + ')'
    );
    const pruneChanges = store.db.prepare(
      'DELETE FROM changes WHERE book_id=? AND created_at<?'
    );
    store.db.transaction(() => {
      for (const row of floors) {
        if (row.floor == null) continue;
        upsertFloor.run(row.book_id, row.floor, now);
        syncRetention.tombstones += pruneTombstones.run(
          row.book_id,
          syncCutoff,
        ).changes;
        syncRetention.changes += pruneChanges.run(
          row.book_id,
          syncCutoff,
        ).changes;
        syncRetention.books += 1;
      }
    })();
  }

  safeRun(
    'expiredInvitations',
    "DELETE FROM invitations WHERE status<>'pending' OR expires_at<?",
    now - 30 * 86400,
  );

  return {
    ranAt: now,
    policy,
    deleted,
    syncRetention,
    syncTombstonesPruned: policy.syncTombstoneDays > 0,
    syncTombstoneReason:
      policy.syncTombstoneDays === 0
        ? 'retained indefinitely by configuration'
        : 'pruned with a retained cursor floor; older clients are forced to full snapshot reconciliation',
  };
}
