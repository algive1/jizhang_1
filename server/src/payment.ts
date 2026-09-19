import { createDecipheriv, createHash, createPrivateKey, createSign, createVerify, randomBytes, randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { ApiError, requireCondition as check } from './contract.js';
import { getMembershipCatalog } from './membership_catalog.js';
import { applePlanForProductId } from './apple_iap.js';
import type { Store } from './store.js';

export type PaymentChannel = 'wechat' | 'alipay';
type User = { id: string; username: string };
type Authenticate = (header: string | undefined) => User;
type OrderRow = {
  id: string;
  user_id: string;
  product_id: string;
  channel: PaymentChannel;
  amount_in_cents: number;
  idempotency_key: string;
  status: string;
  provider_trade_no: string | null;
  invoke_json: string | null;
  created_at: number;
  updated_at: number;
};

const createOrderSchema = z.strictObject({
  productId: z.string().trim().min(1).max(64),
  channel: z.enum(['wechat', 'alipay']),
  idempotencyKey: z.string().trim().min(8).max(128),
  platform: z.enum(['android', 'ios', 'other']).default('other'),
});

const statusValues = new Set(['created', 'pending', 'paid', 'failed', 'refunded']);

function env(name: string): string | null {
  const value = process.env[name]?.trim();
  return value ? value : null;
}

function readSecret(valueName: string, pathName: string): string | null {
  const inline = env(valueName);
  if (inline) return inline.replaceAll('\\n', '\n');
  const file = env(pathName);
  if (file && existsSync(resolve(file))) return readFileSync(resolve(file), 'utf8');
  return null;
}

function rsaSign(message: string, privateKey: string): string {
  return createSign('RSA-SHA256').update(message, 'utf8').sign(createPrivateKey(privateKey), 'base64');
}

function rsaVerify(message: string, signature: string, publicKey: string): boolean {
  return createVerify('RSA-SHA256').update(message, 'utf8').verify(publicKey, signature, 'base64');
}

function randomNonce(length = 16): string {
  return randomBytes(length).toString('hex').slice(0, 32);
}

function decimalCny(cents: number): string {
  return (cents / 100).toFixed(2);
}

function cnyToCents(value: string): number | null {
  if (!/^\d+(?:\.\d{1,2})?$/.test(value)) return null;
  const [whole, fraction = ''] = value.split('.');
  const cents = Number(`${fraction}00`.slice(0, 2));
  const total = Number(whole) * 100 + cents;
  return Number.isSafeInteger(total) ? total : null;
}

function safeJson(value: string | null): Record<string, unknown> {
  if (!value) return {};
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === 'object' ? parsed as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

function publicOrder(row: OrderRow) {
  return {
    id: row.id,
    productId: row.product_id,
    channel: row.channel,
    amountInCents: row.amount_in_cents,
    idempotencyKey: row.idempotency_key,
    status: statusValues.has(row.status) ? row.status : 'failed',
    providerTradeNo: row.provider_trade_no,
    invoke: safeJson(row.invoke_json),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function ensureSchema(store: Store) {
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS membership_orders(
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      product_id TEXT NOT NULL,
      channel TEXT NOT NULL CHECK(channel IN ('wechat','alipay')),
      amount_in_cents INTEGER NOT NULL,
      idempotency_key TEXT NOT NULL,
      status TEXT NOT NULL,
      provider_trade_no TEXT,
      invoke_json TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(user_id, idempotency_key)
    );
    CREATE INDEX IF NOT EXISTS idx_membership_orders_user ON membership_orders(user_id, created_at DESC);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_membership_orders_provider_trade ON membership_orders(provider_trade_no) WHERE provider_trade_no IS NOT NULL;
    CREATE TABLE IF NOT EXISTS membership_subscriptions(
      user_id TEXT PRIMARY KEY REFERENCES users(id),
      product_id TEXT NOT NULL,
      provider TEXT NOT NULL,
      order_id TEXT NOT NULL UNIQUE REFERENCES membership_orders(id),
      started_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  `);
}

function findOrder(store: Store, id: string): OrderRow | undefined {
  return store.db.prepare('SELECT * FROM membership_orders WHERE id=?').get(id) as OrderRow | undefined;
}

function findOrderByOutTradeNo(store: Store, outTradeNo: string): OrderRow | undefined {
  return findOrder(store, outTradeNo);
}

function updateOrder(store: Store, id: string, values: { status?: string; providerTradeNo?: string | null; invoke?: Record<string, unknown> }) {
  const current = findOrder(store, id);
  check(current, '会员订单不存在', 404);
  const status = values.status ?? current.status;
  const providerTradeNo = values.providerTradeNo === undefined ? current.provider_trade_no : values.providerTradeNo;
  const invokeJson = values.invoke === undefined ? current.invoke_json : JSON.stringify(values.invoke);
  store.db.prepare('UPDATE membership_orders SET status=?,provider_trade_no=?,invoke_json=?,updated_at=? WHERE id=?').run(status, providerTradeNo, invokeJson, store.now(), id);
  return findOrder(store, id)!;
}

function addMonths(timestamp: number, months: number): number {
  const date = new Date(timestamp * 1000);
  const target = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, 1));
  target.setUTCDate(Math.min(date.getUTCDate(), new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate()));
  return Math.floor(target.getTime() / 1000);
}

function grantMembership(store: Store, row: OrderRow) {
  const now = store.now();
  const catalog = getMembershipCatalog(store);
  const product = catalog.plans.find((item) => item.id === row.product_id);
  if (!product) return;
  const current = store.db.prepare('SELECT expires_at FROM membership_subscriptions WHERE user_id=?').get(row.user_id) as { expires_at: number } | undefined;
  const startedAt = current && current.expires_at > now ? current.expires_at : now;
  const expiresAt = addMonths(startedAt, product.months);
  store.db.prepare('INSERT INTO membership_subscriptions(user_id,product_id,provider,order_id,started_at,expires_at,updated_at) VALUES(?,?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET product_id=excluded.product_id,provider=excluded.provider,order_id=excluded.order_id,started_at=excluded.started_at,expires_at=excluded.expires_at,updated_at=excluded.updated_at').run(row.user_id, row.product_id, row.channel, row.id, startedAt, expiresAt, now);
}

function markPaid(store: Store, row: OrderRow, providerTradeNo: string | null) {
  if (row.status !== 'paid') {
    updateOrder(store, row.id, { status: 'paid', providerTradeNo });
    grantMembership(store, row);
  } else if (!row.provider_trade_no && providerTradeNo) {
    updateOrder(store, row.id, { providerTradeNo });
  }
}

const memberEntitlementKeys = [
  'automaticBookkeeping',
  'cloudSync',
  'multiDevice',
  'aiAnalysis',
  'voiceAi',
  'ocr',
  'advancedReport',
  'familyBook',
  'dataExport',
  'basicBackup',
  'adFree',
] as const;

function assistantQuotas(store: Store, userId: string) {
  try {
    const policyRow = store.db.prepare(
      'SELECT data_json FROM assistant_policy WHERE id=1',
    ).get() as { data_json: string } | undefined;
    if (!policyRow) return [];
    const policy = JSON.parse(policyRow.data_json) as {
      memberDailyLimit?: number;
    };
    const limit = Number(policy.memberDailyLimit ?? 0);
    if (!Number.isInteger(limit) || limit <= 0) return [];
    const now = store.now();
    const day = new Date((now + 8 * 3600) * 1000).toISOString().slice(0, 10);
    const used =
      (store.db.prepare(
        'SELECT used FROM assistant_usage WHERE user_id=? AND day=?',
      ).get(userId, day) as { used: number } | undefined)?.used ?? 0;
    const periodStart = Math.floor(
      new Date(`${day}T00:00:00+08:00`).getTime() / 1000,
    );
    const periodEnd = periodStart + 86400;
    return ['voiceAi', 'ocr', 'aiAnalysis'].map(key => ({
      key,
      limit,
      used: Math.min(limit, Math.max(0, used)),
      periodStart,
      periodEnd,
    }));
  } catch {
    // Membership remains usable if the assistant tables are temporarily
    // unavailable during a migration. Model endpoints still enforce limits.
    return [];
  }
}

function membershipCurrent(store: Store, userId: string) {
  const apple = store.db.prepare("SELECT * FROM apple_transactions WHERE user_id=? AND revoked_at IS NULL AND expires_at>? ORDER BY expires_at DESC LIMIT 1").get(userId, store.now()) as { transaction_id:string; product_id:string; purchased_at:number|null; expires_at:number; updated_at:number } | undefined;
  if (apple) {
    return {
      membership: { userId, plan: 'pro', status: 'active', updatedAt: apple.updated_at },
      subscription: { id: apple.transaction_id, userId, provider: 'apple', productId: applePlanForProductId(apple.product_id) ?? apple.product_id, startedAt: apple.purchased_at ?? store.now(), expiresAt: apple.expires_at, autoRenew: false, externalSubscriptionId: apple.transaction_id },
      entitlements: memberEntitlementKeys.map((key) => ({ key, source: 'apple_payment', grantedAt: apple.purchased_at ?? store.now(), expiresAt: apple.expires_at })),
      quotas: assistantQuotas(store, userId),
    };
  }
  const subscription = store.db.prepare('SELECT * FROM membership_subscriptions WHERE user_id=?').get(userId) as { user_id: string; product_id: string; provider: PaymentChannel; order_id: string; started_at: number; expires_at: number; updated_at: number } | undefined;
  if (!subscription) return { membership: { userId, plan: 'free', status: 'active', updatedAt: store.now() }, entitlements: [], quotas: [] };
  const now = store.now();
  const status = subscription.expires_at > now ? 'active' : 'expired';
  return {
    membership: { userId, plan: 'pro', status, updatedAt: subscription.updated_at },
    subscription: { id: subscription.order_id, userId, provider: subscription.provider, productId: subscription.product_id, startedAt: subscription.started_at, expiresAt: subscription.expires_at, autoRenew: false, externalSubscriptionId: subscription.order_id },
    entitlements: status === 'active' ? memberEntitlementKeys.map((key) => ({ key, source: `${subscription.provider}_payment`, grantedAt: subscription.started_at, expiresAt: subscription.expires_at })) : [],
    quotas: status === 'active' ? assistantQuotas(store, userId) : [],
  };
}

async function wechatAppOrder(row: OrderRow): Promise<Record<string, unknown>> {
  const appId = env('WECHAT_APP_ID');
  const mchId = env('WECHAT_MCH_ID');
  const serialNo = env('WECHAT_SERIAL_NO');
  const privateKey = readSecret('WECHAT_PRIVATE_KEY', 'WECHAT_PRIVATE_KEY_PATH');
  const notifyUrl = env('WECHAT_NOTIFY_URL');
  check(appId && mchId && serialNo && privateKey && notifyUrl, '微信支付尚未完成服务端配置', 503);
  check(notifyUrl.startsWith('https://'), '微信支付回调地址必须使用 HTTPS', 503);
  const path = '/v3/pay/transactions/app';
  const payload = {
    appid: appId,
    mchid: mchId,
    description: '好好记账会员',
    out_trade_no: row.id,
    notify_url: notifyUrl,
    amount: { total: row.amount_in_cents, currency: 'CNY' },
  };
  const body = JSON.stringify(payload);
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const nonce = randomNonce();
  const message = `POST\n${path}\n${timestamp}\n${nonce}\n${body}\n`;
  const signature = rsaSign(message, privateKey);
  const authorization = `WECHATPAY2-SHA256-RSA2048 mchid="${mchId}",nonce_str="${nonce}",signature="${signature}",timestamp="${timestamp}",serial_no="${serialNo}"`;
  const apiBase = env('WECHAT_API_BASE_URL') ?? 'https://api.mch.weixin.qq.com';
  const apiUri = new URL(apiBase);
  check(apiUri.protocol === 'https:' || ['127.0.0.1', 'localhost'].includes(apiUri.hostname), '微信支付 API 地址必须使用 HTTPS', 503);
  const response = await fetch(`${apiBase.replace(/\/$/, '')}${path}`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: authorization,
    },
    body,
    signal: AbortSignal.timeout(15000),
  });
  const raw = await response.text();
  let data: Record<string, unknown> = {};
  try { data = JSON.parse(raw) as Record<string, unknown>; } catch { /* handled below */ }
  check(response.ok && typeof data.prepay_id === 'string', '微信支付下单失败，请稍后重试', 502);
  const prepayId = data.prepay_id as string;
  const invokeNonce = randomNonce();
  const invokeTimestamp = Math.floor(Date.now() / 1000).toString();
  const invokeMessage = `${appId}\n${invokeTimestamp}\n${invokeNonce}\n${prepayId}\n`;
  return {
    type: 'wechat_app',
    appId,
    universalLink: env('WECHAT_UNIVERSAL_LINK'),
    partnerId: mchId,
    prepayId,
    packageValue: 'Sign=WXPay',
    nonceStr: invokeNonce,
    timeStamp: invokeTimestamp,
    sign: rsaSign(invokeMessage, privateKey),
  };
}

function alipayQuery(params: Record<string, string>): string {
  return Object.entries(params).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([key, value]) => `${key}=${value}`).join('&');
}

async function alipayAppOrder(row: OrderRow): Promise<Record<string, unknown>> {
  const appId = env('ALIPAY_APP_ID');
  const privateKey = readSecret('ALIPAY_PRIVATE_KEY', 'ALIPAY_PRIVATE_KEY_PATH');
  const notifyUrl = env('ALIPAY_NOTIFY_URL');
  check(appId && privateKey && notifyUrl, '支付宝支付尚未完成服务端配置', 503);
  check(notifyUrl.startsWith('https://'), '支付宝支付回调地址必须使用 HTTPS', 503);
  const params: Record<string, string> = {
    app_id: appId,
    method: 'alipay.trade.app.pay',
    charset: 'utf-8',
    sign_type: 'RSA2',
    timestamp: new Date().toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, ''),
    version: '1.0',
    notify_url: notifyUrl,
    biz_content: JSON.stringify({
      out_trade_no: row.id,
      product_code: 'QUICK_MSECURITY_PAY',
      subject: '好好记账会员',
      total_amount: decimalCny(row.amount_in_cents),
    }),
  };
  const sign = rsaSign(alipayQuery(params), privateKey);
  const orderString = `${Object.entries(params).map(([key, value]) => `${key}=${encodeURIComponent(value)}`).join('&')}&sign=${encodeURIComponent(sign)}`;
  return {
    type: 'alipay_app',
    orderString,
    gateway: env('ALIPAY_GATEWAY') ?? 'https://openapi.alipay.com/gateway.do',
  };
}

function verifyWechatNotification(headers: Record<string, unknown>, rawBody: string): boolean {
  const serial = String(headers['wechatpay-serial'] ?? '');
  const timestamp = String(headers['wechatpay-timestamp'] ?? '');
  const nonce = String(headers['wechatpay-nonce'] ?? '');
  const signature = String(headers['wechatpay-signature'] ?? '');
  const publicKey = readSecret('WECHAT_PLATFORM_PUBLIC_KEY', 'WECHAT_PLATFORM_PUBLIC_KEY_PATH');
  const expectedSerial = env('WECHAT_PLATFORM_SERIAL_NO');
  const timestampNumber = Number(timestamp);
  if (!serial || !timestamp || !nonce || !signature || !publicKey || !expectedSerial) return false;
  if (serial !== expectedSerial || !Number.isInteger(timestampNumber)) return false;
  if (Math.abs(Math.floor(Date.now() / 1000) - timestampNumber) > 300) return false;
  return rsaVerify(`${timestamp}\n${nonce}\n${rawBody}\n`, signature, publicKey);
}

function decryptWechatResource(resource: Record<string, unknown>): Record<string, unknown> {
  check(resource.algorithm === 'AEAD_AES_256_GCM', '微信支付回调加密算法不受支持', 400);
  const apiV3Key = env('WECHAT_API_V3_KEY');
  check(apiV3Key && Buffer.byteLength(apiV3Key, 'utf8') === 32, '微信支付 APIv3 密钥未配置或长度错误', 503);
  const ciphertext = Buffer.from(String(resource.ciphertext ?? ''), 'base64');
  const authTag = ciphertext.subarray(ciphertext.length - 16);
  const encrypted = ciphertext.subarray(0, ciphertext.length - 16);
  const decipher = createDecipheriv('aes-256-gcm', Buffer.from(apiV3Key, 'utf8'), Buffer.from(String(resource.nonce), 'utf8'));
  decipher.setAuthTag(authTag);
  decipher.setAAD(Buffer.from(String(resource.associated_data ?? ''), 'utf8'));
  return JSON.parse(Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8')) as Record<string, unknown>;
}

function parseAlipayNotify(body: unknown): Record<string, string> {
  if (typeof body === 'string') {
    const result: Record<string, string> = {};
    for (const [key, value] of new URLSearchParams(body)) result[key] = value;
    return result;
  }
  if (body && typeof body === 'object') {
    return Object.fromEntries(Object.entries(body as Record<string, unknown>).map(([key, value]) => [key, String(value ?? '')]));
  }
  return {};
}

function verifyAlipayNotify(body: Record<string, string>): boolean {
  const signature = body.sign;
  const publicKey = readSecret('ALIPAY_PUBLIC_KEY', 'ALIPAY_PUBLIC_KEY_PATH');
  if (!signature || !publicKey) return false;
  const content = Object.keys(body).filter((key) => key !== 'sign' && key !== 'sign_type' && body[key] !== '').sort().map((key) => `${key}=${body[key]}`).join('&');
  return rsaVerify(content, signature, publicKey);
}

export function registerPaymentRoutes(app: FastifyInstance, store: Store, authenticate: Authenticate) {
  ensureSchema(store);
  app.post('/api/v1/membership/orders', async (req) => {
    const user = authenticate(req.headers.authorization);
    const input = createOrderSchema.parse(req.body);
    const existing = store.db.prepare('SELECT * FROM membership_orders WHERE user_id=? AND idempotency_key=?').get(user.id, input.idempotencyKey) as OrderRow | undefined;
    if (existing) {
      check(existing.product_id === input.productId && existing.channel === input.channel, '幂等键已用于其他会员订单', 409);
      return publicOrder(existing);
    }
    const catalog = getMembershipCatalog(store);
    const product = catalog.plans.find((item) => item.id === input.productId);
    check(product, '会员套餐不存在或已下架', 404);
    // The amount is always loaded from the server catalog; clients cannot alter it.
    const id = randomUUID().replaceAll('-', '');
    const now = store.now();
    store.db.prepare('INSERT INTO membership_orders(id,user_id,product_id,channel,amount_in_cents,idempotency_key,status,provider_trade_no,invoke_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?,NULL,NULL,?,?)').run(id, user.id, product.id, input.channel, product.priceInCents, input.idempotencyKey, 'created', now, now);
    try {
      const invoke = input.channel === 'wechat' ? await wechatAppOrder({ id, user_id: user.id, product_id: product.id, channel: input.channel, amount_in_cents: product.priceInCents, idempotency_key: input.idempotencyKey, status: 'created', provider_trade_no: null, invoke_json: null, created_at: now, updated_at: now }) : await alipayAppOrder({ id, user_id: user.id, product_id: product.id, channel: input.channel, amount_in_cents: product.priceInCents, idempotency_key: input.idempotencyKey, status: 'created', provider_trade_no: null, invoke_json: null, created_at: now, updated_at: now });
      return publicOrder(updateOrder(store, id, { status: 'pending', invoke }));
    } catch (error) {
      updateOrder(store, id, { status: 'failed' });
      if (error instanceof ApiError) throw error;
      throw new ApiError(502, '支付渠道下单失败，请稍后重试');
    }
  });
  app.get('/api/v1/membership/orders', async (req) => {
    const user = authenticate(req.headers.authorization);
    const rows = store.db.prepare('SELECT * FROM membership_orders WHERE user_id=? ORDER BY created_at DESC LIMIT 50').all(user.id) as OrderRow[];
    return { orders: rows.map(publicOrder) };
  });
  app.get('/api/v1/membership/orders/:id', async (req) => {
    const user = authenticate(req.headers.authorization);
    const id = z.object({ id: z.string().min(1).max(64) }).parse(req.params).id;
    const row = findOrder(store, id);
    check(row && row.user_id === user.id, '会员订单不存在', 404);
    return publicOrder(row);
  });
  app.get('/api/v1/membership/current', async (req) => {
    const user = authenticate(req.headers.authorization);
    return membershipCurrent(store, user.id);
  });
  app.post('/api/v1/payments/wechat/notify', { config: { rawBody: true } }, async (req, reply) => {
    const rawBody = String((req as unknown as { rawBody?: string }).rawBody ?? JSON.stringify(req.body));
    check(verifyWechatNotification(req.headers as Record<string, unknown>, rawBody), '微信支付回调验签失败', 401);
    const envelope = JSON.parse(rawBody) as { resource?: Record<string, unknown> };
    const transaction = decryptWechatResource(envelope.resource ?? {});
    const outTradeNo = String(transaction.out_trade_no ?? '');
    const row = findOrderByOutTradeNo(store, outTradeNo);
    check(row, '会员订单不存在', 404);
    check(String(transaction.amount && (transaction.amount as Record<string, unknown>).total) === String(row.amount_in_cents), '微信支付回调金额不匹配', 400);
    if (transaction.trade_state === 'SUCCESS') {
      markPaid(store, row, String(transaction.transaction_id ?? '') || null);
    } else if (transaction.trade_state === 'CLOSED') {
      updateOrder(store, row.id, { status: 'failed' });
    }
    return reply.send({ code: 'SUCCESS', message: '成功' });
  });
  app.post('/api/v1/payments/alipay/notify', async (req, reply) => {
    const body = parseAlipayNotify(req.body);
    check(verifyAlipayNotify(body), '支付宝支付回调验签失败', 401);
    const row = findOrderByOutTradeNo(store, body.out_trade_no ?? '');
    check(row, '会员订单不存在', 404);
    check(body.app_id === env('ALIPAY_APP_ID'), '支付宝回调应用不匹配', 400);
    check(cnyToCents(body.total_amount ?? '') === row.amount_in_cents, '支付宝回调金额不匹配', 400);
    if (body.trade_status === 'TRADE_SUCCESS' || body.trade_status === 'TRADE_FINISHED') {
      markPaid(store, row, body.trade_no || null);
    }
    return reply.type('text/plain').send('success');
  });
}

export const paymentTestHelpers = { alipayQuery, decimalCny, cnyToCents, verifyAlipayNotify, verifyWechatNotification, decryptWechatResource };
