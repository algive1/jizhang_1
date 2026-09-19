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
 for(const id of ['owner','guest'])store.db.prepare('INSERT INTO users(id,username,password_hash,created_at) VALUES(?,?,?,?)').run(id,id,'unused',now);
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
 store.db.prepare('INSERT INTO users(id,username,password_hash,created_at) VALUES(?,?,?,?)').run('owner','owner','unused',now);
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


test('账户昵称随注册、登录和 me 返回，旧注册请求仍兼容',async(t)=>{
 const {app}=await createApp(':memory:');await app.ready();t.after(()=>app.close());
 const registered=await app.inject({method:'POST',url:'/api/v1/auth/register',payload:{username:'named_user',password:'local-test-password',displayName:'小陆'}});
 assert.equal(registered.statusCode,201);
 const first=registered.json() as any;
 assert.equal(first.user.username,'named_user');
 assert.equal(first.user.displayName,'小陆');
 const login=await app.inject({method:'POST',url:'/api/v1/auth/login',payload:{username:'named_user',password:'local-test-password'}});
 assert.equal(login.statusCode,200);
 assert.equal((login.json() as any).user.displayName,'小陆');
 const me=await app.inject({method:'GET',url:'/api/v1/auth/me',headers:{authorization:`Bearer ${first.token}`}});
 assert.equal(me.statusCode,200);
 assert.equal((me.json() as any).user.displayName,'小陆');
 const legacy=await app.inject({method:'POST',url:'/api/v1/auth/register',payload:{username:'legacy_user',password:'local-test-password'}});
 assert.equal(legacy.statusCode,201);
 assert.equal((legacy.json() as any).user.displayName,null);
});


test('账号安全：恢复密钥、改密与设备会话',async(t)=>{
 const {app}=await createApp(':memory:');await app.ready();t.after(()=>app.close());
 const registered=await app.inject({method:'POST',url:'/api/v1/auth/register',payload:{username:'security_user',password:'local-test-password',displayName:'安全用户',deviceName:'测试设备'}});
 assert.equal(registered.statusCode,201);
 const first=registered.json() as any;
 const auth={authorization:`Bearer ${first.token}`};

 const rotated=await app.inject({method:'POST',url:'/api/v1/auth/recovery-key/rotate',headers:auth,payload:{}});
 assert.equal(rotated.statusCode,200);
 const recoveryKey=(rotated.json() as any).recoveryKey as string;
 assert.ok(recoveryKey.length>=20);

 const sessions=await app.inject({method:'GET',url:'/api/v1/auth/sessions',headers:auth});
 assert.equal(sessions.statusCode,200);
 assert.equal((sessions.json() as any).sessions.length,1);
 assert.equal((sessions.json() as any).sessions[0].current,true);

 const changed=await app.inject({method:'POST',url:'/api/v1/auth/change-password',headers:auth,payload:{currentPassword:'local-test-password',newPassword:'local-test-password-2'}});
 assert.equal(changed.statusCode,200);
 assert.equal((await app.inject({method:'POST',url:'/api/v1/auth/login',payload:{username:'security_user',password:'local-test-password'}})).statusCode,401);

 const recovered=await app.inject({method:'POST',url:'/api/v1/auth/recover',payload:{username:'security_user',recoveryKey,newPassword:'local-test-password-3',deviceName:'恢复设备'}});
 assert.equal(recovered.statusCode,200);
 const recoveredBody=recovered.json() as any;
 assert.ok(recoveredBody.recoveryKey);
 assert.notEqual(recoveredBody.recoveryKey,recoveryKey);

 const logoutAll=await app.inject({method:'POST',url:'/api/v1/auth/logout-all',headers:{authorization:`Bearer ${recoveredBody.token}`},payload:{}});
 assert.equal(logoutAll.statusCode,200);
 assert.equal((await app.inject({method:'GET',url:'/api/v1/auth/me',headers:{authorization:`Bearer ${recoveredBody.token}`}})).statusCode,401);
});


test('家庭第一阶段：付款归属、所有权转让与解散生命周期',async(t)=>{
 const {app}=await createApp(':memory:');await app.ready();t.after(()=>app.close());
 async function register(username:string) {
   const res=await app.inject({method:'POST',url:'/api/v1/auth/register',payload:{username,password:'local-test-password'}});
   return res.json() as any;
 }
 const owner=await register('phase_owner');
 const member=await register('phase_member');
 const outsider=await register('phase_outsider');
 const book='phase-'+randomUUID();
 assert.equal((await app.inject({method:'POST',url:'/api/v1/books',headers:{authorization:`Bearer ${owner.token}`},payload:{id:book,name:'我们家',type:'family',entities:[{kind:'accounts',id:'cash',data:account(book)}]}})).statusCode,200);
 const invitation=(await app.inject({method:'POST',url:`/api/v1/books/${book}/invitations`,headers:{authorization:`Bearer ${owner.token}`},payload:{}})).json() as any;
 assert.equal((await app.inject({method:'POST',url:'/api/v1/invitations/accept',headers:{authorization:`Bearer ${member.token}`},payload:{code:invitation.code}})).statusCode,200);

 const attributed={...tx(book,'for-member',500),user_id:member.user.id};
 const mutation=await app.inject({method:'POST',url:`/api/v1/books/${book}/mutations`,headers:{authorization:`Bearer ${owner.token}`},payload:{operations:[op('transactions',attributed)]}});
 assert.equal(mutation.statusCode,200);
 const stored=(mutation.json() as any).entities.find((e:any)=>e.kind==='transactions'&&e.id==='for-member').data;
 assert.equal(stored.created_by,owner.user.id);
 assert.equal(stored.user_id,member.user.id);

 const invalid={...tx(book,'outsider-payer',100),user_id:outsider.user.id};
 assert.equal((await app.inject({method:'POST',url:`/api/v1/books/${book}/mutations`,headers:{authorization:`Bearer ${owner.token}`},payload:{operations:[op('transactions',invalid)]}})).statusCode,400);

 // Historical payer attribution must survive membership changes. The owner
 // recorded this row, so the owner may still edit it after the payer leaves,
 // provided the payer attribution itself is not changed.
 assert.equal((await app.inject({method:'DELETE',url:`/api/v1/books/${book}/members/${member.user.id}`,headers:{authorization:`Bearer ${owner.token}`}})).statusCode,200);
 const retained={...stored,note:'payer left but history remains'};
 delete retained.family_id;
 const retainedEdit=await app.inject({method:'POST',url:`/api/v1/books/${book}/mutations`,headers:{authorization:`Bearer ${owner.token}`},payload:{operations:[{operationId:randomUUID(),kind:'transactions',id:'for-member',action:'update',expectedVersion:stored.version,data:retained}]}});
 assert.equal(retainedEdit.statusCode,200);
 const retainedStored=(retainedEdit.json() as any).entities.find((e:any)=>e.kind==='transactions'&&e.id==='for-member').data;
 assert.equal(retainedStored.user_id,member.user.id);
 const reassigned={...tx(book,'departed-payer',100),user_id:member.user.id};
 assert.equal((await app.inject({method:'POST',url:`/api/v1/books/${book}/mutations`,headers:{authorization:`Bearer ${owner.token}`},payload:{operations:[op('transactions',reassigned)]}})).statusCode,400);

 // Rejoin so the same member can participate in the ownership lifecycle below.
 const reinvite=(await app.inject({method:'POST',url:`/api/v1/books/${book}/invitations`,headers:{authorization:`Bearer ${owner.token}`},payload:{}})).json() as any;
 assert.equal((await app.inject({method:'POST',url:'/api/v1/invitations/accept',headers:{authorization:`Bearer ${member.token}`},payload:{code:reinvite.code}})).statusCode,200);

 assert.equal((await app.inject({method:'POST',url:`/api/v1/books/${book}/transfer-ownership`,headers:{authorization:`Bearer ${member.token}`},payload:{userId:member.user.id}})).statusCode,403);
 assert.equal((await app.inject({method:'POST',url:`/api/v1/books/${book}/transfer-ownership`,headers:{authorization:`Bearer ${owner.token}`},payload:{userId:member.user.id}})).statusCode,200);
 const changed=(await app.inject({method:'GET',url:`/api/v1/books/${book}/changes?cursor=0`,headers:{authorization:`Bearer ${member.token}`}})).json() as any;
 const bookChange=changed.changes.filter((e:any)=>e.kind==='books').at(-1);
 assert.equal(bookChange.data.owner_user_id,member.user.id);
 assert.equal(bookChange.deleted,false);
 const members=(await app.inject({method:'GET',url:`/api/v1/books/${book}/members`,headers:{authorization:`Bearer ${member.token}`}})).json() as any;
 assert.equal(members.members.find((m:any)=>m.user_id===member.user.id).role,'owner');
 assert.equal(members.members.find((m:any)=>m.user_id===owner.user.id).role,'admin');

 assert.equal((await app.inject({method:'POST',url:`/api/v1/books/${book}/disband`,headers:{authorization:`Bearer ${owner.token}`},payload:{}})).statusCode,403);
 assert.equal((await app.inject({method:'POST',url:`/api/v1/books/${book}/disband`,headers:{authorization:`Bearer ${member.token}`},payload:{}})).statusCode,200);
 assert.equal((await app.inject({method:'POST',url:`/api/v1/books/${book}/mutations`,headers:{authorization:`Bearer ${member.token}`},payload:{operations:[op('transactions',tx(book,'after-disband'))]}})).statusCode,403);
});
