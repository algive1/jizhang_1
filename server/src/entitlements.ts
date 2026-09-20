import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Store } from './store.js';
import { requireCondition as check } from './contract.js';
import { auditAdmin, requireAdminPrincipal } from './admin_auth.js';

const entitlementType=z.enum(['boolean','count','quota','storage','rate_limit','enum']);
const entitlement=z.strictObject({
  key:z.string().regex(/^[a-z0-9_.-]{2,80}$/),
  title:z.string().trim().min(1).max(100),
  type:entitlementType,
  value:z.union([z.boolean(),z.number().nonnegative(),z.string().max(100)]),
});
const tier=z.strictObject({
  id:z.string().regex(/^[a-z0-9_.-]{2,60}$/),
  title:z.string().trim().min(1).max(100),
  version:z.number().int().positive(),
  entitlements:z.array(entitlement).max(100).refine(v=>new Set(v.map(x=>x.key)).size===v.length,'权益键不能重复'),
});
const product=z.strictObject({
  id:z.string().regex(/^[a-z0-9_.-]{2,80}$/),
  title:z.string().trim().min(1).max(100),
  tierId:z.string().regex(/^[a-z0-9_.-]{2,60}$/),
  durationDays:z.number().int().positive().max(3660),
  enabled:z.boolean(),
  recommended:z.boolean().default(false),
  displayPrice:z.string().trim().max(40).nullable().default(null),
  appleProductId:z.string().trim().max(200).nullable().default(null),
  googleProductId:z.string().trim().max(200).nullable().default(null),
  sort:z.number().int().min(0).max(10000).default(0),
});

export function ensureEntitlementSchema(store:Store){
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS membership_tiers(
      id TEXT NOT NULL, version INTEGER NOT NULL, title TEXT NOT NULL, entitlements_json TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, PRIMARY KEY(id,version)
    );
    CREATE INDEX IF NOT EXISTS idx_membership_tiers_active ON membership_tiers(id,active);
    CREATE TABLE IF NOT EXISTS membership_products(
      id TEXT PRIMARY KEY,title TEXT NOT NULL,tier_id TEXT NOT NULL,tier_version INTEGER NOT NULL,
      duration_days INTEGER NOT NULL,enabled INTEGER NOT NULL,recommended INTEGER NOT NULL DEFAULT 0,
      display_price TEXT,apple_product_id TEXT,google_product_id TEXT,sort INTEGER NOT NULL DEFAULT 0,updated_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_membership_products_enabled ON membership_products(enabled,sort,id);
    CREATE TABLE IF NOT EXISTS user_entitlement_grants(
      id INTEGER PRIMARY KEY AUTOINCREMENT,user_id TEXT NOT NULL,entitlement_key TEXT NOT NULL,
      value_json TEXT NOT NULL,expires_at INTEGER,source TEXT NOT NULL,reason TEXT,created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_user_entitlement_grants_user ON user_entitlement_grants(user_id,expires_at);
  `);
}

export function registerEntitlementRoutes(app:FastifyInstance,store:Store){
  ensureEntitlementSchema(store);

  app.get('/api/v1/membership/products',async()=>{
    const rows=store.db.prepare('SELECT * FROM membership_products WHERE enabled=1 ORDER BY sort,id').all() as any[];
    return {products:rows.map(r=>({id:r.id,title:r.title,tierId:r.tier_id,tierVersion:r.tier_version,durationDays:r.duration_days,recommended:Boolean(r.recommended),displayPrice:r.display_price,appleProductId:r.apple_product_id,googleProductId:r.google_product_id}))};
  });

  app.put('/api/v1/admin/membership/tiers/:id/:version',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'membership.write');
    const params=z.object({id:z.string(),version:z.coerce.number().int().positive()}).parse(request.params);
    const body=tier.parse({...request.body,id:params.id,version:params.version});
    store.db.prepare('INSERT INTO membership_tiers(id,version,title,entitlements_json,active,created_at) VALUES(?,?,?,?,0,?) ON CONFLICT(id,version) DO UPDATE SET title=excluded.title,entitlements_json=excluded.entitlements_json')
      .run(body.id,body.version,body.title,JSON.stringify(body.entitlements),store.now());
    auditAdmin(store,principal,'membership_tier_upsert',{permission:'membership.write',targetType:'membership_tier',targetId:`${body.id}:v${body.version}`});
    return body;
  });

  app.post('/api/v1/admin/membership/tiers/:id/:version/activate',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'membership.write');
    const p=z.object({id:z.string().min(2).max(60),version:z.coerce.number().int().positive()}).parse(request.params);
    check(store.db.prepare('SELECT 1 FROM membership_tiers WHERE id=? AND version=?').get(p.id,p.version),'权益版本不存在',404);
    store.db.transaction(()=>{store.db.prepare('UPDATE membership_tiers SET active=0 WHERE id=?').run(p.id);store.db.prepare('UPDATE membership_tiers SET active=1 WHERE id=? AND version=?').run(p.id,p.version)})();
    auditAdmin(store,principal,'membership_tier_activate',{permission:'membership.write',targetType:'membership_tier',targetId:`${p.id}:v${p.version}`});
    return {ok:true};
  });

  app.put('/api/v1/admin/membership/products/:id',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'membership.write');
    const {id}=z.object({id:z.string()}).parse(request.params);
    const body=product.parse({...request.body,id});
    const active=store.db.prepare('SELECT version FROM membership_tiers WHERE id=? AND active=1').get(body.tierId) as {version:number}|undefined;
    check(active,'套餐对应的会员权益尚未激活',409);
    store.db.prepare(`INSERT INTO membership_products(id,title,tier_id,tier_version,duration_days,enabled,recommended,display_price,apple_product_id,google_product_id,sort,updated_at)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,tier_id=excluded.tier_id,tier_version=excluded.tier_version,duration_days=excluded.duration_days,enabled=excluded.enabled,recommended=excluded.recommended,display_price=excluded.display_price,apple_product_id=excluded.apple_product_id,google_product_id=excluded.google_product_id,sort=excluded.sort,updated_at=excluded.updated_at`)
      .run(body.id,body.title,body.tierId,active.version,body.durationDays,Number(body.enabled),Number(body.recommended),body.displayPrice,body.appleProductId,body.googleProductId,body.sort,store.now());
    auditAdmin(store,principal,'membership_product_upsert',{permission:'membership.write',targetType:'membership_product',targetId:id});
    return {...body,tierVersion:active.version};
  });

  app.post('/api/v1/admin/users/:userId/entitlement-grants',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'membership.write');
    const {userId}=z.object({userId:z.string().min(1).max(100)}).parse(request.params);
    check(store.db.prepare('SELECT 1 FROM users WHERE id=?').get(userId),'用户不存在',404);
    const body=z.strictObject({key:z.string().regex(/^[a-z0-9_.-]{2,80}$/),value:z.union([z.boolean(),z.number().nonnegative(),z.string().max(100)]),expiresAt:z.number().int().positive().nullable().default(null),reason:z.string().trim().min(3).max(500)}).parse(request.body);
    const result=store.db.prepare('INSERT INTO user_entitlement_grants(user_id,entitlement_key,value_json,expires_at,source,reason,created_at) VALUES(?,?,?,?,?,?,?)')
      .run(userId,body.key,JSON.stringify(body.value),body.expiresAt,'admin',body.reason,store.now());
    auditAdmin(store,principal,'entitlement_grant',{permission:'membership.write',targetType:'user',targetId:userId,reason:body.reason,details:{key:body.key,grantId:Number(result.lastInsertRowid)}});
    return {ok:true,id:Number(result.lastInsertRowid)};
  });
}


export function activeMembershipProduct(store:Store,id:string){
  ensureEntitlementSchema(store);
  return store.db.prepare('SELECT id,title,tier_id AS tierId,tier_version AS tierVersion,duration_days AS durationDays,display_price AS displayPrice,apple_product_id AS appleProductId,google_product_id AS googleProductId FROM membership_products WHERE id=? AND enabled=1').get(id) as any;
}
export function productByAppleId(store:Store,appleProductId:string){
  ensureEntitlementSchema(store);
  return store.db.prepare('SELECT id,title,tier_id AS tierId,tier_version AS tierVersion,duration_days AS durationDays,apple_product_id AS appleProductId FROM membership_products WHERE apple_product_id=? AND enabled=1').get(appleProductId) as any;
}
export function resolvedEntitlements(store:Store,userId:string,productId:string|null){
  ensureEntitlementSchema(store);const now=store.now();const result=new Map<string,unknown>();
  if(productId){
    const p=store.db.prepare('SELECT tier_id,tier_version FROM membership_products WHERE id=?').get(productId) as {tier_id:string;tier_version:number}|undefined;
    if(p){const t=store.db.prepare('SELECT entitlements_json FROM membership_tiers WHERE id=? AND version=?').get(p.tier_id,p.tier_version) as {entitlements_json:string}|undefined;
      if(t)for(const e of JSON.parse(t.entitlements_json) as Array<{key:string;value:unknown}>)result.set(e.key,e.value);
    }
  }
  const grants=store.db.prepare('SELECT entitlement_key,value_json FROM user_entitlement_grants WHERE user_id=? AND (expires_at IS NULL OR expires_at>?) ORDER BY created_at').all(userId,now) as Array<{entitlement_key:string;value_json:string}>;
  for(const g of grants)result.set(g.entitlement_key,JSON.parse(g.value_json));
  return Array.from(result,([key,value])=>({key,value}));
}
