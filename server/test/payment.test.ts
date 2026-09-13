import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createCipheriv, createSign, generateKeyPairSync } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../src/app.js';

test('会员支付订单只接受服务端套餐金额，并在渠道未配置时拒绝伪造成功', async t => {
  const names = [
    'WECHAT_APP_ID', 'WECHAT_MCH_ID', 'WECHAT_SERIAL_NO', 'WECHAT_PRIVATE_KEY',
    'WECHAT_PRIVATE_KEY_PATH', 'WECHAT_NOTIFY_URL', 'ALIPAY_APP_ID',
    'ALIPAY_PRIVATE_KEY', 'ALIPAY_PRIVATE_KEY_PATH', 'ALIPAY_NOTIFY_URL',
  ];
  const previous = Object.fromEntries(names.map(name => [name, process.env[name]]));
  for (const name of names) delete process.env[name];
  t.after(() => {
    for (const name of names) {
      const value = previous[name];
      if (value == null) delete process.env[name]; else process.env[name] = value;
    }
  });
  const { app } = await createApp(':memory:');
  const base = await app.listen({ host: '127.0.0.1', port: 0 });
  t.after(() => app.close());
  const request = async (path: string, token = '', body?: unknown, method = body ? 'POST' : 'GET') => {
    const response = await fetch(`${base}/api/v1${path}`, {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const raw = await response.text();
    return { status: response.status, data: raw ? JSON.parse(raw) as Record<string, unknown> : {} };
  };
  const register = await request('/auth/register', '', { username: 'payment_test', password: 'local-test-password' });
  assert.equal(register.status, 201);
  const token = register.data.token as string;
  const order = await request('/membership/orders', token, {
    productId: 'quarterly', channel: 'wechat', idempotencyKey: 'payment-test-0001', priceInCents: 1,
  });
  assert.equal(order.status, 400, 'strict schema must reject client supplied price');
  const unavailable = await request('/membership/orders', token, {
    productId: 'quarterly', channel: 'wechat', idempotencyKey: 'payment-test-0002',
  });
  assert.equal(unavailable.status, 503);
  const orders = await request('/membership/orders', token);
  assert.equal(orders.status, 200);
  const rows = orders.data.orders as Array<Record<string, unknown>>;
  assert.equal(rows.length, 1);
  assert.equal(rows[0]?.amountInCents, 3000);
  assert.equal(rows[0]?.status, 'failed');
  const replay = await request('/membership/orders', token, {
    productId: 'quarterly', channel: 'wechat', idempotencyKey: 'payment-test-0002',
  });
  assert.equal(replay.status, 200);
  assert.equal((replay.data as Record<string, unknown>).status, 'failed');
  const conflict = await request('/membership/orders', token, {
    productId: 'quarterly', channel: 'alipay', idempotencyKey: 'payment-test-0002',
  });
  assert.equal(conflict.status, 409);
});

test('微信和支付宝沙箱适配器可生成官方 APP 调起参数', async t => {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const privatePem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  const publicPem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
  const names = ['WECHAT_APP_ID', 'WECHAT_MCH_ID', 'WECHAT_SERIAL_NO', 'WECHAT_PRIVATE_KEY', 'WECHAT_NOTIFY_URL', 'WECHAT_API_BASE_URL', 'ALIPAY_APP_ID', 'ALIPAY_PRIVATE_KEY', 'ALIPAY_NOTIFY_URL'];
  const previous = Object.fromEntries(names.map(name => [name, process.env[name]]));
  process.env.WECHAT_APP_ID = 'wx-test-app';
  process.env.WECHAT_MCH_ID = '1900000001';
  process.env.WECHAT_SERIAL_NO = 'serial-test';
  process.env.WECHAT_PRIVATE_KEY = privatePem;
  process.env.WECHAT_NOTIFY_URL = 'https://example.test/wechat';
  process.env.ALIPAY_APP_ID = '2026000000000000';
  process.env.ALIPAY_PRIVATE_KEY = privatePem;
  process.env.ALIPAY_NOTIFY_URL = 'https://example.test/alipay';
  const mock = createServer((request, response) => {
    assert.equal(request.url, '/v3/pay/transactions/app');
    response.setHeader('content-type', 'application/json');
    response.end(JSON.stringify({ prepay_id: 'wx-prepay-test' }));
  });
  await new Promise<void>(resolve => mock.listen(0, '127.0.0.1', resolve));
  const address = mock.address();
  assert.ok(address && typeof address === 'object');
  process.env.WECHAT_API_BASE_URL = `http://127.0.0.1:${address.port}`;
  t.after(async () => {
    await new Promise<void>(resolve => mock.close(() => resolve()));
    for (const name of names) {
      const value = previous[name];
      if (value == null) delete process.env[name]; else process.env[name] = value;
    }
  });
  const { app } = await createApp(':memory:');
  const base = await app.listen({ host: '127.0.0.1', port: 0 });
  t.after(() => app.close());
  const request = async (path: string, token = '', body?: unknown) => {
    const response = await fetch(`${base}/api/v1${path}`, {
      method: body ? 'POST' : 'GET',
      headers: { ...(body ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: response.status, data: await response.json() as Record<string, unknown> };
  };
  const register = await request('/auth/register', '', { username: 'payment_sandbox', password: 'local-test-password' });
  const token = register.data.token as string;
  const wechat = await request('/membership/orders', token, { productId: 'quarterly', channel: 'wechat', idempotencyKey: 'sandbox-wechat-0001' });
  assert.equal(wechat.status, 200);
  assert.equal((wechat.data.invoke as Record<string, unknown>).prepayId, 'wx-prepay-test');
  assert.equal(wechat.data.amountInCents, 3000);
  const alipay = await request('/membership/orders', token, { productId: 'monthly', channel: 'alipay', idempotencyKey: 'sandbox-alipay-0001' });
  assert.equal(alipay.status, 200);
  assert.match(String((alipay.data.invoke as Record<string, unknown>).orderString), /alipay\.trade\.app\.pay/);
  assert.ok(publicPem.includes('BEGIN PUBLIC KEY'));
});

test('支付回调验签后才授予会员，重复通知保持幂等', async t => {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const privatePem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  const publicPem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
  const apiV3Key = '01234567890123456789012345678901';
  const names = [
    'WECHAT_APP_ID', 'WECHAT_MCH_ID', 'WECHAT_SERIAL_NO', 'WECHAT_PRIVATE_KEY',
    'WECHAT_NOTIFY_URL', 'WECHAT_PLATFORM_PUBLIC_KEY', 'WECHAT_PLATFORM_SERIAL_NO',
    'WECHAT_API_V3_KEY', 'WECHAT_API_BASE_URL',
  ];
  const previous = Object.fromEntries(names.map(name => [name, process.env[name]]));
  process.env.WECHAT_APP_ID = 'wx-callback-test';
  process.env.WECHAT_MCH_ID = '1900000002';
  process.env.WECHAT_SERIAL_NO = 'merchant-serial';
  process.env.WECHAT_PRIVATE_KEY = privatePem;
  process.env.WECHAT_NOTIFY_URL = 'https://example.test/wechat';
  process.env.WECHAT_PLATFORM_PUBLIC_KEY = publicPem;
  process.env.WECHAT_PLATFORM_SERIAL_NO = 'platform-serial';
  process.env.WECHAT_API_V3_KEY = apiV3Key;
  const mock = createServer((_request, response) => {
    response.setHeader('content-type', 'application/json');
    response.end(JSON.stringify({ prepay_id: 'callback-prepay' }));
  });
  await new Promise<void>(resolve => mock.listen(0, '127.0.0.1', resolve));
  const address = mock.address();
  assert.ok(address && typeof address === 'object');
  process.env.WECHAT_API_BASE_URL = `http://127.0.0.1:${address.port}`;
  t.after(async () => {
    await new Promise<void>(resolve => mock.close(() => resolve()));
    for (const name of names) {
      const value = previous[name];
      if (value == null) delete process.env[name]; else process.env[name] = value;
    }
  });
  const { app } = await createApp(':memory:');
  const base = await app.listen({ host: '127.0.0.1', port: 0 });
  t.after(() => app.close());
  const request = async (path: string, token = '', body?: unknown, headers: Record<string, string> = {}) => {
    const response = await fetch(`${base}/api/v1${path}`, {
      method: body === undefined ? 'GET' : 'POST',
      headers: {
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...headers,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, data: await response.json() as Record<string, unknown> };
  };
  const register = await request('/auth/register', '', { username: 'payment_callback', password: 'local-test-password' });
  const token = register.data.token as string;
  const order = await request('/membership/orders', token, {
    productId: 'quarterly', channel: 'wechat', idempotencyKey: 'callback-wechat-0001',
  });
  assert.equal(order.status, 200);
  const orderId = order.data.id as string;
  const nonce = 'callbacknonce';
  const cipher = createCipheriv('aes-256-gcm', Buffer.from(apiV3Key, 'utf8'), Buffer.from(nonce, 'utf8'));
  cipher.setAAD(Buffer.from('', 'utf8'));
  const transaction = JSON.stringify({
    out_trade_no: orderId,
    transaction_id: 'wx-transaction-callback',
    trade_state: 'SUCCESS',
    amount: { total: 3000 },
  });
  const ciphertext = Buffer.concat([cipher.update(transaction, 'utf8'), cipher.final(), cipher.getAuthTag()]).toString('base64');
  const body = JSON.stringify({ resource: { algorithm: 'AEAD_AES_256_GCM', ciphertext, associated_data: '', nonce } });
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signer = createSign('RSA-SHA256');
  const callbackSignature = signer.update(`${timestamp}\ncallback-header-nonce\n${body}\n`, 'utf8').sign(privateKey, 'base64');
  const callback = await request('/payments/wechat/notify', '', JSON.parse(body), {
    'Wechatpay-Serial': 'platform-serial',
    'Wechatpay-Timestamp': timestamp,
    'Wechatpay-Nonce': 'callback-header-nonce',
    'Wechatpay-Signature': callbackSignature,
  });
  assert.equal(callback.status, 200);
  const current = await request('/membership/current', token);
  assert.equal((current.data.membership as Record<string, unknown>).plan, 'pro');
  const replay = await request('/payments/wechat/notify', '', JSON.parse(body), {
    'Wechatpay-Serial': 'platform-serial',
    'Wechatpay-Timestamp': timestamp,
    'Wechatpay-Nonce': 'callback-header-nonce',
    'Wechatpay-Signature': callbackSignature,
  });
  assert.equal(replay.status, 200);
});

test('支付宝回调验签并校验金额后才授予会员', async t => {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const privatePem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  const publicPem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
  const names = ['ALIPAY_APP_ID', 'ALIPAY_PRIVATE_KEY', 'ALIPAY_NOTIFY_URL', 'ALIPAY_PUBLIC_KEY'];
  const previous = Object.fromEntries(names.map(name => [name, process.env[name]]));
  process.env.ALIPAY_APP_ID = '2026000000000001';
  process.env.ALIPAY_PRIVATE_KEY = privatePem;
  process.env.ALIPAY_NOTIFY_URL = 'https://example.test/alipay';
  process.env.ALIPAY_PUBLIC_KEY = publicPem;
  t.after(() => {
    for (const name of names) {
      const value = previous[name];
      if (value == null) delete process.env[name]; else process.env[name] = value;
    }
  });
  const { app } = await createApp(':memory:');
  const base = await app.listen({ host: '127.0.0.1', port: 0 });
  t.after(() => app.close());
  const request = async (path: string, token = '', body?: unknown) => {
    const response = await fetch(`${base}/api/v1${path}`, {
      method: body === undefined ? 'GET' : 'POST',
      headers: {
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, data: await response.json() as Record<string, unknown> };
  };
  const register = await request('/auth/register', '', { username: 'payment_alipay_callback', password: 'local-test-password' });
  const token = register.data.token as string;
  const order = await request('/membership/orders', token, {
    productId: 'monthly', channel: 'alipay', idempotencyKey: 'callback-alipay-0001',
  });
  assert.equal(order.status, 200);
  const notify: Record<string, string> = {
    app_id: process.env.ALIPAY_APP_ID!,
    out_trade_no: order.data.id as string,
    total_amount: '12.00',
    trade_status: 'TRADE_SUCCESS',
    trade_no: 'ali-transaction-callback',
    sign_type: 'RSA2',
    charset: 'utf-8',
  };
  const content = Object.keys(notify)
    .filter(key => key !== 'sign_type')
    .sort()
    .map(key => `${key}=${notify[key]}`)
    .join('&');
  const sign = createSign('RSA-SHA256').update(content, 'utf8').sign(privateKey, 'base64');
  const form = new URLSearchParams({ ...notify, sign });
  const callback = await fetch(`${base}/api/v1/payments/alipay/notify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form,
  });
  assert.equal(callback.status, 200);
  assert.equal(await callback.text(), 'success');
  const current = await request('/membership/current', token);
  assert.equal((current.data.membership as Record<string, unknown>).plan, 'pro');
});
