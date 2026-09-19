import { createHash, timingSafeEqual } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { requireCondition as check } from './contract.js';
import type { Store } from './store.js';

export type AdminRole = 'super_admin' | 'operator' | 'support' | 'developer' | 'finance';

const permissionSchema = z.enum([
  'dashboard.read',
  'users.read',
  'users.sensitive.read',
  'investments.sensitive.read',
  'membership.read',
  'membership.write',
  'releases.read',
  'releases.write',
  'messages.write',
  'ai.read',
  'ai.write',
  'logs.read',
  'support.write',
  'audit.read',
]);

export type AdminPermission = z.infer<typeof permissionSchema>;

const rolePermissions: Record<AdminRole, readonly AdminPermission[]> = {
  super_admin: permissionSchema.options,
  operator: ['dashboard.read','users.read','membership.read','releases.read','messages.write','ai.read'],
  support: ['dashboard.read','users.read','membership.read','support.write'],
  developer: ['dashboard.read','releases.read','releases.write','ai.read','ai.write','logs.read'],
  finance: ['dashboard.read','users.read','membership.read','audit.read'],
};

function digest(value: string) {
  return createHash('sha256').update(value).digest();
}

function equalSecret(left: string, right: string) {
  return left.length === right.length && timingSafeEqual(digest(left), digest(right));
}

export type AdminPrincipal = {
  id: string;
  role: AdminRole;
  permissions: readonly AdminPermission[];
};

function configuredPrincipals(): Array<{id:string;role:AdminRole;token:string}> {
  const result: Array<{id:string;role:AdminRole;token:string}> = [];
  const superToken = (process.env.ADMIN_TOKEN ?? '').trim();
  if (superToken.length >= 24) result.push({id:'env:super-admin',role:'super_admin',token:superToken});
  const raw = (process.env.ADMIN_PRINCIPALS_JSON ?? '').trim();
  if (!raw) return result;
  const parsed = z.array(z.strictObject({
    id:z.string().trim().min(2).max(80),
    role:z.enum(['super_admin','operator','support','developer','finance']),
    token:z.string().min(24).max(512),
  })).max(50).parse(JSON.parse(raw));
  for (const item of parsed) result.push(item);
  return result;
}

export function requireAdminPrincipal(
  header: string | string[] | undefined,
  permission?: AdminPermission,
): AdminPrincipal {
  const supplied = ((Array.isArray(header) ? header[0] : header) ?? '').trim();
  check(supplied, '管理令牌无效', 401);
  const matched = configuredPrincipals().find((item) => equalSecret(item.token, supplied));
  check(matched, '管理令牌无效', 401);
  const permissions = rolePermissions[matched!.role];
  if (permission) check(permissions.includes(permission), '没有执行该操作的权限', 403);
  return {id:matched!.id,role:matched!.role,permissions};
}

export function ensureCommercialAdminSchema(store: Store) {
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS admin_audit_v2(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      admin_id TEXT NOT NULL,
      admin_role TEXT NOT NULL,
      permission TEXT,
      action TEXT NOT NULL,
      target_type TEXT,
      target_id TEXT,
      reason TEXT,
      details_json TEXT NOT NULL DEFAULT '{}',
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_admin_audit_v2_time ON admin_audit_v2(created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_admin_audit_v2_target ON admin_audit_v2(target_type,target_id,created_at DESC);
  `);
}

export function auditAdmin(
  store: Store,
  principal: AdminPrincipal,
  action: string,
  options: {permission?:AdminPermission;targetType?:string;targetId?:string;reason?:string;details?:Record<string,unknown>} = {},
) {
  ensureCommercialAdminSchema(store);
  store.db.prepare(
    'INSERT INTO admin_audit_v2(admin_id,admin_role,permission,action,target_type,target_id,reason,details_json,created_at) VALUES(?,?,?,?,?,?,?,?,?)',
  ).run(
    principal.id,principal.role,options.permission??null,action,options.targetType??null,
    options.targetId??null,options.reason??null,JSON.stringify(options.details??{}),store.now(),
  );
}

export function registerCommercialAdminRoutes(app: FastifyInstance, store: Store) {
  ensureCommercialAdminSchema(store);

  app.get('/api/v1/admin/me', async (request) => {
    const principal = requireAdminPrincipal(request.headers['x-admin-token']);
    return {id:principal.id,role:principal.role,permissions:principal.permissions};
  });

  app.get('/api/v1/admin/audit', async (request) => {
    const principal = requireAdminPrincipal(request.headers['x-admin-token'],'audit.read');
    const query = z.object({limit:z.coerce.number().int().min(1).max(500).default(100)}).parse(request.query);
    auditAdmin(store,principal,'audit_list',{permission:'audit.read'});
    return {items:store.db.prepare(
      'SELECT id,admin_id AS adminId,admin_role AS adminRole,permission,action,target_type AS targetType,target_id AS targetId,reason,details_json AS detailsJson,created_at AS createdAt FROM admin_audit_v2 ORDER BY created_at DESC LIMIT ?',
    ).all(query.limit)};
  });
}
