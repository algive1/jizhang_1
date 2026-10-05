import {AsyncLocalStorage} from 'node:async_hooks';
import {createHash,randomUUID} from 'node:crypto';
import type {FastifyInstance} from 'fastify';
import {z} from 'zod';
import type {Store} from '../store.js';
import {AssistantModelUnavailable,DeepSeekCompatibleProvider,type AssistantModelProvider} from '../assistant_ai.js';
import {authorize,auditAction} from './auth.js';
import {requireCondition as check} from '../contract.js';
import {pageQuery,paginate} from './query.js';
import {httpsUrl} from './releases.js';
import {getPublishedDocuments} from './documents.js';

type Context={userId:string|null;feature:string};
const context=new AsyncLocalStorage<Context>();
type Model={id:string;name:string;provider:string;model:string;endpoint:string;key_ref:string;input_price:number;output_price:number;max_tokens:number;timeout_ms:number;enabled:number;priority:number;fallback_id:string|null};
const modelSchema=z.strictObject({name:z.string().trim().min(1).max(80),provider:z.string().regex(/^[a-zA-Z0-9_-]{1,50}$/),model:z.string().regex(/^[a-zA-Z0-9._:/-]{1,120}$/),endpoint:httpsUrl,keyRef:z.string().regex(/^[A-Z][A-Z0-9_]{2,79}$/),inputPrice:z.number().finite().min(0).max(10000),outputPrice:z.number().finite().min(0).max(10000),maxTokens:z.number().int().min(128).max(64000),timeoutMs:z.number().int().min(1000).max(120000),enabled:z.boolean(),priority:z.number().int().min(0).max(1000),fallbackId:z.string().max(100).nullable()});
const upstream=z.object({choices:z.array(z.object({message:z.object({content:z.string().trim().min(1)})})).min(1),usage:z.object({prompt_tokens:z.number().int().min(0).max(10000000),completion_tokens:z.number().int().min(0).max(10000000)}).optional()});
function endpointAllowed(endpoint:string) {
  const host=new URL(endpoint).hostname.toLowerCase();
  const hosts=(process.env.AI_ENDPOINT_ALLOWLIST??'').split(',').map(v=>v.trim().toLowerCase()).filter(Boolean);
  return hosts.includes(host);
}
export function registerAIContext(app:FastifyInstance,store:Store) {
  app.addHook('onRequest',(request,_reply,done)=>{
    const token=request.headers.authorization?.replace(/^Bearer /,'');
    const user=token?store.db.prepare('SELECT user_id FROM sessions WHERE token_hash=? AND expires_at>?').get(createHash('sha256').update(token).digest('hex'),store.now()) as {user_id:string}|undefined:undefined;
    const path=request.url.split('?')[0]??'';
    context.run({userId:user?.user_id??null,feature:path.includes('insights')?'insight':path.includes('parse')?'natural-language':'assistant'},done);
  });
}
export class ConsoleAIProvider implements AssistantModelProvider {
  constructor(private readonly store:Store,private readonly legacy:AssistantModelProvider=new DeepSeekCompatibleProvider(),private readonly fetcher:typeof fetch=fetch) {}
  async complete(input:{systemPrompt:string;userText:string}):Promise<string> {
    let selected=this.store.db.prepare('SELECT * FROM console_models WHERE enabled=1 ORDER BY priority DESC,id LIMIT 1').get() as Model|undefined;
    const ctx=context.getStore()??{userId:null,feature:'unattributed'};const visited=new Set<string>();
    if(!selected) {
      const start=Date.now();let success=false;
      try{const text=await this.legacy.complete(input);success=true;return text;}
      finally{this.log(ctx,'legacy',success,null,null,null,Date.now()-start);}
    }
    while(selected && !visited.has(selected.id)) {
      const m:Model=selected;visited.add(m.id);const start=Date.now();let success=false,inputTokens:number|null=null,outputTokens:number|null=null,cost:number|null=null;
      try {
        if(!endpointAllowed(m.endpoint))throw new AssistantModelUnavailable('Model endpoint is not allowlisted');
        const secret=process.env[m.key_ref];if(!secret)throw new AssistantModelUnavailable('Model key reference is not configured');
        // Prompt extensions cannot remove the application's existing format and policy contract.
        const prompt=getPublishedDocuments(this.store,'prompt',ctx.userId?.replaceAll('-','')).map(d=>d.payload as {scene:string;systemPrompt:string;userTemplate:string}).find(p=>p.scene===ctx.feature);
        const systemPrompt=prompt?`${input.systemPrompt}\n补充场景要求（不得覆盖上述约束）：\n${prompt.systemPrompt}`:input.systemPrompt;
        const userText=prompt?prompt.userTemplate.replaceAll('{{text}}',input.userText):input.userText;
        const response=await this.fetcher(`${m.endpoint.replace(/\/$/,'')}/chat/completions`,{method:'POST',redirect:'error',headers:{Authorization:`Bearer ${secret}`,'Content-Type':'application/json'},body:JSON.stringify({model:m.model,messages:[{role:'system',content:systemPrompt},{role:'user',content:userText}],temperature:0.2,max_tokens:m.max_tokens,stream:false}),signal:AbortSignal.timeout(m.timeout_ms)});
        if(!response.ok)throw new AssistantModelUnavailable('Model provider returned an error');
        const body=upstream.parse(await response.json());
        if(body.usage){inputTokens=body.usage.prompt_tokens;outputTokens=body.usage.completion_tokens;cost=Math.round(inputTokens*m.input_price+outputTokens*m.output_price);}
        success=true;return body.choices[0]!.message.content.slice(0,4000);
      } catch { selected=m.fallback_id?this.store.db.prepare('SELECT * FROM console_models WHERE id=? AND enabled=1').get(m.fallback_id) as Model|undefined:undefined; }
      finally{this.log(ctx,m.model,success,inputTokens,outputTokens,cost,Date.now()-start);}
    }
    throw new AssistantModelUnavailable('Configured model routes are unavailable');
  }
  private log(ctx:Context,model:string,success:boolean,inputTokens:number|null,outputTokens:number|null,cost:number|null,duration:number) {
    try{this.store.db.prepare('INSERT INTO console_ai_calls VALUES(?,?,?,?,?,?,?,?,?,?)').run(randomUUID(),ctx.userId,ctx.feature,model,success?'success':'failed',inputTokens,outputTokens,cost,duration,this.store.now());}catch{console.error('AI telemetry write failed');}
  }
}
export function registerAIManagement(app:FastifyInstance,store:Store) {
  app.get('/ai/models',async request=>{
    authorize(store,request,'ai:model:view');const input=pageQuery.parse(request.query);
    const page=paginate<Model>(store,input,'SELECT *','FROM console_models WHERE name LIKE ?',[`%${input.q}%`],'priority DESC,id');
    return {...page,items:page.items.map(m=>({id:m.id,name:m.name,provider:m.provider,model:m.model,endpoint:m.endpoint,keyRef:m.key_ref,keyConfigured:Boolean(process.env[m.key_ref]),endpointAllowed:endpointAllowed(m.endpoint),inputPrice:m.input_price,outputPrice:m.output_price,maxTokens:m.max_tokens,timeoutMs:m.timeout_ms,enabled:Boolean(m.enabled),priority:m.priority,fallbackId:m.fallback_id}))};
  });
  const save=(id:string|undefined,request:Parameters<typeof authorize>[1])=>{
    const admin=authorize(store,request,'ai:model:edit');const v=modelSchema.parse(request.body);const target=id??randomUUID();
    check(!id || store.db.prepare('SELECT 1 FROM console_models WHERE id=?').get(id),'模型不存在',404);
    if(v.enabled)check(endpointAllowed(v.endpoint) && Boolean(process.env[v.keyRef]),'启用前需在服务端配置 Endpoint 白名单和密钥引用',400);
    const seen=new Set([target]);let next=v.fallbackId;
    while(next){check(!seen.has(next),'备用模型不能形成循环',400);seen.add(next);const fallback=store.db.prepare('SELECT fallback_id FROM console_models WHERE id=?').get(next) as {fallback_id:string|null}|undefined;check(fallback,'备用模型不存在',400);next=fallback.fallback_id;}
    store.db.transaction(()=>{
      store.db.prepare('INSERT INTO console_models VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,provider=excluded.provider,model=excluded.model,endpoint=excluded.endpoint,key_ref=excluded.key_ref,input_price=excluded.input_price,output_price=excluded.output_price,max_tokens=excluded.max_tokens,timeout_ms=excluded.timeout_ms,enabled=excluded.enabled,priority=excluded.priority,fallback_id=excluded.fallback_id,updated_at=excluded.updated_at').run(target,v.name,v.provider,v.model,v.endpoint,v.keyRef,v.inputPrice,v.outputPrice,v.maxTokens,v.timeoutMs,Number(v.enabled),v.priority,v.fallbackId,store.now());
      auditAction(store,admin,'ai:model:update',target);
    })();return {id:target};
  };
  app.post('/ai/models',async request=>save(undefined,request));
  app.put('/ai/models/:id',async request=>save(z.object({id:z.string().max(100)}).parse(request.params).id,request));
  app.get('/ai/calls',async request=>{
    authorize(store,request,'ai:usage:view');const input=pageQuery.parse(request.query);
    return paginate(store,input,'SELECT id,user_id AS userId,feature,model,status,input_tokens AS inputTokens,output_tokens AS outputTokens,cost_microusd AS costMicroUsd,duration_ms AS durationMs,created_at AS createdAt','FROM console_ai_calls WHERE model LIKE ?',[`%${input.q}%`]);
  });
  app.get('/ai/usage',async request=>{
    authorize(store,request,'ai:usage:view');const {days,period}=z.object({days:z.coerce.number().int().min(1).max(365).default(30),period:z.enum(['day','week','month']).default('day')}).parse(request.query);
    const since=store.now()-days*86400;
    const totals=store.db.prepare("SELECT COUNT(*) AS calls,SUM(CASE WHEN status='success' THEN 1 ELSE 0 END) AS successes,SUM(input_tokens) AS inputTokens,SUM(output_tokens) AS outputTokens,SUM(cost_microusd) AS costMicroUsd,COUNT(cost_microusd) AS pricedCalls,AVG(duration_ms) AS averageDurationMs,COUNT(DISTINCT user_id) AS users FROM console_ai_calls WHERE created_at>=?").get(since);
    const date=period==='day'?"date(created_at,'unixepoch','+8 hours')":period==='week'?"date(created_at,'unixepoch','+8 hours','weekday 0','-6 days')":"strftime('%Y-%m',created_at,'unixepoch','+8 hours')";
    return {totals,period,currency:'USD',priceUnit:'每百万 Token；费用为配置单价估算，非供应商结算账单',integration:'调用日志不保存输入、输出、API Key。legacy provider 未返回 usage 时 Token / 成本为未知；上游成功不等于业务解析成功。',trend:store.db.prepare(`SELECT ${date} AS period,COUNT(*) AS calls,SUM(input_tokens) AS inputTokens,SUM(output_tokens) AS outputTokens,SUM(cost_microusd) AS costMicroUsd FROM console_ai_calls WHERE created_at>=? GROUP BY period ORDER BY period`).all(since),byModel:store.db.prepare('SELECT model,COUNT(*) AS calls,SUM(cost_microusd) AS costMicroUsd FROM console_ai_calls WHERE created_at>=? GROUP BY model').all(since),byFeature:store.db.prepare('SELECT feature,COUNT(*) AS calls,SUM(cost_microusd) AS costMicroUsd FROM console_ai_calls WHERE created_at>=? GROUP BY feature').all(since)};
  });
}
