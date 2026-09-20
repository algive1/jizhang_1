import type { FastifyInstance } from 'fastify';
import type { Store } from './store.js';
import { quotaSnapshot } from './entitlement_usage.js';
export function registerEntitlementUsageRoutes(app:FastifyInstance,store:Store,authenticate:(header:string|undefined)=>{id:string}){
  app.get('/api/v1/membership/entitlements',async request=>{const user=authenticate(request.headers.authorization);return {entitlements:quotaSnapshot(store,user.id)}});
}
