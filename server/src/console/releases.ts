import { createHash, randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from '../store.js';
import { requireCondition as check } from '../contract.js';
import { authorize, auditAction } from './auth.js';
import { pageQuery,paginate } from './query.js';

export const semver=z.string().regex(/^\d{1,5}\.\d{1,5}\.\d{1,5}$/);
export function compareVersions(left:string,right:string) {
  const a=left.split('.').map(Number),b=right.split('.').map(Number);
  for(let i=0;i<3;i++) if(a[i]!==b[i]) return (a[i]??0)<(b[i]??0)?-1:1;
  return 0;
}
export function inRollout(key:string,installationId:string|undefined,percent:number) {
  if(percent===100) return true;
  if(!installationId || percent===0) return false;
  return createHash('sha256').update(`${key}:${installationId}`).digest().readUInt32BE(0)%100<percent;
}
export const httpsUrl=z.url().max(2000).refine(v=>new URL(v).protocol==='https:' && !new URL(v).username && !new URL(v).password,'地址必须使用 HTTPS 且不能含凭据');
const releaseSchema=z.strictObject({platform:z.enum(['android','ios']),versionName:semver,versionCode:z.number().int().positive().max(2147483647),minimumVersion:semver,downloadUrl:httpsUrl,changelog:z.string().trim().min(1).max(6000),rollout:z.number().int().min(0).max(100).default(100)}).refine(v=>compareVersions(v.minimumVersion,v.versionName)<=0,'最低版本不能高于当前版本');
export type ReleaseRow={id:string;platform:string;version_name:string;version_code:number;minimum_version:string;download_url:string;changelog:string;rollout:number;status:string};
export function publishedRelease(store:Store,platform:string,installationId?:string) {
  const rows=store.db.prepare("SELECT * FROM console_releases WHERE platform=? AND status='published' ORDER BY version_code DESC LIMIT 100").all(platform) as ReleaseRow[];
  return rows.find(r=>inRollout(`${platform}:${r.id}`,installationId,r.rollout));
}
export function registerReleases(app:FastifyInstance,store:Store) {
  app.get('/releases',async request => {
    authorize(store,request,'app:version:view');
    const input=pageQuery.extend({platform:z.enum(['android','ios']).optional(),status:z.enum(['draft','published','offline']).optional()}).parse(request.query);
    const filters:string[]=[],args:unknown[]=[];
    if(input.platform) {filters.push('platform=?');args.push(input.platform);}
    if(input.status) {filters.push('status=?');args.push(input.status);}
    if(input.q) {filters.push('version_name LIKE ?');args.push(`%${input.q}%`);}
    return paginate(store,input,'SELECT id,platform,version_name AS versionName,version_code AS versionCode,minimum_version AS minimumVersion,download_url AS downloadUrl,changelog,rollout,status,created_at AS createdAt,published_at AS publishedAt',`FROM console_releases ${filters.length?'WHERE '+filters.join(' AND '):''}`,args,'version_code DESC');
  });
  app.post('/releases',async request => {
    const admin=authorize(store,request,'app:version:edit');const v=releaseSchema.parse(request.body);const id=randomUUID();
    check(!store.db.prepare('SELECT 1 FROM console_releases WHERE platform=? AND version_code=?').get(v.platform,v.versionCode),'该平台 versionCode 已存在',409);
    store.db.transaction(()=>{
      store.db.prepare('INSERT INTO console_releases(id,platform,version_name,version_code,minimum_version,download_url,changelog,rollout,created_at,updated_by) VALUES(?,?,?,?,?,?,?,?,?,?)').run(id,v.platform,v.versionName,v.versionCode,v.minimumVersion,v.downloadUrl,v.changelog,v.rollout,store.now(),admin.id);
      auditAction(store,admin,'release:create',id);
    })();return {id};
  });
  app.patch('/releases/:id/state',async request => {
    const admin=authorize(store,request,'app:version:publish');
    const {id}=z.object({id:z.string().max(100)}).parse(request.params);
    const {status,rollout}=z.strictObject({status:z.enum(['published','offline']),rollout:z.number().int().min(0).max(100).optional()}).parse(request.body);
    const row=store.db.prepare('SELECT * FROM console_releases WHERE id=?').get(id) as ReleaseRow|undefined;check(row,'版本不存在',404);
    const previous=store.db.prepare("SELECT * FROM console_releases WHERE platform=? AND status='published' AND rollout=100 ORDER BY version_code DESC LIMIT 1").get(row.platform) as ReleaseRow|undefined;
    const percentage=rollout??row.rollout;
    if(status==='published' && previous && previous.id!==id) {
      check(row.version_code>previous.version_code && compareVersions(row.version_name,previous.version_name)>=0,'发布版本必须高于当前全量版本；回滚请先下线新版本',409);
      check(percentage===100 || compareVersions(row.minimum_version,previous.minimum_version)<=0,'灰度发布不能提高全局最低版本',400);
    }
    store.db.transaction(()=>{
      store.db.prepare('UPDATE console_releases SET status=?,rollout=?,published_at=CASE WHEN ?=\'published\' THEN ? ELSE published_at END,updated_by=? WHERE id=?').run(status,percentage,status,store.now(),admin.id,id);
      auditAction(store,admin,`release:${status}:${percentage}`,id);
    })();return {ok:true};
  });
}
