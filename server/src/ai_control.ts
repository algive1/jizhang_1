import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Store } from './store.js';
import { auditAdmin, requireAdminPrincipal } from './admin_auth.js';
import { requireCondition as check } from './contract.js';

const provider=z.strictObject({
  id:z.string().regex(/^[a-z0-9_.-]{2,80}$/),
  kind:z.enum(['llm','asr','ocr','tts','embedding','reranker']),
  baseUrl:z.string().url().nullable().default(null),
  model:z.string().trim().min(1).max(200),
  secretEnv:z.string().regex(/^[A-Z][A-Z0-9_]{2,100}$/).nullable().default(null),
  timeoutMs:z.number().int().min(500).max(120000).default(30000),
  enabled:z.boolean().default(true),
  priority:z.number().int().min(0).max(1000).default(100),
  config:z.record(z.string(),z.union([z.string(),z.number(),z.boolean(),z.null()])).default({}),
});
const route=z.strictObject({
  feature:z.string().regex(/^[a-z0-9_.-]{2,80}$/),
  providerIds:z.array(z.string().regex(/^[a-z0-9_.-]{2,80}$/)).min(1).max(10),
  memberOnly:z.boolean().default(false),
  monthlyFreeQuota:z.number().int().nonnegative().max(1000000).default(0),
  monthlyMemberQuota:z.number().int().nonnegative().max(10000000).default(0),
});

export function ensureAiControlSchema(store:Store){
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS ai_providers(
      id TEXT PRIMARY KEY,kind TEXT NOT NULL,base_url TEXT,model TEXT NOT NULL,secret_env TEXT,
      timeout_ms INTEGER NOT NULL,enabled INTEGER NOT NULL,priority INTEGER NOT NULL,config_json TEXT NOT NULL,updated_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_ai_providers_route ON ai_providers(kind,enabled,priority,id);
    CREATE TABLE IF NOT EXISTS ai_routes(
      feature TEXT PRIMARY KEY,provider_ids_json TEXT NOT NULL,member_only INTEGER NOT NULL,
      monthly_free_quota INTEGER NOT NULL,monthly_member_quota INTEGER NOT NULL,updated_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS prompt_versions(
      key TEXT NOT NULL,version INTEGER NOT NULL,body TEXT NOT NULL,active INTEGER NOT NULL DEFAULT 0,created_at INTEGER NOT NULL,
      PRIMARY KEY(key,version)
    );
    CREATE INDEX IF NOT EXISTS idx_prompt_versions_active ON prompt_versions(key,active);
  `);
}

export function registerAiControlRoutes(app:FastifyInstance,store:Store){
  ensureAiControlSchema(store);

  app.get('/api/v1/admin/ai/providers',async request=>{
    requireAdminPrincipal(request.headers['x-admin-token'],'ai.read');
    const rows=store.db.prepare('SELECT id,kind,base_url AS baseUrl,model,secret_env AS secretEnv,timeout_ms AS timeoutMs,enabled,priority,config_json AS configJson,updated_at AS updatedAt FROM ai_providers ORDER BY kind,priority,id').all() as any[];
    return {providers:rows.map(r=>({...r,enabled:Boolean(r.enabled),config:JSON.parse(r.configJson),configJson:undefined,secretConfigured:r.secretEnv?Boolean(process.env[r.secretEnv]):false}))};
  });

  app.put('/api/v1/admin/ai/providers/:id',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'ai.write');
    const {id}=z.object({id:z.string()}).parse(request.params);
    const body=provider.parse({...request.body,id});
    store.db.prepare(`INSERT INTO ai_providers(id,kind,base_url,model,secret_env,timeout_ms,enabled,priority,config_json,updated_at)
      VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET kind=excluded.kind,base_url=excluded.base_url,model=excluded.model,secret_env=excluded.secret_env,timeout_ms=excluded.timeout_ms,enabled=excluded.enabled,priority=excluded.priority,config_json=excluded.config_json,updated_at=excluded.updated_at`)
      .run(body.id,body.kind,body.baseUrl,body.model,body.secretEnv,body.timeoutMs,Number(body.enabled),body.priority,JSON.stringify(body.config),store.now());
    auditAdmin(store,principal,'ai_provider_upsert',{permission:'ai.write',targetType:'ai_provider',targetId:id,details:{kind:body.kind,model:body.model,secretEnv:body.secretEnv}});
    return {...body,secretConfigured:body.secretEnv?Boolean(process.env[body.secretEnv]):false};
  });

  app.put('/api/v1/admin/ai/routes/:feature',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'ai.write');
    const {feature}=z.object({feature:z.string()}).parse(request.params);
    const body=route.parse({...request.body,feature});
    const providerRows=store.db.prepare(`SELECT id FROM ai_providers WHERE id IN (${body.providerIds.map(()=>'?').join(',')}) AND enabled=1`).all(...body.providerIds) as Array<{id:string}>;
    check(providerRows.length===body.providerIds.length,'路由包含不存在或未启用的 Provider',400);
    store.db.prepare(`INSERT INTO ai_routes(feature,provider_ids_json,member_only,monthly_free_quota,monthly_member_quota,updated_at)
      VALUES(?,?,?,?,?,?) ON CONFLICT(feature) DO UPDATE SET provider_ids_json=excluded.provider_ids_json,member_only=excluded.member_only,monthly_free_quota=excluded.monthly_free_quota,monthly_member_quota=excluded.monthly_member_quota,updated_at=excluded.updated_at`)
      .run(feature,JSON.stringify(body.providerIds),Number(body.memberOnly),body.monthlyFreeQuota,body.monthlyMemberQuota,store.now());
    auditAdmin(store,principal,'ai_route_upsert',{permission:'ai.write',targetType:'ai_route',targetId:feature,details:{providers:body.providerIds}});
    return body;
  });

  app.put('/api/v1/admin/ai/prompts/:key/:version',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'ai.write');
    const p=z.object({key:z.string().regex(/^[a-z0-9_.-]{2,80}$/),version:z.coerce.number().int().positive()}).parse(request.params);
    const {body}=z.strictObject({body:z.string().min(10).max(30000)}).parse(request.body);
    store.db.prepare('INSERT INTO prompt_versions(key,version,body,active,created_at) VALUES(?,?,?,0,?) ON CONFLICT(key,version) DO UPDATE SET body=excluded.body').run(p.key,p.version,body,store.now());
    auditAdmin(store,principal,'prompt_upsert',{permission:'ai.write',targetType:'prompt',targetId:`${p.key}:v${p.version}`});
    return {key:p.key,version:p.version};
  });

  app.post('/api/v1/admin/ai/prompts/:key/:version/activate',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'ai.write');
    const p=z.object({key:z.string(),version:z.coerce.number().int().positive()}).parse(request.params);
    check(store.db.prepare('SELECT 1 FROM prompt_versions WHERE key=? AND version=?').get(p.key,p.version),'Prompt 版本不存在',404);
    store.db.transaction(()=>{store.db.prepare('UPDATE prompt_versions SET active=0 WHERE key=?').run(p.key);store.db.prepare('UPDATE prompt_versions SET active=1 WHERE key=? AND version=?').run(p.key,p.version)})();
    auditAdmin(store,principal,'prompt_activate',{permission:'ai.write',targetType:'prompt',targetId:`${p.key}:v${p.version}`});
    return {ok:true};
  });
}
