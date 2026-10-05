import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createApp} from '../src/app.js';
import {ConsoleAIProvider} from '../src/console/ai.js';
import {encodePassword} from '../src/console/auth.js';

test('model configuration never returns secret values and routing records actual usage with fallback',async t=>{
  const previous={key:process.env.CONSOLE_TEST_AI_KEY,allow:process.env.AI_ENDPOINT_ALLOWLIST};
  process.env.CONSOLE_TEST_AI_KEY='test-only-secret';process.env.AI_ENDPOINT_ALLOWLIST='models.example.test';
  t.after(()=>{if(previous.key===undefined)delete process.env.CONSOLE_TEST_AI_KEY;else process.env.CONSOLE_TEST_AI_KEY=previous.key;if(previous.allow===undefined)delete process.env.AI_ENDPOINT_ALLOWLIST;else process.env.AI_ENDPOINT_ALLOWLIST=previous.allow;});
  const {app,store}=await createApp(':memory:');t.after(()=>app.close());
  store.db.prepare('INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)').run('ai-test','ai_test_admin',await encodePassword('ai-test-admin-password'),'super',store.now());
  const token=(await app.inject({method:'POST',url:'/api/v1/console/auth/login',payload:{username:'ai_test_admin',password:'ai-test-admin-password'}})).json().data.token;const headers={authorization:`Bearer ${token}`};
  const body={name:'测试模型',provider:'openai-compatible',model:'test-model',endpoint:'https://models.example.test',keyRef:'CONSOLE_TEST_AI_KEY',inputPrice:2,outputPrice:4,maxTokens:512,timeoutMs:1000,enabled:true,priority:10,fallbackId:null};
  const create=await app.inject({method:'POST',url:'/api/v1/console/ai/models',headers,payload:body});assert.equal(create.statusCode,200);const fallbackId=create.json().data.id;
  const list=await app.inject({url:'/api/v1/console/ai/models',headers});assert.ok(!list.body.includes('test-only-secret'));assert.equal(list.json().data.items[0].keyConfigured,true);
  const provider=new ConsoleAIProvider(store,{complete:async()=>{throw new Error('legacy must not run');}},async()=>new Response(JSON.stringify({choices:[{message:{content:'识别结果'}}],usage:{prompt_tokens:100,completion_tokens:50}}),{status:200}));
  assert.equal(await provider.complete({systemPrompt:'policy',userText:'private text'}),'识别结果');
  const call=store.db.prepare('SELECT * FROM console_ai_calls').get() as {input_tokens:number;output_tokens:number;cost_microusd:number};assert.equal(call.input_tokens,100);assert.equal(call.output_tokens,50);assert.equal(call.cost_microusd,400);
  const logs=await app.inject({url:'/api/v1/console/ai/calls',headers});assert.ok(!logs.body.includes('private text'));assert.ok(!logs.body.includes('识别结果'));assert.ok(!logs.body.includes('test-only-secret'));
  const primary=(await app.inject({method:'POST',url:'/api/v1/console/ai/models',headers,payload:{...body,model:'primary',priority:100,fallbackId}})).json().data.id;
  let attempt=0;const fallback=new ConsoleAIProvider(store,undefined,async()=>{attempt++;return attempt===1?new Response('{}',{status:503}):new Response(JSON.stringify({choices:[{message:{content:'备用结果'}}]}),{status:200});});
  assert.equal(await fallback.complete({systemPrompt:'policy',userText:'never logged'}),'备用结果');assert.equal(attempt,2);
  const usage=(await app.inject({url:'/api/v1/console/ai/usage?period=week',headers})).json().data;assert.equal(usage.totals.calls,3);assert.equal(usage.totals.pricedCalls,1);assert.equal(usage.totals.costMicroUsd,400);
  assert.equal((await app.inject({method:'PUT',url:`/api/v1/console/ai/models/${fallbackId}`,headers,payload:{...body,fallbackId:primary}})).statusCode,400);
  assert.equal((await app.inject({method:'POST',url:'/api/v1/console/ai/models',headers,payload:{...body,endpoint:'https://not-allowed.example'}})).statusCode,400);
});
