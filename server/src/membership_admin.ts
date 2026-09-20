import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from './store.js';
import { requireAdminPrincipal,auditAdmin } from './admin_auth.js';
import { ensureQuotaSchema, quotaSnapshot } from './entitlement_usage.js';
import { membershipState } from './membership_state.js';

export function registerMembershipAdminRoutes(app:FastifyInstance,store:Store){
  ensureQuotaSchema(store);
  app.get('/api/v1/admin/users/:userId/membership',async req=>{
    const principal=requireAdminPrincipal(req.headers['x-admin-token'],'membership.read');
    const {userId}=z.object({userId:z.string().min(1).max(100)}).parse(req.params);
    const state=membershipState(store,userId),usage=quotaSnapshot(store,userId);
    auditAdmin(store,principal,'membership_user_read',{permission:'membership.read',targetType:'user',targetId:userId});
    return {state,usage};
  });
  app.get('/api/v1/admin/membership/usage',async req=>{
    requireAdminPrincipal(req.headers['x-admin-token'],'membership.read');
    const {period}=z.object({period:z.string().regex(/^\d{4}-\d{2}$/).optional()}).parse(req.query);
    const p=period??new Date(store.now()*1000).toISOString().slice(0,7);
    return {period:p,items:store.db.prepare('SELECT entitlement_key AS entitlementKey,COUNT(DISTINCT user_id) users,SUM(used) used FROM entitlement_usage WHERE period=? GROUP BY entitlement_key ORDER BY used DESC').all(p)};
  });
}
