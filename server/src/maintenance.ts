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
    syncTombstoneDays: days('SYNC_TOMBSTONE_RETENTION_DAYS', 0),
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

  // Shared-ledger changes are cursor-based replication history. Pruning them
  // without a per-device acknowledged cursor can make a long-offline device
  // miss a deletion forever. Therefore tombstones are retained indefinitely
  // by default. A non-zero setting is intentionally reported but not applied
  // until an acknowledgement watermark is implemented.
  safeRun(
    'expiredInvitations',
    "DELETE FROM invitations WHERE status<>'pending' OR expires_at<?",
    now - 30 * 86400,
  );

  return {
    ranAt: now,
    policy,
    deleted,
    syncTombstonesPruned: false,
    syncTombstoneReason:
      policy.syncTombstoneDays === 0
        ? 'retained indefinitely'
        : 'retained because no safe per-device acknowledgement watermark exists',
  };
}
