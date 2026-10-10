import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createApp } from '../src/app.js';
import { membershipCurrent } from '../src/payment.js';

test('published feature switches use the same rollout for delivery and execution',async t=>{
  const {app,store}=await createApp(':memory:'); t.after(()=>app.close());
  const publish=(version:number,rollout:number)=>store.db.prepare('INSERT OR REPLACE INTO console_publications VALUES(?,?,?,?,?,?,?)').run('config','runtime',version,rollout,'fixture',store.now(),null);
  store.db.prepare('INSERT INTO console_documents VALUES(?,?,?,?,?,?,?)').run('config','runtime',1,JSON.stringify({aiEnabled:false,voiceEnabled:false,cloudBackupEnabled:false}),'test','fixture',store.now());
  publish(1,100);
  for(const url of ['/api/v1/assistant/parse-transaction','/api/v1/insights/interpret','/api/v1/asr/recognize','/api/v1/sync/bootstrap']) {
    const response=await app.inject({method:'POST',url,payload:{}}); assert.equal(response.statusCode,503,url);
  }
  assert.equal((await app.inject({url:'/api/v1/membership/catalog'})).statusCode,200);
  assert.equal((await app.inject({url:'/api/v1/app/config'})).json().documents[0].payload.aiEnabled,false);
  publish(1,0);
  assert.deepEqual((await app.inject({url:'/api/v1/app/config'})).json().documents,[]);
  assert.equal((await app.inject({method:'POST',url:'/api/v1/asr/recognize',payload:{}})).statusCode,401);
  store.db.prepare('DELETE FROM console_publications').run();
  assert.equal((await app.inject({method:'POST',url:'/api/v1/asr/recognize',payload:{}})).statusCode,401);
});

test('production free and canceled users receive restrictive policies without stale paid grants',async t=>{
  const previous=process.env.ALL_FEATURES_FREE_FOR_TESTING;
  process.env.ALL_FEATURES_FREE_FOR_TESTING='false';
  t.after(()=>{if(previous===undefined) delete process.env.ALL_FEATURES_FREE_FOR_TESTING; else process.env.ALL_FEATURES_FREE_FOR_TESTING=previous;});
  const {app,store}=await createApp(':memory:');t.after(()=>app.close());
  const response=(await app.inject({method:'POST',url:'/api/v1/auth/register',payload:{username:'runtime_member',password:'runtime-member-password'}})).json();
  const current=membershipCurrent(store,response.user.id);
  for(const policy of Object.values(current.featurePolicies??{})) assert.equal(policy.requiresMembership,true);
  const policies=current.featurePolicies as Record<string,{enabled:boolean;requiresMembership:boolean}>;
  assert.equal(policies.automatic_bookkeeping?.enabled,true);
  assert.equal(current.entitlements.length,0);
  store.db.prepare('INSERT INTO membership_adjustments VALUES(?,?,?,?,?,?,?)').run(response.user.id,null,'',store.now(),store.now(),store.now(),'cancel');
  const canceled=membershipCurrent(store,response.user.id);
  assert.equal(canceled.membership.status,'canceled');
  const canceledPolicies=canceled.featurePolicies as Record<string,{enabled:boolean;requiresMembership:boolean}>;
  assert.equal(canceledPolicies.ledger_sync?.requiresMembership,true);
  assert.equal(canceled.entitlements.length,0);
});
