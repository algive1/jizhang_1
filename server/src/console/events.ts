import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Store } from '../store.js';
import { requireCondition as check } from '../contract.js';
import { authorize } from './auth.js';
import { pageQuery,paginate } from './query.js';
import type { Authenticate } from './index.js';

const identifier=z.string().regex(/^[a-zA-Z0-9._:-]{1,100}$/);
export const stages=['notification','page','parsed','matched','candidate','overlay','confirmed','ignored','saved','synced'] as const;
const stage=z.enum(stages),status=z.enum(['success','failed','pending']);
const reason=z.enum(['amount_parse_failed','merchant_parse_failed','page_not_matched','notification_missing','duplicate','event_match_failed','overlay_failed','user_ignored','database_write_failed','sync_failed','permission_missing','timeout','unknown']);
const safeLabel=z.string().max(80).regex(/^[a-zA-Z0-9 ._+/-]*$/).refine(v=>!/[0-9]{7,}/.test(v),'设备标签不可包含长数字');
const event=z.strictObject({eventId:identifier,traceId:identifier,occurredAt:z.number().int().positive(),stage,status,packageName:z.string().max(160).regex(/^[a-zA-Z]\w*(?:\.\w+)+$/),appVersion:z.string().regex(/^\d{1,5}\.\d{1,5}\.\d{1,5}$/),ruleVersion:z.number().int().nonnegative().optional(),brand:safeLabel.optional(),androidVersion:safeLabel.optional(),reason:reason.optional(),metadata:z.strictObject({structureHash:z.string().regex(/^[a-f0-9]{64}$/).optional(),nodeTypes:z.array(z.enum(['text','button','image','container','input','other'])).max(20).optional(),ruleMatched:z.boolean().optional(),amountInCents:z.number().int().nonnegative().max(100000000000).optional(),confidence:z.number().min(0).max(1).optional(),durationMs:z.number().int().min(0).max(86400000).optional(),relatedEventIds:z.array(identifier).max(10).optional()}).default({})});
const select='SELECT user_id AS userId,event_id AS eventId,trace_id AS traceId,occurred_at AS occurredAt,stage,status,package_name AS packageName,app_version AS appVersion,rule_version AS ruleVersion,brand,android_version AS androidVersion,reason,metadata_json AS metadataJson';
type EventRow={userId:string;eventId:string;traceId:string;occurredAt:number;stage:string;status:string;metadataJson:string};
export function registerEventManagement(app:FastifyInstance,store:Store) {
  app.get('/events',async request=>{
    authorize(store,request,'auto-accounting:event:list');
    const input=pageQuery.extend({stage:stage.optional(),status:status.optional(),packageName:z.string().max(160).optional(),appVersion:z.string().max(40).optional(),brand:safeLabel.optional(),androidVersion:safeLabel.optional(),ruleVersion:z.coerce.number().int().nonnegative().optional(),reason:reason.optional(),from:z.coerce.number().int().nonnegative().optional(),until:z.coerce.number().int().nonnegative().optional()}).parse(request.query);
    const filters:string[]=[],args:unknown[]=[];
    for(const [field,column] of Object.entries({stage:'stage',status:'status',packageName:'package_name',appVersion:'app_version',brand:'brand',androidVersion:'android_version',ruleVersion:'rule_version',reason:'reason'})) {
      const value=input[field as keyof typeof input];if(value!==undefined){filters.push(`${column}=?`);args.push(value);}
    }
    if(input.q){filters.push('(trace_id=? OR event_id=? OR user_id=?)');args.push(input.q,input.q,input.q);}
    if(input.from!==undefined){filters.push('occurred_at>=?');args.push(input.from);}
    if(input.until!==undefined){filters.push('occurred_at<=?');args.push(input.until);}
    return paginate(store,input,select,`FROM console_events ${filters.length?'WHERE '+filters.join(' AND '):''}`,args,'occurred_at DESC,event_id ASC');
  });
  app.get('/events/trace/:userId/:traceId',async request=>{
    authorize(store,request,'auto-accounting:event:detail');
    const {userId,traceId}=z.object({userId:identifier,traceId:identifier}).parse(request.params);
    const rows=store.db.prepare(`${select} FROM console_events WHERE user_id=? AND trace_id=? ORDER BY occurred_at,event_id LIMIT 201`).all(userId,traceId) as EventRow[];
    check(rows.length,'事件链不存在',404);check(rows.length<=200,'事件链超过展示上限',413);
    return {events:rows,observedStages:[...new Set(rows.map(row=>row.stage))],integration:'未上报的阶段仅表示未观测到，不证明对应操作失败。服务端不重新合并本地支付。'};
  });
  app.get('/auto-accounting/summary',async request=>{
    authorize(store,request,'auto-accounting:event:list');
    return {stages:store.db.prepare('SELECT stage,status,COUNT(*) AS count FROM console_events GROUP BY stage,status').all(),failures:store.db.prepare("SELECT reason,COUNT(*) AS count FROM console_events WHERE status='failed' GROUP BY reason ORDER BY count DESC").all()};
  });
}
export function registerEventIngestion(app:FastifyInstance,store:Store,authenticate:Authenticate) {
  app.post('/api/v1/auto-accounting/events',{bodyLimit:128*1024,config:{rateLimit:{max:30,timeWindow:'1 minute'}}},async request=>{
    const user=authenticate(request.headers.authorization);
    const body=z.strictObject({diagnosticConsent:z.literal(true),events:z.array(event).min(1).max(100)}).parse(request.body);
    const now=store.now()*1000;
    for(const e of body.events)check(e.occurredAt>=now-30*86400000 && e.occurredAt<=now+300000,'事件时间超出允许范围',400);
    return store.db.transaction(()=>{
      const write=store.db.prepare('INSERT INTO console_events VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(user_id,event_id) DO NOTHING');
      let accepted=0;
      for(const e of body.events) {
        const old=store.db.prepare('SELECT trace_id FROM console_events WHERE user_id=? AND event_id=?').get(user.id,e.eventId) as {trace_id:string}|undefined;
        check(!old || old.trace_id===e.traceId,'相同事件 ID 不能归入不同事件链',409);
        if(!old) {const count=(store.db.prepare('SELECT COUNT(*) AS n FROM console_events WHERE user_id=? AND trace_id=?').get(user.id,e.traceId) as {n:number}).n;check(count<200,'单条事件链最多 200 个事件',413);}
        accepted+=write.run(user.id,e.eventId,e.traceId,e.occurredAt,e.stage,e.status,e.packageName,e.appVersion,e.ruleVersion??null,e.brand??null,e.androidVersion??null,e.reason??null,JSON.stringify(e.metadata),store.now()).changes;
      }
      // Validate links after the entire batch has been inserted, preserving arbitrary batch order.
      for(const e of body.events)for(const relatedId of e.metadata.relatedEventIds??[]) {
        const related=store.db.prepare('SELECT trace_id FROM console_events WHERE user_id=? AND event_id=?').get(user.id,relatedId) as {trace_id:string}|undefined;
        check(related?.trace_id===e.traceId,'合并引用必须属于同一用户与事件链',400);
      }
      return {accepted,duplicates:body.events.length-accepted};
    })();
  });
}
