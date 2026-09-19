import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { requireCondition as check } from './contract.js';
import type { Store } from './store.js';
import { auditAdmin, requireAdminPrincipal } from './admin_auth.js';

const platform = z.enum(['android','ios']);
const semver = z.string().regex(/^\d+\.\d+\.\d+$/);
const releaseSchema = z.strictObject({
  platform,
  latestVersion:semver,
  minimumVersion:semver,
  storeUrl:z.string().url().refine(v=>v.startsWith('https://'),'必须使用 HTTPS'),
  message:z.string().trim().min(1).max(1000),
  rolloutPercent:z.number().int().min(0).max(100).default(100),
  enabled:z.boolean().default(true),
});

function compare(left:string,right:string) {
  const a=left.split('.').map(Number), b=right.split('.').map(Number);
  for(let i=0;i<3;i++) if((a[i]??0)!==(b[i]??0)) return (a[i]??0)<(b[i]??0)?-1:1;
  return 0;
}

export function ensureReleaseSchema(store:Store) {
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS app_release_config(
      platform TEXT PRIMARY KEY,
      latest_version TEXT NOT NULL,
      minimum_version TEXT NOT NULL,
      store_url TEXT NOT NULL,
      message TEXT NOT NULL,
      rollout_percent INTEGER NOT NULL DEFAULT 100,
      enabled INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS feature_flags(
      key TEXT PRIMARY KEY,
      enabled INTEGER NOT NULL,
      rollout_percent INTEGER NOT NULL DEFAULT 100,
      min_version TEXT,
      platforms_json TEXT NOT NULL DEFAULT '["android","ios"]',
      config_json TEXT NOT NULL DEFAULT '{}',
      updated_at INTEGER NOT NULL
    );
  `);
}

export function registerReleaseControlRoutes(app:FastifyInstance,store:Store) {
  ensureReleaseSchema(store);

  app.get('/api/v1/app/release-config',async request=>{
    const q=z.strictObject({platform,version:semver,installationId:z.string().min(8).max(128).optional()}).parse(request.query);
    const row=store.db.prepare('SELECT * FROM app_release_config WHERE platform=?').get(q.platform) as any;
    if(!row || !row.enabled) return {status:'none',configured:false};
    const required=compare(q.version,row.minimum_version)<0;
    const optional=compare(q.version,row.latest_version)<0;
    return {configured:true,status:required?'required':optional?'optional':'none',latestVersion:row.latest_version,minimumVersion:row.minimum_version,storeUrl:row.store_url,message:optional?row.message:null};
  });

  app.get('/api/v1/app/features',async request=>{
    const q=z.strictObject({platform,version:semver,installationId:z.string().min(8).max(128)}).parse(request.query);
    const rows=store.db.prepare('SELECT * FROM feature_flags').all() as any[];
    const bucket=(key:string)=>{let h=2166136261;for(const c of q.installationId+':'+key){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return (h>>>0)%100};
    const flags:Record<string,unknown>={};
    for(const row of rows){
      const platforms=JSON.parse(row.platforms_json) as string[];
      const eligible=Boolean(row.enabled)&&platforms.includes(q.platform)&&(!row.min_version||compare(q.version,row.min_version)>=0)&&bucket(row.key)<row.rollout_percent;
      flags[row.key]={enabled:eligible,config:eligible?JSON.parse(row.config_json):{}};
    }
    return {flags};
  });

  app.put('/api/v1/admin/releases/:platform',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'releases.write');
    const p=z.object({platform}).parse(request.params);
    const body=releaseSchema.parse({...request.body,platform:p.platform});
    check(compare(body.minimumVersion,body.latestVersion)<=0,'最低支持版本不能高于最新版本',400);
    store.db.prepare(`INSERT INTO app_release_config(platform,latest_version,minimum_version,store_url,message,rollout_percent,enabled,updated_at)
      VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(platform) DO UPDATE SET latest_version=excluded.latest_version,minimum_version=excluded.minimum_version,store_url=excluded.store_url,message=excluded.message,rollout_percent=excluded.rollout_percent,enabled=excluded.enabled,updated_at=excluded.updated_at`)
      .run(body.platform,body.latestVersion,body.minimumVersion,body.storeUrl,body.message,body.rolloutPercent,Number(body.enabled),store.now());
    auditAdmin(store,principal,'release_update',{permission:'releases.write',targetType:'platform',targetId:p.platform,details:{latestVersion:body.latestVersion,minimumVersion:body.minimumVersion,rolloutPercent:body.rolloutPercent}});
    return body;
  });

  app.put('/api/v1/admin/features/:key',async request=>{
    const principal=requireAdminPrincipal(request.headers['x-admin-token'],'releases.write');
    const {key}=z.object({key:z.string().regex(/^[a-z0-9_.-]{2,80}$/)}).parse(request.params);
    const body=z.strictObject({
      enabled:z.boolean(),rolloutPercent:z.number().int().min(0).max(100).default(100),
      minVersion:semver.nullable().optional(),platforms:z.array(platform).min(1).max(2),
      config:z.record(z.string(),z.union([z.string(),z.number(),z.boolean(),z.null()])).default({}),
    }).parse(request.body);
    store.db.prepare(`INSERT INTO feature_flags(key,enabled,rollout_percent,min_version,platforms_json,config_json,updated_at)
      VALUES(?,?,?,?,?,?,?) ON CONFLICT(key) DO UPDATE SET enabled=excluded.enabled,rollout_percent=excluded.rollout_percent,min_version=excluded.min_version,platforms_json=excluded.platforms_json,config_json=excluded.config_json,updated_at=excluded.updated_at`)
      .run(key,Number(body.enabled),body.rolloutPercent,body.minVersion??null,JSON.stringify(body.platforms),JSON.stringify(body.config),store.now());
    auditAdmin(store,principal,'feature_flag_update',{permission:'releases.write',targetType:'feature_flag',targetId:key,details:{enabled:body.enabled,rolloutPercent:body.rolloutPercent}});
    return {key,...body};
  });
}
