import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createApp} from '../src/app.js';
import {encodePassword} from '../src/console/auth.js';

test('backup metadata excludes content, feedback is redacted and operations persist without push',async t=>{
  const {app,store}=await createApp(':memory:');t.after(()=>app.close());
  store.db.prepare('INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)').run('ops-test','ops_test_admin',await encodePassword('ops-test-admin-password'),'super',store.now());
  const token=(await app.inject({method:'POST',url:'/api/v1/console/auth/login',payload:{username:'ops_test_admin',password:'ops-test-admin-password'}})).json().data.token;const headers={authorization:`Bearer ${token}`};
  const registered=(await app.inject({method:'POST',url:'/api/v1/auth/register',payload:{username:'ops_user',password:'ops-user-password'}})).json();
  store.db.prepare('INSERT INTO cloud_datasets(user_id,dataset_id,revision,has_snapshot,created_at,updated_at,snapshot_blob,snapshot_sha256,snapshot_size) VALUES(?,?,?,?,?,?,?,?,?)').run(registered.user.id,'dataset-test',3,1,store.now(),store.now(),Buffer.from('private content'),'a'.repeat(64),15);
  const backups=await app.inject({url:'/api/v1/console/backups',headers});assert.equal(backups.statusCode,200);assert.equal(backups.json().data.items[0].size,15);assert.ok(!backups.body.includes('private content'));assert.ok(!backups.body.includes('snapshot_blob'));
  const summary=(await app.inject({url:'/api/v1/console/backups/summary',headers})).json().data;assert.equal(summary.storage.bytes,15);assert.match(summary.encryption,/尚未端到端加密/);
  const feedback=await app.inject({method:'POST',url:'/api/v1/support/tickets',headers:{authorization:`Bearer ${registered.token}`},payload:{installationId:'f'.repeat(32),subject:'请联系 13800138000',message:'支付失败，手机号 13800138000，token=private-secret',contact:'contact@example.com'}});assert.equal(feedback.statusCode,201);
  const id=feedback.json().id;const detail=await app.inject({url:`/api/v1/console/feedback/${id}`,headers});assert.equal(detail.statusCode,200);assert.ok(!detail.body.includes('13800138000'));assert.ok(!detail.body.includes('private-secret'));assert.ok(!detail.body.includes('contact@example.com'));
  assert.equal((await app.inject({method:'PATCH',url:`/api/v1/console/feedback/${id}/status`,headers,payload:{status:'resolved'}})).statusCode,200);
  assert.equal((await app.inject({url:'/api/v1/console/feedback?status=resolved',headers})).json().data.total,1);
  const operation=await app.inject({method:'POST',url:'/api/v1/console/operations',headers,payload:{kind:'faq',title:'测试 FAQ',body:'离线时可以继续记账',enabled:true}});assert.equal(operation.statusCode,200);
  assert.equal((await app.inject({url:'/api/v1/app/operations?kind=faq'})).json().items[0].title,'测试 FAQ');
  const announcement=await app.inject({method:'POST',url:'/api/v1/console/announcements',headers,payload:{title:'测试公告',body:'此公告仅用于测试'}});assert.equal(announcement.statusCode,200);
  assert.equal((store.db.prepare('SELECT COUNT(*) AS n FROM push_outbox').get() as {n:number}).n,0);
  assert.equal((await app.inject({url:'/api/v1/console/backups'})).statusCode,401);
});
