import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createApp } from '../src/app.js';

test('theme catalog is public, versioned and admin protected', async t => {
  const old = process.env.MEMBERSHIP_ADMIN_TOKEN;
  process.env.MEMBERSHIP_ADMIN_TOKEN = '0123456789abcdef0123456789abcdef';
  t.after(() => { if (old == null) delete process.env.MEMBERSHIP_ADMIN_TOKEN; else process.env.MEMBERSHIP_ADMIN_TOKEN = old; });
  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const initial = await app.inject({method:'GET',url:'/api/v1/themes/catalog'});
  assert.equal(initial.statusCode,200);
  assert.equal(initial.json().version,1);
  assert.equal(initial.json().themes[0].id,'fresh_green');
  assert.equal(initial.json().themes[0].premium,false);

  const denied = await app.inject({method:'PUT',url:'/api/v1/admin/themes/catalog',payload:initial.json()});
  assert.equal(denied.statusCode,403);

  const next = initial.json();
  next.version = 2;
  next.themes[1].name = '云雾蓝 2';
  const updated = await app.inject({
    method:'PUT',url:'/api/v1/admin/themes/catalog',
    headers:{authorization:'Bearer 0123456789abcdef0123456789abcdef'},
    payload:next,
  });
  assert.equal(updated.statusCode,200);
  assert.equal(updated.json().version,2);

  const stale = await app.inject({
    method:'PUT',url:'/api/v1/admin/themes/catalog',
    headers:{authorization:'Bearer 0123456789abcdef0123456789abcdef'},
    payload:next,
  });
  assert.equal(stale.statusCode,409);
});
