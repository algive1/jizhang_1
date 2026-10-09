import { createHash, timingSafeEqual } from 'node:crypto';
import { requireCondition as check } from './contract.js';
import type { Store } from './store.js';

export function requireAdmin(header: string | string[] | undefined) {
  const configured = (process.env.ADMIN_TOKEN ?? '').trim();
  check(configured.length >= 24, '管理后台未启用', 404);
  const provided = (Array.isArray(header) ? header[0] : header) ?? '';
  const digest = (value: string) => createHash('sha256').update(value).digest();
  check(timingSafeEqual(digest(configured), digest(provided)), '管理令牌无效', 401);
}

export function audit(store: Store, action: string, details: Record<string, unknown> = {}) {
  store.db.prepare('INSERT INTO admin_audit_log(action,details_json,created_at) VALUES(?,?,?)')
    .run(action, JSON.stringify(details), store.now());
}
