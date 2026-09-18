import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';

const keys = [
  'APP_UPDATE_ANDROID_LATEST_VERSION',
  'APP_UPDATE_ANDROID_MINIMUM_VERSION',
  'APP_UPDATE_ANDROID_STORE_URL',
  'APP_UPDATE_ANDROID_MESSAGE',
  'APP_UPDATE_IOS_LATEST_VERSION',
  'APP_UPDATE_IOS_MINIMUM_VERSION',
  'APP_UPDATE_IOS_STORE_URL',
  'APP_UPDATE_IOS_MESSAGE',
] as const;

test('app update policy returns none, optional and required without login', async t => {
  const previous = new Map(keys.map(key => [key, process.env[key]]));
  t.after(() => {
    for (const key of keys) {
      const value = previous.get(key);
      if (value == null) delete process.env[key];
      else process.env[key] = value;
    }
  });

  process.env.APP_UPDATE_ANDROID_LATEST_VERSION = '1.2.0';
  process.env.APP_UPDATE_ANDROID_MINIMUM_VERSION = '1.1.0';
  process.env.APP_UPDATE_ANDROID_STORE_URL = 'https://example.com/android';
  process.env.APP_UPDATE_ANDROID_MESSAGE = 'Android update';

  process.env.APP_UPDATE_IOS_LATEST_VERSION = '2.0.0';
  process.env.APP_UPDATE_IOS_MINIMUM_VERSION = '1.0.0';
  process.env.APP_UPDATE_IOS_STORE_URL = 'https://example.com/ios';
  process.env.APP_UPDATE_IOS_MESSAGE = 'iOS update';

  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const current = await app.inject({
    method: 'GET',
    url: '/api/v1/app/update?platform=android&version=1.2.0',
  });
  assert.equal(current.statusCode, 200);
  assert.deepEqual(current.json(), {
    status: 'none',
    latestVersion: '1.2.0',
    minimumVersion: '1.1.0',
    storeUrl: 'https://example.com/android',
    message: null,
  });

  const optional = await app.inject({
    method: 'GET',
    url: '/api/v1/app/update?platform=android&version=1.1.5',
  });
  assert.equal(optional.statusCode, 200);
  assert.deepEqual(optional.json(), {
    status: 'optional',
    latestVersion: '1.2.0',
    minimumVersion: '1.1.0',
    storeUrl: 'https://example.com/android',
    message: 'Android update',
  });

  const required = await app.inject({
    method: 'GET',
    url: '/api/v1/app/update?platform=android&version=1.0.9',
  });
  assert.equal(required.statusCode, 200);
  assert.equal(required.json().status, 'required');

  const ios = await app.inject({
    method: 'GET',
    url: '/api/v1/app/update?platform=ios&version=1.5.0',
  });
  assert.equal(ios.statusCode, 200);
  assert.deepEqual(ios.json(), {
    status: 'optional',
    latestVersion: '2.0.0',
    minimumVersion: '1.0.0',
    storeUrl: 'https://example.com/ios',
    message: 'iOS update',
  });
});

test('app update stays silent until a store URL is configured', async t => {
  const previous = new Map(keys.map(key => [key, process.env[key]]));
  t.after(() => {
    for (const key of keys) {
      const value = previous.get(key);
      if (value == null) delete process.env[key];
      else process.env[key] = value;
    }
  });

  process.env.APP_UPDATE_ANDROID_LATEST_VERSION = '9.0.0';
  process.env.APP_UPDATE_ANDROID_MINIMUM_VERSION = '8.0.0';
  delete process.env.APP_UPDATE_ANDROID_STORE_URL;

  const { app } = await createApp(':memory:');
  t.after(() => app.close());

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/app/update?platform=android&version=1.0.0',
  });
  assert.equal(response.statusCode, 200);
  assert.equal(response.json().status, 'none');
  assert.equal(response.json().storeUrl, null);
});
