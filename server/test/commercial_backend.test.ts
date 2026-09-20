import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createApp } from '../src/app.js';

test('commercial backend controls and quota enforcement', async () => {
  process.env.ADMIN_TOKEN='test-super-admin-token-123456789';
  const {app}=await createApp(':memory:',{complete:async()=> '[]'});
  const admin={'x-admin-token':process.env.ADMIN_TOKEN,'content-type':'application/json'};
  let r=await app.inject({method:'PUT',url:'/api/v1/admin/features/voice_bookkeeping',headers:admin,payload:{enabled:true,rolloutPercent:100,platforms:['android','ios'],config:{mode:'beta'}}});
  assert.equal(r.statusCode,200);
  r=await app.inject({method:'GET',url:'/api/v1/app/features?platform=android&version=1.0.0&installationId=installation-123'});
  assert.equal(r.json().flags.voice_bookkeeping.enabled,true);

  r=await app.inject({method:'PUT',url:'/api/v1/admin/membership/tiers/pro/1',headers:admin,payload:{title:'Pro',entitlements:[{key:'voice_bookkeeping',title:'Voice',type:'quota',value:2},{key:'ocr_import',title:'OCR',type:'quota',value:1}]}});
  assert.equal(r.statusCode,200);
  assert.equal((await app.inject({method:'POST',url:'/api/v1/admin/membership/tiers/pro/1/activate',headers:admin})).statusCode,200);
  r=await app.inject({method:'PUT',url:'/api/v1/admin/membership/products/pro_yearly',headers:admin,payload:{title:'Pro yearly',tierId:'pro',durationDays:365,enabled:true,recommended:true,displayPrice:'¥128',priceInMinor:12800,currency:'CNY',appleProductId:'test.pro.yearly',googleProductId:null,sort:1}});
  assert.equal(r.statusCode,200);
  r=await app.inject({method:'GET',url:'/api/v1/membership/products'});assert.equal(r.json().products[0].priceInMinor,12800);

  r=await app.inject({method:'POST',url:'/api/v1/auth/register',payload:{username:'quota_user',password:'very-secure-password',displayName:'Quota'}});
  assert.equal(r.statusCode,201);const auth={authorization:`Bearer ${r.json().token}`};
  const userId=r.json().user.id;
  r=await app.inject({method:'POST',url:`/api/v1/admin/users/${userId}/entitlement-grants`,headers:admin,payload:{key:'ocr_import',value:1,expiresAt:null,reason:'commercial backend test grant'}});
  assert.equal(r.statusCode,200);
  r=await app.inject({method:'GET',url:'/api/v1/membership/entitlements',headers:auth});assert.equal(r.statusCode,200);
  assert.equal(r.json().entitlements.find((x:any)=>x.key==='ocr_import').remaining,1);
  await app.close();
});
