import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {createApp} from '../src/app.js';
import type {Data,Kind} from '../src/contract.js';
const now=Math.floor(Date.now()/1000);
function account(book:string,id='cash'):Data {return {id,book_id:book,name:'现金',type:'cash',balance_in_cents:10000,opening_balance_in_cents:10000,currency:'CNY',asset_form:'cash',icon:'wallet',color:1,sort_order:0,is_archived:0,created_at:now,updated_at:now};}
function tx(book:string,id:string,amount=1200):Data {return {id,book_id:book,type:'expense',amount_in_cents:amount,currency:'CNY',account_id:'cash',occurred_at:now,created_at:now,updated_at:now,is_recurring:0,is_one_time:1,is_large_transaction:0,is_planned:0,source:'manual',user_corrected:0,sync_status:'pending',visibility:'shared',version:1};}
function op(kind:Kind,data:Data,expectedVersion=0) {return {operationId:randomUUID(),kind,id:String(data.id),action:'upsert' as const,expectedVersion,data};}
test('真实 HTTP 两客户端：重试、冲突、权限、隔离',async(t)=>{
 const {app}=await createApp(':memory:');const base=await app.listen({host:'127.0.0.1',port:0});t.after(()=>app.close());
 async function call(path:string,token='',body?:unknown,method=body?'POST':'GET') {const res=await fetch(base+'/api/v1'+path,{method,headers:{...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`}:{})},body:body?JSON.stringify(body):undefined});return {status:res.status,data:await res.json() as any};}
 const a=(await call('/auth/register','',{username:'owner_a',password:'local-test-password-a'})).data;
 const b=(await call('/auth/register','',{username:'member_b',password:'local-test-password-b'})).data;
 assert.equal((await call('/auth/login','',{username:'owner_a',password:'wrong-password'})).status,401);
 const book='shared-'+randomUUID();assert.equal((await call('/books',a.token,{id:book,name:'家庭',type:'family',entities:[{kind:'accounts',id:'cash',data:account(book)}]})).status,200);
 assert.deepEqual((await call('/books',b.token)).data.books,[]);assert.equal((await call(`/books/${book}/snapshot`,b.token)).status,403);
 const invite=(await call(`/books/${book}/invitations`,a.token,{})).data;
 assert.equal((await call('/invitations/accept',b.token,{code:invite.code})).status,200);assert.equal((await call('/invitations/accept',b.token,{code:invite.code})).status,409);
 const pending=op('transactions',tx(book,'offline'));
 assert.equal((await call(`/books/${book}/mutations`,b.token,{operations:[pending]})).status,200);
 const replay=await call(`/books/${book}/mutations`,b.token,{operations:[pending]});assert.equal(replay.status,200);
 assert.equal(replay.data.entities.filter((e:any)=>e.kind==='transactions').length,1);
 assert.equal(replay.data.entities.find((e:any)=>e.kind==='accounts').data.balance_in_cents,8800);
 assert.equal(replay.data.entities.find((e:any)=>e.kind==='transactions').data.created_by,b.user.id);
 assert.equal((await call(`/books/${book}/mutations`,a.token,{operations:[op('transactions',tx(book,'another',300))]})).status,200);
 assert.equal((await call(`/books/${book}/mutations`,a.token,{operations:[op('transactions',tx(book,'offline',1500),1)]})).status,200);
 const conflict=await call(`/books/${book}/mutations`,b.token,{operations:[op('transactions',tx(book,'offline',2000),1)]});assert.equal(conflict.status,409);assert.equal(conflict.data.details.remote.version,2);
 assert.equal((await call(`/books/${book}/mutations`,b.token,{operations:[op('transactions',tx(book,'offline',2000),2)]})).status,200);
 assert.equal((await call(`/books/${book}/mutations`,b.token,{operations:[op('transactions',tx(book,'another',400),1)]})).status,403);
 assert.equal((await call(`/books/${book}/mutations`,b.token,{operations:[op('accounts',account(book,'illegal'))]})).status,403);
 assert.equal((await call(`/books/${book}/mutations`,a.token,{operations:[op('transactions',{...tx(book,'cross'),book_id:'personal-private'})]})).status,400);
 assert.equal((await call(`/books/${book}/mutations`,a.token,{operations:[op('transactions',{...tx(book,'raw'),metadata_json:'{"rawNotification":"private"}'})]})).status,400);
 const snapshot=(await call(`/books/${book}/snapshot`,a.token)).data;assert.equal(snapshot.entities.find((e:any)=>e.kind==='accounts').data.balance_in_cents,7700);
 assert.equal((await call(`/books/${book}/changes?cursor=0`,b.token)).data.cursor,snapshot.cursor);
 assert.equal((await call(`/books/${book}/members/${a.user.id}`,a.token,undefined,'DELETE')).status,403);
 assert.equal((await call(`/books/${book}/members/${b.user.id}`,a.token,undefined,'DELETE')).status,200);
 assert.equal((await call(`/books/${book}/mutations`,b.token,{operations:[op('transactions',tx(book,'revoked'))]})).status,403);
 assert.equal((await call(`/books/${book}/snapshot`,b.token)).status,403);
 assert.equal((await call('/auth/logout',a.token,{})).status,200);assert.equal((await call('/auth/me',a.token)).status,401);
});
test('批量原子性、校准版本、负余额、邀请过期、共享额度',async(t)=>{
 const {app,store}=await createApp(':memory:');await app.ready();t.after(()=>app.close());
 for(const id of ['owner','guest'])store.db.prepare('INSERT INTO users VALUES(?,?,?,?)').run(id,id,'unused',now);
 const book='family';store.create('owner',book,'家庭','family',[{kind:'accounts',id:'cash',data:account(book)}]);
 assert.throws(()=>store.mutate(book,'owner',[op('transactions',tx(book,'good')),op('transactions',{...tx(book,'bad'),account_id:'missing'})]));
 assert.equal(store.all(book,'transactions').length,0);assert.equal((store.db.prepare('SELECT COUNT(*) n FROM operations').get() as {n:number}).n,0);
 const calibration={...op('transactions',{...tx(book,'calibration',-15000),type:'adjustment'}),expectedAccountVersion:1};store.mutate(book,'owner',[calibration]);
 assert.equal(store.get(book,'accounts','cash')!.data.balance_in_cents,-5000);
 assert.throws(()=>store.mutate(book,'owner',[{...calibration,operationId:randomUUID(),id:'stale',data:{...calibration.data,id:'stale'}}]),/校准/);
 const inv=store.invite(book,'owner');store.db.prepare('UPDATE invitations SET expires_at=? WHERE id=?').run(now-1,inv.id);assert.throws(()=>store.accept(inv.code,'guest'),/过期/);
 store.create('owner','enterprise','企业','enterprise',[]);store.create('owner','third','第三本','family',[]);assert.throws(()=>store.create('owner','fourth','第四本','family',[]),/上限/);
});

test('服务端拒绝已删除原流水继续被关联',async(t)=>{
 const {app,store}=await createApp(':memory:');await app.ready();t.after(()=>app.close());
 store.db.prepare('INSERT INTO users VALUES(?,?,?,?)').run('owner','owner','unused',now);
 const book='relation-book';store.create('owner',book,'家庭','family',[{kind:'accounts',id:'cash',data:account(book)}]);
 const original=tx(book,'original',500);
 store.mutate(book,'owner',[op('transactions',original)]);
 const refund={...tx(book,'refund',100),type:'refund',related_transaction_id:'original'};
 store.mutate(book,'owner',[op('transactions',refund)]);
 assert.throws(()=>store.mutate(book,'owner',[op('transactions',{...original,deleted_at:now+1,updated_at:now+1},1)]),/不存在或已删除/);
 store.mutate(book,'owner',[op('transactions',{...refund,deleted_at:now+2,updated_at:now+2},1)]);
 store.mutate(book,'owner',[op('transactions',{...original,deleted_at:now+3,updated_at:now+3},1)]);
 assert.equal(store.get(book,'transactions','original')?.data.deleted_at,now+3);
});
