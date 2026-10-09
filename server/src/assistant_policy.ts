import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { createHash, timingSafeEqual } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "./store.js";
import {
  hasMembershipEntitlement,
  membershipAiDailyLimit,
  membershipCurrent,
} from "./payment.js";
import { allFeaturesFreeForTesting } from "./testing_access.js";
import { ApiError, requireCondition as check } from "./contract.js";
import {
  AssistantModelUnavailable,
  DeepSeekCompatibleProvider,
  type AssistantModelProvider,
} from "./assistant_ai.js";
import {
  assistantHardPrompt,
  transactionPrompt,
  outOfScope,
  assistantQueryFeature,
} from "./assistant_boundary.js";
import {
  queryPlanRequest, queryPlanResponse, queryPlanPrompt,
  interpretationRequest, interpretationResponse, interpretationPrompt,
} from "./assistant_analysis.js";
export { outOfScope } from "./assistant_boundary.js";

const feature = z.enum(["export", "summary", "voice", "ocr"]);
const voiceParseRequestSchema = z.strictObject({
  requestId: z.string().trim().min(16).max(100),
  text: z.string().trim().min(1).max(2000),
  schemaVersion: z.literal("voice_transaction_v1"),
  now: z.string().datetime({ offset: true }).optional(),
  timezoneOffsetMinutes: z.number().int().min(-720).max(840).optional(),
  source: z.enum(["voice", "ocr", "natural-language"]).default("voice"),
});
const voiceTransactionSchema = z.strictObject({
  type: z.enum(["expense", "income"]),
  amount: z.number().finite().positive().max(999999999999).multipleOf(0.01),
  category: z.string().trim().min(1).max(40),
  subcategory: z.string().trim().min(1).max(40).nullable().optional(),
  account: z.string().trim().min(1).max(80),
  merchant: z.string().trim().min(1).max(120).nullable().optional(),
  occurredAt: z.string().datetime({ offset: true }),
  confidence: z.number().finite().min(0).max(1),
  rawFragment: z.string().max(500),
});
const voiceTransactionsSchema = z.array(voiceTransactionSchema).min(1).max(30);
export const assistantPolicySchema = z.strictObject({
  enabled: z.boolean(),
  systemPrompt: z.string().trim().min(30).max(8000),
  boundaryReply: z.string().trim().min(1).max(500),
  maxInputLength: z.number().int().min(20).max(2000),
  freeDailyLimit: z.number().int().min(0).max(10000),
  memberDailyLimit: z.number().int().min(0).max(10000),
  requestsPerMinute: z.number().int().min(1).max(60),
  memberFeatures: z
    .array(feature)
    .max(4)
    .refine((v) => new Set(v).size === v.length),
  maxTransactions: z.number().int().min(1).max(30).default(30),
  maxImageMb: z.number().int().min(1).max(20).default(10),
  maxImportFileMb: z.number().int().min(1).max(50).default(20),
  maxImportRows: z.number().int().min(1).max(10000).default(10000),
});
export const readAssistantPolicy = (store: Store) =>
  assistantPolicySchema.parse(
    JSON.parse(
      (
        store.db
          .prepare("SELECT data_json FROM assistant_policy WHERE id=1")
          .get() as { data_json: string }
      ).data_json,
    ),
  );
export const assistantRequestSchema = z
  .strictObject({
    requestId: z.string().trim().min(16).max(100),
    text: z.string().trim().min(1).max(2000).optional(),
    feature: feature.optional(),
  })
  .refine(
    (v) => (v.text !== undefined) !== (v.feature !== undefined),
    "必须且只能提供文本或功能",
  );

type AssistantRequest = z.infer<typeof assistantRequestSchema>;
type AssistantPolicy = z.infer<typeof assistantPolicySchema>;
type AuthorizationResult = {
  requestId: string;
  allowed: boolean;
  message: string;
  requiresMembership: boolean;
  remaining: number;
  day?: string;
  member?: boolean;
};

export function registerAssistantPolicy(
  app: FastifyInstance,
  store: Store,
  authenticate: (header: string | undefined) => { id: string },
  modelProvider: AssistantModelProvider = new DeepSeekCompatibleProvider(),
) {
  const pendingModels = new Map<
    string,
    { hash: string; result: Promise<unknown> }
  >();
  const once = async (
    key: string,
    body: unknown,
    run: () => Promise<unknown>,
  ) => {
    const hash = createHash("sha256")
        .update(JSON.stringify(body))
        .digest("hex"),
      pending = pendingModels.get(key);
    if (pending) {
      check(pending.hash === hash, "请求标识已用于其他内容", 409);
      return pending.result;
    }
    const result = Promise.resolve().then(run);
    pendingModels.set(key, { hash, result });
    try {
      return await result;
    } finally {
      pendingModels.delete(key);
    }
  };
  store.db.exec(`
    CREATE TABLE IF NOT EXISTS assistant_policy(id INTEGER PRIMARY KEY CHECK(id=1),data_json TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS assistant_memberships(user_id TEXT PRIMARY KEY REFERENCES users(id),expires_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS assistant_usage(user_id TEXT NOT NULL REFERENCES users(id),day TEXT NOT NULL,used INTEGER NOT NULL,PRIMARY KEY(user_id,day));
    CREATE TABLE IF NOT EXISTS assistant_requests(user_id TEXT NOT NULL REFERENCES users(id),request_id TEXT NOT NULL,body_hash TEXT NOT NULL,created_at INTEGER NOT NULL,result_json TEXT NOT NULL,PRIMARY KEY(user_id,request_id));
    CREATE TABLE IF NOT EXISTS assistant_chat_responses(user_id TEXT NOT NULL REFERENCES users(id),request_id TEXT NOT NULL,body_hash TEXT NOT NULL,created_at INTEGER NOT NULL,result_json TEXT NOT NULL,PRIMARY KEY(user_id,request_id));
    CREATE TABLE IF NOT EXISTS assistant_parse_responses(user_id TEXT NOT NULL REFERENCES users(id),request_id TEXT NOT NULL,body_hash TEXT NOT NULL,created_at INTEGER NOT NULL,result_json TEXT NOT NULL,PRIMARY KEY(user_id,request_id));
  `);
  const requestColumns = store.db
    .prepare("PRAGMA table_info(assistant_requests)")
    .all() as Array<{ name: string }>;
  if (!requestColumns.some((c) => c.name === "refunded"))
    store.db.exec(
      "ALTER TABLE assistant_requests ADD COLUMN refunded INTEGER NOT NULL DEFAULT 0",
    );
  const source = [
    resolve(process.cwd(), "assets/config/assistant_policy.json"),
    resolve(process.cwd(), "../assets/config/assistant_policy.json"),
  ].find(existsSync);
  check(source, "助手默认配置文件不存在", 500);
  const defaults = assistantPolicySchema.parse(
    JSON.parse(readFileSync(source!, "utf8")),
  );
  store.db
    .prepare("INSERT OR IGNORE INTO assistant_policy VALUES(1,?)")
    .run(JSON.stringify(defaults));
  const policy = (): AssistantPolicy => readAssistantPolicy(store);
  const admin = (authorization: string | undefined) => {
    const secret = process.env.ASSISTANT_ADMIN_TOKEN;
    check(secret && secret.length >= 32, "助手配置管理尚未启用", 503);
    const expected = Buffer.from(`Bearer ${secret}`),
      supplied = Buffer.from(authorization ?? "");
    check(
      expected.length === supplied.length &&
        timingSafeEqual(expected, supplied),
      "无助手配置管理权限",
      403,
    );
  };

  const hasActiveMembership = (userId: string, now: number): boolean => {
    if (allFeaturesFreeForTesting()) return true;
    if (
      store.db
        .prepare(
          "SELECT 1 FROM assistant_memberships WHERE user_id=? AND expires_at>?",
        )
        .get(userId, now)
    )
      return true;
    try {
      const member = membershipCurrent(store, userId);
      if (
        member.membership.plan !== "free" &&
        member.membership.status === "active"
      )
        return true;
    } catch {
      // Payment tables may not exist in isolated assistant tests.
    }
    return false;
  };

  const authorize = (
    userId: string,
    body: AssistantRequest,
  ): AuthorizationResult => {
    const bodyHash = createHash("sha256")
      .update(JSON.stringify(body))
      .digest("hex");
    return store.db.transaction(() => {
      const p = policy(),
        now = store.now();
      const day = new Date((now + 8 * 3600) * 1000).toISOString().slice(0, 10);
      const member = hasActiveMembership(userId, now);
      const limit = member
        ? (membershipAiDailyLimit(store, userId) ?? p.memberDailyLimit)
        : p.freeDailyLimit;
      const used =
        (
          store.db
            .prepare(
              "SELECT used FROM assistant_usage WHERE user_id=? AND day=?",
            )
            .get(userId, day) as { used: number } | undefined
        )?.used ?? 0;
      if (!p.enabled)
        return {
          requestId: body.requestId,
          allowed: false,
          message: "记账助手暂时停用",
          requiresMembership: false,
          remaining: Math.max(0, limit - used),
          day,
          member,
        };
      const replay = store.db
        .prepare(
          "SELECT body_hash,result_json,refunded FROM assistant_requests WHERE user_id=? AND request_id=?",
        )
        .get(userId, body.requestId) as
        | { body_hash: string; result_json: string; refunded: number }
        | undefined;
      if (replay) {
        check(replay.body_hash === bodyHash, "请求标识已用于其他内容", 409);
        if (!replay.refunded)
          return JSON.parse(replay.result_json) as AuthorizationResult;
      }
      const recent = (
        store.db
          .prepare(
            "SELECT COUNT(*) count FROM assistant_requests WHERE user_id=? AND created_at>?",
          )
          .get(userId, now - 60) as { count: number }
      ).count;
      check(recent < p.requestsPerMinute, "发送太快，请稍后再试", 429);
      let allowed = true,
        message = "",
        requiresMembership = false,
        nextUsed = used;
      const requestedFeature =
        body.feature ??
        (body.text ? assistantQueryFeature(body.text) : undefined);
      const entitlement =
        requestedFeature === "voice"
          ? "voiceAi"
          : requestedFeature === "ocr"
            ? "ocr"
            : requestedFeature === "export"
              ? "dataExport"
              : null;
      const entitled = entitlement
        ? hasMembershipEntitlement(store, userId, entitlement) ||
          Boolean(
            store.db
              .prepare(
                "SELECT 1 FROM assistant_memberships WHERE user_id=? AND expires_at>?",
              )
              .get(userId, now),
          )
        : member;
      if (
        requestedFeature &&
        p.memberFeatures.includes(requestedFeature) &&
        !entitled
      ) {
        allowed = false;
        message = "该功能需要会员，开通后可继续使用";
        requiresMembership = true;
      } else if (body.text) {
        if (Array.from(body.text).length > p.maxInputLength) {
          allowed = false;
          message = `单条消息最多${p.maxInputLength}字`;
        } else if (outOfScope(body.text)) {
          allowed = false;
          message = p.boundaryReply;
        } else if (used >= limit) {
          allowed = false;
          message = `今日助手次数已用完（${limit}次）`;
          requiresMembership = !member && p.memberDailyLimit > limit;
        } else {
          nextUsed++;
          store.db
            .prepare(
              "INSERT INTO assistant_usage VALUES(?,?,1) ON CONFLICT(user_id,day) DO UPDATE SET used=used+1",
            )
            .run(userId, day);
        }
      }
      const result: AuthorizationResult = {
        requestId: body.requestId,
        allowed,
        message,
        requiresMembership,
        remaining: Math.max(0, limit - nextUsed),
        day,
        member,
      };
      store.db
        .prepare(
          "INSERT INTO assistant_requests(user_id,request_id,body_hash,created_at,result_json,refunded) VALUES(?,?,?,?,?,0) ON CONFLICT(user_id,request_id) DO UPDATE SET result_json=excluded.result_json,created_at=excluded.created_at,refunded=0",
        )
        .run(userId, body.requestId, bodyHash, now, JSON.stringify(result));
      return result;
    })();
  };
  const refund = (userId: string, requestId: string) =>
    store.db.transaction(() => {
      const row = store.db
        .prepare(
          "SELECT result_json,refunded FROM assistant_requests WHERE user_id=? AND request_id=?",
        )
        .get(userId, requestId) as
        | { result_json: string; refunded: number }
        | undefined;
      if (!row || row.refunded) return;
      const result = JSON.parse(row.result_json) as AuthorizationResult;
      if (!result.allowed || !result.day) return;
      store.db
        .prepare(
          "UPDATE assistant_usage SET used=MAX(0,used-1) WHERE user_id=? AND day=?",
        )
        .run(userId, result.day);
      store.db
        .prepare(
          "UPDATE assistant_requests SET refunded=1 WHERE user_id=? AND request_id=?",
        )
        .run(userId, requestId);
    })();

  app.get("/api/v1/assistant/config", async () => {
    const { systemPrompt: _, ...publicPolicy } = policy();
    return publicPolicy;
  });
  app.get("/api/v1/admin/assistant/config", async (req) => {
    admin(req.headers.authorization);
    return policy();
  });
  app.put("/api/v1/admin/assistant/config", async (req) => {
    admin(req.headers.authorization);
    const value = assistantPolicySchema.parse(req.body);
    store.db
      .prepare("UPDATE assistant_policy SET data_json=? WHERE id=1")
      .run(JSON.stringify(value));
    return value;
  });
  // A trusted operational/verified-payment integration may grant or revoke
  // assistant access. No client payment-success flag is accepted.
  app.put("/api/v1/admin/assistant/memberships/:userId", async (req) => {
    admin(req.headers.authorization);
    const { userId } = z
      .object({ userId: z.string().min(1).max(100) })
      .parse(req.params);
    const { expiresAt } = z
      .strictObject({
        expiresAt: z.number().int().nonnegative().max(4102444800),
      })
      .parse(req.body);
    check(
      store.db.prepare("SELECT 1 FROM users WHERE id=?").get(userId),
      "用户不存在",
      404,
    );
    store.db
      .prepare(
        "INSERT INTO assistant_memberships VALUES(?,?) ON CONFLICT(user_id) DO UPDATE SET expires_at=excluded.expires_at",
      )
      .run(userId, expiresAt);
    return { userId, expiresAt };
  });
  app.post(
    "/api/v1/assistant/authorize",
    { config: { rateLimit: { max: 60, timeWindow: "1 minute" } } },
    async (req) => {
      const user = authenticate(req.headers.authorization);
      return authorize(user.id, assistantRequestSchema.parse(req.body));
    },
  );
  app.post(
    "/api/v1/assistant/parse-transaction",
    { config: { rateLimit: { max: 30, timeWindow: "1 minute" } } },
    async (req) => {
      const user = authenticate(req.headers.authorization);
      const body = voiceParseRequestSchema.parse(req.body);
      return once(`${user.id}:parse:${body.requestId}`, body, async () => {
        const bodyHash = createHash("sha256")
          .update(JSON.stringify(body))
          .digest("hex");
        const cached = store.db
          .prepare(
            "SELECT body_hash,result_json FROM assistant_parse_responses WHERE user_id=? AND request_id=?",
          )
          .get(user.id, body.requestId) as
          | { body_hash: string; result_json: string }
          | undefined;
        if (cached) {
          check(cached.body_hash === bodyHash, "请求标识已用于其他内容", 409);
          return JSON.parse(cached.result_json);
        }

        const p = policy();
        const member = hasActiveMembership(user.id, store.now());
        const accessFeature =
          body.source === "ocr"
            ? "ocr"
            : body.source === "voice"
              ? "voice"
              : undefined;
        if (accessFeature && p.memberFeatures.includes(accessFeature)) {
          const legacy = store.db
            .prepare(
              "SELECT 1 FROM assistant_memberships WHERE user_id=? AND expires_at>?",
            )
            .get(user.id, store.now());
          check(
            hasMembershipEntitlement(
              store,
              user.id,
              accessFeature === "ocr" ? "ocr" : "voiceAi",
            ) || legacy,
            "该解析功能需要对应会员权益",
            403,
          );
        }
        const authorization = authorize(user.id, {
          requestId: body.requestId,
          text: body.text,
        });
        check(
          authorization.allowed,
          authorization.message || "AI解析暂不可用",
          authorization.requiresMembership ? 403 : 429,
        );

        const referenceTime = body.now ?? new Date().toISOString();
        const timezoneOffset = body.timezoneOffsetMinutes ?? 0;
        const systemPrompt = [
          transactionPrompt,
          `最多返回${p.maxTransactions}笔。相对时间以客户端当前时间为准。`,
          `客户端当前时间：${referenceTime}；时区偏移分钟：${timezoneOffset}`,
        ].join("\n");

        let raw: string;
        try {
          raw = await modelProvider.complete({
            systemPrompt,
            userText: body.text,
            scene: body.source,
          });
        } catch (error) {
          refund(user.id, body.requestId);
          if (error instanceof AssistantModelUnavailable) {
            throw new ApiError(503, "模型服务暂时不可用，请稍后重试");
          }
          throw error;
        }
        const cleaned = raw
          .trim()
          .replace(/^\`\`\`(?:json)?\s*/i, "")
          .replace(/\s*\`\`\`$/, "");
        let decoded: unknown;
        try {
          decoded = JSON.parse(cleaned);
        } catch {
          refund(user.id, body.requestId);
          throw new ApiError(502, "模型返回了无效的交易 JSON");
        }
        const parsed = voiceTransactionsSchema.safeParse(decoded);
        if (!parsed.success || parsed.data.length > p.maxTransactions) {
          refund(user.id, body.requestId);
          throw new ApiError(502, "模型返回的交易字段不符合严格结构");
        }
        const result = {
          ...authorization,
          requestId: body.requestId,
          schemaVersion: body.schemaVersion,
          json: JSON.stringify(parsed.data),
          source: "deepseek",
        };
        store.db
          .prepare("INSERT INTO assistant_parse_responses VALUES(?,?,?,?,?)")
          .run(
            user.id,
            body.requestId,
            bodyHash,
            store.now(),
            JSON.stringify(result),
          );
        return result;
      });
    },
  );

  app.post(
    "/api/v1/assistant/chat",
    { config: { rateLimit: { max: 60, timeWindow: "1 minute" } } },
    async (req) => {
      const user = authenticate(req.headers.authorization);
      const body = assistantRequestSchema.parse(req.body);
      return once(`${user.id}:chat:${body.requestId}`, body, async () => {
        check(body.text !== undefined, "模型对话必须提供文本", 400);
        const bodyHash = createHash("sha256")
          .update(JSON.stringify(body))
          .digest("hex");
        const cached = store.db
          .prepare(
            "SELECT body_hash,result_json FROM assistant_chat_responses WHERE user_id=? AND request_id=?",
          )
          .get(user.id, body.requestId) as
          | { body_hash: string; result_json: string }
          | undefined;
        if (cached) {
          check(cached.body_hash === bodyHash, "请求标识已用于其他内容", 409);
          return JSON.parse(cached.result_json);
        }
        const authorization = authorize(user.id, body);
        if (!authorization.allowed)
          return { ...authorization, source: "policy" };
        let message: string,
          sourceType: "deepseek" | "boundary" = "deepseek";
        try {
          message = await modelProvider.complete({
            systemPrompt: `${assistantHardPrompt}\n${policy().systemPrompt}`,
            userText: body.text,
          });
        } catch (error) {
          refund(user.id, body.requestId);
          if (error instanceof AssistantModelUnavailable)
            throw new ApiError(503, "模型服务暂时不可用，请稍后重试");
          throw error;
        }
        if (
          outOfScope(message) ||
          /已(?:经)?(?:为你|帮你)?(?:成功)?(?:记账|入账|保存|退款|支付|导出)|(?:记账|入账|退款|支付|导出)成功|(?:余额|收入|支出|结余)(?:为|是|：|:)\s*[¥￥\d]/.test(
            message,
          )
        ) {
          message = policy().boundaryReply;
          sourceType = "boundary";
        }
        const result = { ...authorization, message, source: sourceType };
        store.db
          .prepare("INSERT INTO assistant_chat_responses VALUES(?,?,?,?,?)")
          .run(
            user.id,
            body.requestId,
            bodyHash,
            store.now(),
            JSON.stringify(result),
          );
        return result;
      });
    },
  );
  function modelAction<T extends { requestId: string; text: string }>(
    action: string, schema: z.ZodType<T>,
    run: (body: T) => Promise<Record<string, unknown>>,
  ) {
    app.post(`/api/v1/assistant/${action}`,
      { config: { rateLimit: { max: 30, timeWindow: "1 minute" } } }, async req => {
        const user = authenticate(req.headers.authorization);
        const body = schema.parse(req.body);
        check(assistantQueryFeature(body.text) === "summary", "请提供消费查询或分析问题", 400);
        const key = `${action}:${body.requestId}`;
        return once(`${user.id}:${key}`, body, async () => {
          const hash = createHash("sha256").update(JSON.stringify(body)).digest("hex");
          const cached = store.db.prepare(
            "SELECT body_hash,result_json FROM assistant_chat_responses WHERE user_id=? AND request_id=?",
          ).get(user.id, key) as { body_hash: string; result_json: string } | undefined;
          if (cached) {
            check(cached.body_hash === hash, "请求标识已用于其他内容", 409);
            return JSON.parse(cached.result_json);
          }
          // Reuse the original turn authorization; the two phases consume one request.
          const authorization = authorize(user.id, { requestId: body.requestId, text: body.text });
          if (!authorization.allowed) return { ...authorization, source: "policy" };
          let result;
          try {
            result = { ...authorization, ...await run(body), source: "model" };
          } catch (error) {
            refund(user.id, body.requestId);
            if (error instanceof AssistantModelUnavailable) throw new ApiError(503, "模型服务暂时不可用");
            if (error instanceof ApiError) throw error;
            throw new ApiError(502, "模型没有返回有效结果");
          }
          store.db.prepare("INSERT INTO assistant_chat_responses VALUES(?,?,?,?,?)")
            .run(user.id, key, hash, store.now(), JSON.stringify(result));
          return result;
        });
      });
  }
  modelAction("query-plan", queryPlanRequest, async body => {
    const raw = await modelProvider.complete({
      systemPrompt: queryPlanPrompt,
      userText: JSON.stringify({ text: body.text, referenceDate: body.referenceDate, categories: body.categories }),
    });
    const result = queryPlanResponse.parse(JSON.parse(raw));
    if ("clarification" in result) return { message: result.clarification };
    check(result.endDate <= body.referenceDate, "查询不能包含未来日期", 502);
    check(result.categoryId === null || body.categories.some(c => c.id === result.categoryId), "查询分类无效", 502);
    return { plan: result };
  });
  modelAction("interpret", interpretationRequest, async body => {
    const raw = await modelProvider.complete({
      systemPrompt: interpretationPrompt,
      userText: JSON.stringify({ question: body.text, facts: body.facts }),
    });
    const result = interpretationResponse.parse(JSON.parse(raw));
    return { message: [result.analysis, ...result.suggestions].join("\n") };
  });
}
