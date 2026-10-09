import test from "node:test";
import assert from "node:assert/strict";
import { randomUUID, generateKeyPairSync } from "node:crypto";
import { createServer } from "node:http";
import { createApp } from "../src/app.js";
import { encodePassword } from "../src/console/auth.js";
import { integrationValue } from "../src/integrations.js";
import { markPaid } from "../src/payment.js";
import { ApiError } from "../src/contract.js";

test("退款重试复用原参数，已使用时长不扣后来续费的会员期限", async (t) => {
  const names = [
    "WECHAT_APP_ID",
    "WECHAT_MCH_ID",
    "WECHAT_SERIAL_NO",
    "WECHAT_PRIVATE_KEY",
    "WECHAT_API_BASE_URL",
  ];
  const old = names.map((n) => process.env[n]),
    fetcher = globalThis.fetch;
  process.env.WECHAT_APP_ID = "retry-app";
  process.env.WECHAT_MCH_ID = "retry-mch";
  process.env.WECHAT_SERIAL_NO = "retry-serial";
  process.env.WECHAT_API_BASE_URL = "http://127.0.0.1";
  process.env.WECHAT_PRIVATE_KEY = generateKeyPairSync("rsa", {
    modulusLength: 2048,
  })
    .privateKey.export({ type: "pkcs8", format: "pem" })
    .toString();
  const { app, store, headers } = await fixture();
  t.after(async () => {
    await app.close();
    globalThis.fetch = fetcher;
    names.forEach((n, i) => {
      if (old[i] === undefined) delete process.env[n];
      else process.env[n] = old[i];
    });
  });
  const user = (
    await app.inject({
      method: "POST",
      url: "/api/v1/auth/register",
      payload: {
        username: "refund_retry_user",
        password: "refund-retry-password",
      },
    })
  ).json();
  let clock = store.now();
  store.now = () => clock;
  const catalog = (
    await app.inject({ url: "/api/v1/membership/catalog" })
  ).json();
  for (const id of ["first-paid", "second-paid"]) {
    store.db
      .prepare(
        "INSERT INTO membership_orders(id,user_id,product_id,channel,amount_in_cents,idempotency_key,status,created_at,updated_at,product_json) VALUES(?,?,?,?,?,?,?,?,?,?)",
      )
      .run(
        id,
        user.user.id,
        "monthly",
        "wechat",
        800,
        id,
        "pending",
        clock,
        clock,
        JSON.stringify(catalog.plans[0]),
      );
    markPaid(
      store,
      store.db
        .prepare("SELECT * FROM membership_orders WHERE id=?")
        .get(id) as Parameters<typeof markPaid>[1],
      `trade-${id}`,
    );
  }
  const firstGrant = store.db
    .prepare(
      "SELECT expires_at FROM membership_grants WHERE order_id='first-paid'",
    )
    .get() as { expires_at: number };
  clock = firstGrant.expires_at + 86400;
  // Advancing through a membership period also expires the original admin session.
  const renewed = await app.inject({
    method: "POST",
    url: "/api/v1/console/auth/login",
    payload: { username: "commerce_admin", password: "commerce-password-2026" },
  });
  headers.authorization = `Bearer ${renewed.json().data.token}`;
  const expiry = (
    store.db
      .prepare(
        "SELECT expires_at FROM membership_subscriptions WHERE user_id=?",
      )
      .get(user.user.id) as { expires_at: number }
  ).expires_at;
  const requests: Record<string, unknown>[] = [];
  globalThis.fetch = async (_url, options) => {
    const body = JSON.parse(String(options?.body)) as Record<string, unknown>;
    requests.push(body);
    if (requests.length === 1) throw new ApiError(502, "网络超时");
    return new Response(
      JSON.stringify({
        out_trade_no: body.out_trade_no,
        status: "SUCCESS",
        amount: { refund: 800 },
      }),
    );
  };
  const refund = (id: string, reason: string) =>
    app.inject({
      method: "POST",
      url: `/api/v1/console/payments/orders/${id}/refund`,
      headers,
      payload: { reason, confirmed: true },
    });
  assert.equal((await refund("first-paid", "原退款原因")).statusCode, 502);
  assert.equal((await refund("first-paid", "重试")).statusCode, 200);
  assert.deepEqual(requests[0], requests[1], "重试退款不得换编号、金额或原因");
  assert.equal(
    (
      store.db
        .prepare(
          "SELECT expires_at FROM membership_subscriptions WHERE user_id=?",
        )
        .get(user.user.id) as { expires_at: number }
    ).expires_at,
    expiry,
    "已用完的旧订单不会扣后来续费时长",
  );
  assert.equal((await refund("second-paid", "退续费")).statusCode, 200);
  assert.equal(
    (
      store.db
        .prepare(
          "SELECT expires_at FROM membership_subscriptions WHERE user_id=?",
        )
        .get(user.user.id) as { expires_at: number }
    ).expires_at,
    clock,
  );
});

async function fixture() {
  const value = await createApp(":memory:");
  value.store.db
    .prepare(
      "INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)",
    )
    .run(
      randomUUID(),
      "commerce_admin",
      await encodePassword("commerce-password-2026"),
      "super",
      value.store.now(),
    );
  const login = await value.app.inject({
    method: "POST",
    url: "/api/v1/console/auth/login",
    payload: { username: "commerce_admin", password: "commerce-password-2026" },
  });
  return {
    ...value,
    headers: { authorization: `Bearer ${login.json().data.token}` },
  };
}
test("会员草稿发布、冲突、回滚与人工取消的列表筛选保持一致", async (t) => {
  const { app, store, headers } = await fixture();
  t.after(() => app.close());
  const call = (
    path: string,
    body?: Record<string, unknown>,
    method: "GET" | "POST" | "PUT" = body ? "POST" : "GET",
  ) =>
    app.inject({
      url: `/api/v1/console${path}`,
      method,
      headers,
      payload: body,
    });
  assert.equal(
    (await app.inject({ url: "/api/v1/console/membership/catalog" }))
      .statusCode,
    401,
  );
  const initial = (await call("/membership/catalog")).json().data;
  const catalog = structuredClone(initial.catalog);
  catalog.plans[0].priceInCents = 1234;
  catalog.plans[0].aiDailyLimit = 7;
  const saved = await call("/membership/catalog", {
    catalog,
    baseRevision: 0,
    note: "测试调价",
  });
  assert.equal(saved.statusCode, 200, saved.body);
  assert.equal(
    (await app.inject({ url: "/api/v1/membership/catalog" })).json().plans[0]
      .priceInCents,
    800,
    "草稿不改变 APP",
  );
  assert.equal(
    (
      await call("/membership/catalog", {
        catalog,
        baseRevision: 0,
        note: "冲突",
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (
      await call("/membership/catalog/1/publish", {
        publishedHash: initial.publishedHash,
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (await app.inject({ url: "/api/v1/membership/catalog" })).json().plans[0]
      .priceInCents,
    1234,
  );
  assert.equal(
    (
      await call("/membership/catalog/1/publish", {
        publishedHash: initial.publishedHash,
      })
    ).statusCode,
    409,
  );
  const user = (
    await app.inject({
      url: "/api/v1/auth/register",
      method: "POST",
      payload: {
        username: "commerce_user",
        password: "commerce-user-password",
      },
    })
  ).json();
  const adjusted = await call(
    `/membership/users/${user.user.id}`,
    { productId: "monthly", durationDays: 30, reason: "客服补偿" },
    "PUT",
  );
  assert.equal(adjusted.statusCode, 200);
  assert.equal(adjusted.json().data.quotas[0].limit, 7);
  store.db
    .prepare(
      "INSERT INTO membership_orders(id,user_id,product_id,channel,amount_in_cents,idempotency_key,status,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)",
    )
    .run(
      "previous",
      user.user.id,
      "monthly",
      "wechat",
      800,
      "previous-key",
      "paid",
      store.now(),
      store.now(),
    );
  store.db
    .prepare(
      "INSERT INTO membership_subscriptions(user_id,product_id,provider,order_id,started_at,expires_at,updated_at) VALUES(?,?,?,?,?,?,?)",
    )
    .run(
      user.user.id,
      "monthly",
      "wechat",
      "previous",
      store.now(),
      store.now() + 86400,
      store.now(),
    );
  await call(
    `/membership/users/${user.user.id}`,
    { productId: null, durationDays: 0, reason: "人工取消" },
    "PUT",
  );
  const users = (await call("/users?member=no&q=commerce_user")).json().data;
  assert.equal(users.total, 1);
  assert.equal(users.items[0].member, 0);
  assert.equal(
    (await call(`/membership/users/${user.user.id}`)).json().data.history
      .length,
    2,
  );
  const state = (await call("/membership/catalog")).json().data;
  await call("/membership/catalog", {
    catalog: initial.catalog,
    baseRevision: 1,
    note: "恢复原价",
  });
  await call("/membership/catalog/2/publish", {
    publishedHash: state.publishedHash,
  });
  assert.equal(
    (await app.inject({ url: "/api/v1/membership/catalog" })).json().plans[0]
      .priceInCents,
    800,
  );
});
test("接入密钥加密存储、仅写不回显、空值保留，管理权限隔离", async (t) => {
  const old = process.env.INTEGRATION_ENCRYPTION_KEY;
  process.env.INTEGRATION_ENCRYPTION_KEY = "ab".repeat(32);
  t.after(() => {
    if (old === undefined) delete process.env.INTEGRATION_ENCRYPTION_KEY;
    else process.env.INTEGRATION_ENCRYPTION_KEY = old;
  });
  const { app, store, headers } = await fixture();
  t.after(() => app.close());
  const write = async (values: Record<string, string>) =>
    app.inject({
      url: "/api/v1/console/integrations/alipay",
      method: "PUT",
      headers,
      payload: { values },
    });
  const result = await write({
    ALIPAY_APP_ID: "20260001",
    ALIPAY_PRIVATE_KEY: "private-test-value",
  });
  assert.equal(result.statusCode, 200, result.body);
  assert.ok(!result.body.includes("private-test-value"));
  assert.equal(
    integrationValue(store, "ALIPAY_PRIVATE_KEY"),
    "private-test-value",
  );
  const stored = store.db
    .prepare(
      "SELECT value FROM integration_settings WHERE name='ALIPAY_PRIVATE_KEY'",
    )
    .get() as { value: string };
  assert.ok(!stored.value.includes("private-test-value"));
  await write({ ALIPAY_PRIVATE_KEY: "" });
  assert.equal(
    integrationValue(store, "ALIPAY_PRIVATE_KEY"),
    "private-test-value",
  );
  assert.equal(
    (await write({ ALIPAY_NOTIFY_URL: "not-a-url" })).statusCode,
    400,
  );
  store.db.prepare("UPDATE console_admins SET role_id='support'").run();
  assert.equal((await write({ ALIPAY_APP_ID: "forbidden" })).statusCode, 403);
});
test("主动查单补发会员、重复查询不重复发放、整单退款扣回该订单时长", async (t) => {
  const names = [
    "WECHAT_APP_ID",
    "WECHAT_MCH_ID",
    "WECHAT_SERIAL_NO",
    "WECHAT_PRIVATE_KEY",
    "WECHAT_API_BASE_URL",
    "ALL_FEATURES_FREE_FOR_TESTING",
  ];
  const old = Object.fromEntries(names.map((n) => [n, process.env[n]]));
  t.after(() => {
    for (const [n, v] of Object.entries(old))
      if (v === undefined) delete process.env[n];
      else process.env[n] = v;
  });
  process.env.ALL_FEATURES_FREE_FOR_TESTING = "false";
  process.env.WECHAT_APP_ID = "wx-reconcile";
  process.env.WECHAT_MCH_ID = "merchant-reconcile";
  process.env.WECHAT_SERIAL_NO = "serial";
  process.env.WECHAT_PRIVATE_KEY = generateKeyPairSync("rsa", {
    modulusLength: 2048,
  })
    .privateKey.export({ type: "pkcs8", format: "pem" })
    .toString();
  const { app, store, headers } = await fixture();
  t.after(() => app.close());
  const user = (
    await app.inject({
      url: "/api/v1/auth/register",
      method: "POST",
      payload: {
        username: "reconcile_user",
        password: "reconcile-user-password",
      },
    })
  ).json();
  const id = "a".repeat(32),
    now = store.now(),
    catalog = (await app.inject({ url: "/api/v1/membership/catalog" })).json();
  store.db
    .prepare(
      "INSERT INTO membership_orders(id,user_id,product_id,channel,amount_in_cents,idempotency_key,status,created_at,updated_at,product_json) VALUES(?,?,?,?,?,?,?,?,?,?)",
    )
    .run(
      id,
      user.user.id,
      "monthly",
      "wechat",
      800,
      "reconcile-order",
      "pending",
      now,
      now,
      JSON.stringify(catalog.plans[0]),
    );
  let queryCalls = 0;
  const mock = createServer((req, res) => {
    res.setHeader("content-type", "application/json");
    if (req.method === "GET" && req.url?.includes("/transactions/")) {
      queryCalls++;
      res.end(
        JSON.stringify({
          out_trade_no: id,
          appid: "wx-reconcile",
          mchid: "merchant-reconcile",
          trade_state: "SUCCESS",
          transaction_id: "provider-1",
          amount: { total: 800, currency: "CNY" },
        }),
      );
    } else
      res.end(
        JSON.stringify({
          out_trade_no: id,
          status: "SUCCESS",
          amount: { refund: 800 },
        }),
      );
  });
  await new Promise<void>((r) => mock.listen(0, "127.0.0.1", r));
  t.after(() => new Promise<void>((r) => mock.close(() => r())));
  const address = mock.address();
  assert.ok(address && typeof address === "object");
  process.env.WECHAT_API_BASE_URL = `http://127.0.0.1:${address.port}`;
  const refresh = () =>
    app.inject({
      url: `/api/v1/membership/orders/${id}/refresh`,
      method: "POST",
      headers: { authorization: `Bearer ${user.token}` },
    });
  assert.equal((await refresh()).json().status, "paid");
  const current = () =>
    app.inject({
      url: "/api/v1/membership/current",
      headers: { authorization: `Bearer ${user.token}` },
    });
  const expiry = (await current()).json().subscription.expiresAt;
  await refresh();
  assert.equal(queryCalls, 1);
  assert.equal((await current()).json().subscription.expiresAt, expiry);
  const refund = await app.inject({
    url: `/api/v1/console/payments/orders/${id}/refund`,
    method: "POST",
    headers,
    payload: { reason: "测试退款", confirmed: true },
  });
  assert.equal(refund.statusCode, 200, refund.body);
  assert.equal(refund.json().data.status, "refunded");
  assert.equal((await current()).json().entitlements.length, 0);
});
