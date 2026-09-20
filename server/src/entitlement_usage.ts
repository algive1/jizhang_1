import type { Store } from './store.js';
import { ApiError } from './contract.js';
import { membershipState } from './membership_state.js';

export function ensureQuotaSchema(store:Store){
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS entitlement_usage(
      user_id TEXT NOT NULL,entitlement_key TEXT NOT NULL,period TEXT NOT NULL,used INTEGER NOT NULL DEFAULT 0,updated_at INTEGER NOT NULL,
      PRIMARY KEY(user_id,entitlement_key,period)
    );
    CREATE INDEX IF NOT EXISTS idx_entitlement_usage_period ON entitlement_usage(period,entitlement_key);
  `);
}
function period(now:number){return new Date(now*1000).toISOString().slice(0,7)}
export function entitlementValue(store:Store,userId:string,key:string):unknown{
  const state=membershipState(store,userId);return (state.entitlements.find(e=>e.key===key) as any)?.value;
}
export function consumeEntitlement(store:Store,userId:string,key:string,amount=1){
  ensureQuotaSchema(store);const now=store.now(),p=period(now);
  return store.db.transaction(()=>{
    const value=entitlementValue(store,userId,key);
    if(value===true)return {allowed:true,unlimited:true,used:0,remaining:null};
    if(typeof value!=='number'||value<=0)throw new ApiError(403,'当前会员权益不包含此功能');
    const row=store.db.prepare('SELECT used FROM entitlement_usage WHERE user_id=? AND entitlement_key=? AND period=?').get(userId,key,p) as {used:number}|undefined;
    const used=row?.used??0;if(used+amount>value)throw new ApiError(429,'本周期权益额度已用完');
    store.db.prepare('INSERT INTO entitlement_usage(user_id,entitlement_key,period,used,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(user_id,entitlement_key,period) DO UPDATE SET used=used+excluded.used,updated_at=excluded.updated_at').run(userId,key,p,amount,now);
    return {allowed:true,unlimited:false,used:used+amount,remaining:value-used-amount,limit:value,period:p};
  })();
}
export function quotaSnapshot(store:Store,userId:string){
  ensureQuotaSchema(store);const p=period(store.now());const ent=membershipState(store,userId).entitlements;
  const usage=store.db.prepare('SELECT entitlement_key AS key,used FROM entitlement_usage WHERE user_id=? AND period=?').all(userId,p) as Array<{key:string;used:number}>;
  const map=new Map(usage.map(x=>[x.key,x.used]));return ent.map((e:any)=>({key:e.key,value:e.value,used:map.get(e.key)??0,remaining:typeof e.value==='number'?Math.max(0,e.value-(map.get(e.key)??0)):null}));
}
