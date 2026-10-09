import type { FastifyInstance } from "fastify";
import { createHash } from "node:crypto";
import { z } from "zod";
import type { Store } from "./store.js";
import { ApiError, requireCondition as check } from "./contract.js";
import {
  findOrder,
  markPaid,
  paymentCrypto as crypto,
  publicOrder,
  updateOrder,
  type OrderRow,
} from "./payment.js";
import { authorize, auditAction } from "./console/auth.js";
import { paginate, pageQuery } from "./console/query.js";

const loopback = (url: URL) =>
  process.env.NODE_ENV !== "production" &&
  ["127.0.0.1", "localhost"].includes(url.hostname);
export async function wechatRequest(
  store: Store,
  method: string,
  path: string,
  payload?: unknown,
) {
  const { env, readSecret, rsaSign, randomNonce } = crypto;
  const mchId = env("WECHAT_MCH_ID", store),
    serial = env("WECHAT_SERIAL_NO", store),
    key = readSecret("WECHAT_PRIVATE_KEY", "WECHAT_PRIVATE_KEY_PATH", store);
  check(mchId && serial && key, "微信支付配置不完整", 503);
  const url = new URL(
    process.env.WECHAT_API_BASE_URL ?? "https://api.mch.weixin.qq.com",
  );
  check(
    url.protocol === "https:" || loopback(url),
    "支付网关必须使用 HTTPS",
    503,
  );
  const body = payload === undefined ? "" : JSON.stringify(payload),
    timestamp = String(Math.floor(Date.now() / 1000)),
    nonce = randomNonce();
  const signature = rsaSign(
    `${method}\n${path}\n${timestamp}\n${nonce}\n${body}\n`,
    key,
  );
  const response = await fetch(`${url.origin}${path}`, {
    method,
    redirect: "error",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: `WECHATPAY2-SHA256-RSA2048 mchid="${mchId}",nonce_str="${nonce}",signature="${signature}",timestamp="${timestamp}",serial_no="${serial}"`,
    },
    body: body || undefined,
    signal: AbortSignal.timeout(15000),
  });
  const raw = await response.text();
  if (!loopback(url))
    check(
      crypto.verifyWechatNotification(
        Object.fromEntries(response.headers.entries()),
        raw,
        store,
      ),
      "微信支付响应验签失败",
      502,
    );
  check(response.ok, "微信支付渠道请求失败，请查询订单状态后重试", 502);
  return raw ? (JSON.parse(raw) as Record<string, unknown>) : {};
}
function signedObject(raw: string, name: string) {
  const label = raw.indexOf(JSON.stringify(name));
  check(label >= 0, "支付宝响应格式无效", 502);
  const start = raw.indexOf("{", label);
  let depth = 0,
    quoted = false,
    escaped = false;
  for (let i = start; i < raw.length; i++) {
    const ch = raw[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (quoted && ch === "\\") {
      escaped = true;
      continue;
    }
    if (ch === '"') {
      quoted = !quoted;
      continue;
    }
    if (quoted) continue;
    if (ch === "{") depth++;
    if (ch === "}" && --depth === 0) return raw.slice(start, i + 1);
  }
  throw new ApiError(502, "支付宝响应格式无效");
}
export async function alipayRequest(
  store: Store,
  method: string,
  biz: Record<string, unknown>,
) {
  const { env, readSecret, rsaSign, rsaVerify, alipayQuery } = crypto;
  const appId = env("ALIPAY_APP_ID", store),
    key = readSecret("ALIPAY_PRIVATE_KEY", "ALIPAY_PRIVATE_KEY_PATH", store),
    publicKey = readSecret(
      "ALIPAY_PUBLIC_KEY",
      "ALIPAY_PUBLIC_KEY_PATH",
      store,
    );
  check(appId && key && publicKey, "支付宝配置不完整", 503);
  const url = new URL(
    process.env.ALIPAY_GATEWAY ?? "https://openapi.alipay.com/gateway.do",
  );
  check(
    url.protocol === "https:" || loopback(url),
    "支付网关必须使用 HTTPS",
    503,
  );
  const timestamp = new Date(Date.now() + 8 * 3600000)
    .toISOString()
    .replace("T", " ")
    .slice(0, 19);
  const params = {
    app_id: appId,
    method,
    charset: "utf-8",
    sign_type: "RSA2",
    timestamp,
    version: "1.0",
    biz_content: JSON.stringify(biz),
  };
  const signature = rsaSign(alipayQuery(params), key);
  const response = await fetch(url, {
    method: "POST",
    redirect: "error",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
    },
    body: new URLSearchParams({ ...params, sign: signature }),
    signal: AbortSignal.timeout(15000),
  });
  const raw = await response.text(),
    data = JSON.parse(raw) as Record<string, unknown>,
    name = `${method.replaceAll(".", "_")}_response`;
  check(
    response.ok &&
      typeof data.sign === "string" &&
      rsaVerify(signedObject(raw, name), data.sign, publicKey),
    "支付宝响应验签失败",
    502,
  );
  const result = data[name] as Record<string, unknown>;
  check(
    result?.code === "10000",
    "支付宝渠道请求失败，请查询订单状态后重试",
    502,
  );
  return result;
}
export async function reconcileOrder(store: Store, id: string) {
  const row = findOrder(store, id);
  check(row, "订单不存在", 404);
  if (["paid", "refunded"].includes(row.status)) return row;
  const result =
    row.channel === "wechat"
      ? await wechatRequest(
          store,
          "GET",
          `/v3/pay/transactions/out-trade-no/${encodeURIComponent(id)}?mchid=${encodeURIComponent(crypto.env("WECHAT_MCH_ID", store) ?? "")}`,
        )
      : await alipayRequest(store, "alipay.trade.query", { out_trade_no: id });
  check(result.out_trade_no === id, "渠道返回的订单号不匹配", 502);
  if (row.channel === "wechat") {
    check(
      result.appid === crypto.env("WECHAT_APP_ID", store) &&
        result.mchid === crypto.env("WECHAT_MCH_ID", store),
      "微信交易归属不匹配",
      502,
    );
    const amount = result.amount as { total: number; currency: string };
    check(
      amount?.total === row.amount_in_cents && amount.currency === "CNY",
      "交易金额不匹配",
      502,
    );
    if (result.trade_state === "SUCCESS")
      markPaid(store, row, String(result.transaction_id));
    else if (
      ["CLOSED", "REVOKED", "PAYERROR"].includes(String(result.trade_state)) &&
      !["paid", "refunded"].includes(findOrder(store, id)!.status)
    )
      updateOrder(store, id, { status: "failed" });
  } else {
    check(
      crypto.cnyToCents(String(result.total_amount)) === row.amount_in_cents,
      "交易金额不匹配",
      502,
    );
    const seller = crypto.env("ALIPAY_SELLER_ID", store);
    check(!seller || result.seller_id === seller, "交易卖家不匹配", 502);
    if (
      ["TRADE_SUCCESS", "TRADE_FINISHED"].includes(String(result.trade_status))
    )
      markPaid(store, row, String(result.trade_no));
    else if (
      result.trade_status === "TRADE_CLOSED" &&
      !["paid", "refunded"].includes(findOrder(store, id)!.status)
    )
      updateOrder(store, id, { status: "failed" });
  }
  return findOrder(store, id)!;
}
function applyRefund(store: Store, row: OrderRow) {
  store.db.transaction(() => {
    if (findOrder(store, row.id)!.status === "refunded") return;
    const grant = store.db
      .prepare("SELECT * FROM membership_grants WHERE order_id=?")
      .get(row.id) as
      | { version_id: string; renewal_from: number; expires_at: number }
      | undefined;
    check(grant, "旧订单缺少权益发放记录，需要人工审核后处理", 409);
    const remaining = Math.max(
      0,
      grant.expires_at - Math.max(store.now(), grant.renewal_from),
    );
    store.db
      .prepare(
        "UPDATE membership_subscriptions SET expires_at=MAX(?,expires_at-?),updated_at=? WHERE user_id=?",
      )
      .run(store.now(), remaining, store.now(), row.user_id);
    // Move later renewal periods forward after removing this order's unused time.
    store.db
      .prepare(
        "UPDATE membership_grants SET renewal_from=MAX(?,renewal_from-?),expires_at=MAX(?,expires_at-?) WHERE user_id=? AND order_id<>? AND renewal_from>=?",
      )
      .run(
        store.now(),
        remaining,
        store.now(),
        remaining,
        row.user_id,
        row.id,
        grant.expires_at,
      );
    updateOrder(store, row.id, { status: "refunded" });
    store.db
      .prepare(
        "UPDATE membership_refunds SET status='succeeded',updated_at=? WHERE order_id=?",
      )
      .run(store.now(), row.id);
  })();
}
type Refund = { id: string; order_id: string; status: string; reason: string };
async function queryRefund(store: Store, row: OrderRow, refund: Refund) {
  const result =
    row.channel === "wechat"
      ? await wechatRequest(
          store,
          "GET",
          `/v3/refund/domestic/refunds/${encodeURIComponent(refund.id)}`,
        )
      : await alipayRequest(store, "alipay.trade.fastpay.refund.query", {
          out_trade_no: row.id,
          out_request_no: refund.id,
        });
  check(result.out_trade_no === row.id, "退款订单不匹配", 502);
  const cents =
    row.channel === "wechat"
      ? (result.amount as { refund: number })?.refund
      : crypto.cnyToCents(String(result.refund_amount));
  check(cents === row.amount_in_cents, "退款金额不匹配", 502);
  if (result.status === "SUCCESS" || result.refund_status === "REFUND_SUCCESS")
    applyRefund(store, row);
  else if (["CLOSED", "ABNORMAL"].includes(String(result.status)))
    store.db
      .prepare(
        "UPDATE membership_refunds SET status='failed',updated_at=? WHERE id=?",
      )
      .run(store.now(), refund.id);
  return findOrder(store, row.id)!;
}
export function registerPaymentOperations(
  app: FastifyInstance,
  store: Store,
  authenticate: (header: string | undefined) => { id: string },
) {
  store.db.exec(
    "CREATE TABLE IF NOT EXISTS membership_refunds(id TEXT PRIMARY KEY,order_id TEXT NOT NULL UNIQUE,amount_in_cents INTEGER NOT NULL,status TEXT NOT NULL,reason TEXT NOT NULL,actor_id TEXT NOT NULL,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL)",
  );
  const active = new Set<string>();
  const guarded = async <T>(id: string, run: () => Promise<T>) => {
    check(!active.has(id), "订单正在处理，请稍后刷新", 409);
    active.add(id);
    try {
      return await run();
    } finally {
      active.delete(id);
    }
  };
  const routeId = (params: unknown) =>
    z.object({ id: z.string().regex(/^[a-zA-Z0-9_-]{1,64}$/) }).parse(params)
      .id;
  let working = false;
  const reconcilePending = async () => {
    if (working) return;
    working = true;
    try {
      const rows = store.db
        .prepare(
          "SELECT o.id,r.id AS refundId FROM membership_orders o LEFT JOIN membership_refunds r ON r.order_id=o.id WHERE (o.status='pending' OR r.status='requested') AND o.updated_at<? AND o.created_at>? ORDER BY o.updated_at LIMIT 20",
        )
        .all(store.now() - 60, store.now() - 7 * 86400) as {
        id: string;
        refundId: string | null;
      }[];
      for (const row of rows) {
        if (active.has(row.id)) continue;
        try {
          await guarded(row.id, async () => {
            const order = findOrder(store, row.id)!;
            const refund = store.db
              .prepare("SELECT * FROM membership_refunds WHERE id=?")
              .get(row.refundId ?? "") as Refund | undefined;
            if (refund) await queryRefund(store, order, refund);
            else await reconcileOrder(store, row.id);
          });
        } catch {
          /* Manual refresh remains available; provider failure must not change payment state. */
        }
      }
    } finally {
      working = false;
    }
  };
  const timer =
    process.env.PAYMENT_RECONCILE_ENABLED === "true"
      ? setInterval(() => void reconcilePending(), 60000)
      : undefined;
  timer?.unref();
  app.addHook("onClose", async () => {
    if (timer) clearInterval(timer);
  });
  app.post(
    "/api/v1/payments/wechat/refund-notify",
    { config: { rawBody: true } },
    async (req, reply) => {
      const raw = String(
        (req as unknown as { rawBody?: string }).rawBody ?? "",
      );
      check(
        crypto.verifyWechatNotification(
          req.headers as Record<string, unknown>,
          raw,
          store,
        ),
        "退款回调验签失败",
        401,
      );
      const result = crypto.decryptWechatResource(
        (JSON.parse(raw) as { resource: Record<string, unknown> }).resource,
        store,
      );
      const row = findOrder(store, String(result.out_trade_no));
      check(row && row.channel === "wechat", "退款订单不存在", 404);
      const refund = store.db
        .prepare("SELECT * FROM membership_refunds WHERE order_id=? AND id=?")
        .get(row.id, String(result.out_refund_no)) as Refund | undefined;
      check(refund, "退款请求不存在", 404);
      check(
        (result.amount as { refund: number })?.refund === row.amount_in_cents,
        "退款金额不匹配",
        400,
      );
      check(
        result.mchid === crypto.env("WECHAT_MCH_ID", store),
        "退款商户不匹配",
        400,
      );
      if (result.refund_status === "SUCCESS") applyRefund(store, row);
      return reply.send({ code: "SUCCESS", message: "成功" });
    },
  );
  app.post("/api/v1/membership/orders/:id/refresh", async (req) => {
    const user = authenticate(req.headers.authorization),
      id = routeId(req.params),
      row = findOrder(store, id);
    check(row?.user_id === user.id, "订单不存在", 404);
    return publicOrder(await guarded(id, () => reconcileOrder(store, id)));
  });
  app.get("/api/v1/console/payments/orders", async (req) => {
    authorize(store, req, "payment:view");
    const query = pageQuery
      .extend({
        status: z
          .enum(["created", "pending", "paid", "failed", "refunded"])
          .optional(),
        channel: z.enum(["wechat", "alipay"]).optional(),
        userId: z.string().max(100).optional(),
      })
      .parse(req.query);
    const filters = ["(o.id LIKE ? OR u.username LIKE ?)"],
      args: unknown[] = [`%${query.q}%`, `%${query.q}%`];
    for (const [name, value] of [
      ["status", query.status],
      ["channel", query.channel],
      ["user_id", query.userId],
    ])
      if (value) {
        filters.push(`o.${name}=?`);
        args.push(value);
      }
    return {
      data: paginate(
        store,
        query,
        "SELECT o.id,o.user_id AS userId,u.username,o.product_id AS productId,json_extract(o.product_json,'$.title') AS productTitle,o.channel,o.amount_in_cents AS amountInCents,o.status,o.provider_trade_no AS providerTradeNo,o.created_at AS createdAt,r.status AS refundStatus,r.id AS refundId",
        `FROM membership_orders o JOIN users u ON u.id=o.user_id LEFT JOIN membership_refunds r ON r.order_id=o.id WHERE ${filters.join(" AND ")}`,
        args,
        "o.created_at DESC",
      ),
    };
  });
  app.post("/api/v1/console/payments/orders/:id/refresh", async (req) => {
    const admin = authorize(store, req, "payment:reconcile"),
      id = routeId(req.params);
    const row = await guarded(id, async () => {
      const refund = store.db
        .prepare("SELECT * FROM membership_refunds WHERE order_id=?")
        .get(id) as Refund | undefined;
      const order = findOrder(store, id);
      check(order, "订单不存在", 404);
      return refund && refund.status === "requested"
        ? queryRefund(store, order, refund)
        : reconcileOrder(store, id);
    });
    auditAction(store, admin, "payment:reconcile", id);
    return { data: publicOrder(row) };
  });
  app.post("/api/v1/console/payments/orders/:id/close", async (req) => {
    const admin = authorize(store, req, "payment:reconcile"),
      id = routeId(req.params);
    return guarded(id, async () => {
      const row = await reconcileOrder(store, id);
      check(
        !["paid", "refunded"].includes(row.status),
        "已支付订单不能关闭",
        409,
      );
      if (row.status !== "failed") {
        if (row.channel === "wechat")
          await wechatRequest(
            store,
            "POST",
            `/v3/pay/transactions/out-trade-no/${encodeURIComponent(id)}/close`,
            { mchid: crypto.env("WECHAT_MCH_ID", store) },
          );
        else
          await alipayRequest(store, "alipay.trade.close", {
            out_trade_no: id,
          });
      }
      const latest = findOrder(store, id)!;
      if (!["paid", "refunded"].includes(latest.status))
        updateOrder(store, id, { status: "failed" });
      auditAction(store, admin, "payment:close", id);
      return { data: publicOrder(findOrder(store, id)!) };
    });
  });
  app.post("/api/v1/console/payments/orders/:id/refund", async (req) => {
    const admin = authorize(store, req, "payment:refund"),
      id = routeId(req.params);
    const { reason } = z
      .strictObject({
        reason: z.string().trim().min(1).max(80),
        confirmed: z.literal(true),
      })
      .parse(req.body);
    return guarded(id, async () => {
      const row = findOrder(store, id);
      check(row && row.status === "paid", "只可退已支付订单", 409);
      check(
        store.db
          .prepare("SELECT 1 FROM membership_grants WHERE order_id=?")
          .get(id),
        "旧订单缺少权益发放记录，需要人工审核后处理",
        409,
      );
      const refund = store.db
        .prepare("SELECT * FROM membership_refunds WHERE order_id=?")
        .get(id) as Refund | undefined;
      const refundId =
        refund?.id ??
        `r${createHash("sha256").update(id).digest("hex").slice(0, 31)}`;
      if (!refund)
        store.db
          .prepare(
            "INSERT INTO membership_refunds VALUES(?,?,?,'requested',?,?,?,?)",
          )
          .run(
            refundId,
            id,
            row.amount_in_cents,
            reason,
            admin.id,
            store.now(),
            store.now(),
          );
      store.db
        .prepare(
          "UPDATE membership_refunds SET status='requested',updated_at=? WHERE id=?",
        )
        .run(store.now(), refundId);
      auditAction(store, admin, "payment:refund-request", id);
      const notifyUrl = crypto.env("WECHAT_REFUND_NOTIFY_URL", store);
      const result =
        row.channel === "wechat"
          ? await wechatRequest(store, "POST", "/v3/refund/domestic/refunds", {
              out_trade_no: id,
              out_refund_no: refundId,
              reason: refund?.reason ?? reason,
              ...(notifyUrl ? { notify_url: notifyUrl } : {}),
              amount: {
                refund: row.amount_in_cents,
                total: row.amount_in_cents,
                currency: "CNY",
              },
            })
          : await alipayRequest(store, "alipay.trade.refund", {
              out_trade_no: id,
              out_request_no: refundId,
              refund_amount: crypto.decimalCny(row.amount_in_cents),
              refund_reason: refund?.reason ?? reason,
            });
      check(result.out_trade_no === id, "退款订单不匹配", 502);
      if (row.channel === "alipay") {
        check(
          crypto.cnyToCents(String(result.refund_fee)) === row.amount_in_cents,
          "退款金额不匹配",
          502,
        );
        applyRefund(store, row);
      } else if (result.status === "SUCCESS") {
        check(
          (result.amount as { refund: number })?.refund === row.amount_in_cents,
          "退款金额不匹配",
          502,
        );
        applyRefund(store, row);
      }
      return { data: publicOrder(findOrder(store, id)!) };
    });
  });
}
