import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createApp } from '../src/app.js';

test('commercial backend controls', async () => {
  process.env.ADMIN_TOKEN='test-super-admin-token-123456789';
  const {app}=await createApp(':memory:');
  const headers={'x-admin-token':process.env.ADMIN_TOKEN,'content-type':'application/json'};
  let response=await app.inject({method:'PUT',url:'/api/v1/admin/features/voice_bookkeeping',headers,payload:{enabled:true,rolloutPercent:100,platforms:['android','ios'],config:{mode:'beta'}}});
  assert.equal(response.statusCode,200);
  response=await app.inject({method:'GET',url:'/api/v1/app/features?platform=android&version=1.0.0&installationId=installation-123'});
  assert.equal(response.statusCode,200);
  assert.equal(response.json().flags.voice_bookkeeping.enabled,true);
  response=await app.inject({method:'PUT',url:'/api/v1/admin/membership/tiers/pro/1',headers,payload:{title:'Pro',entitlements:[{key:'voice_bookkeeping',title:'Voice',type:'boolean',value:true}]}});
  assert.equal(response.statusCode,200);
  response=await app.inject({method:'POST',url:'/api/v1/admin/membership/tiers/pro/1/activate',headers});
  assert.equal(response.statusCode,200);
  await app.close();
});
