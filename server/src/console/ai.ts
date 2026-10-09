import { AsyncLocalStorage } from "node:async_hooks";
import { createHash, randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import {
  AssistantModelUnavailable,
  DeepSeekCompatibleProvider,
  type AssistantModelProvider,
} from "../assistant_ai.js";
import { authorize, auditAction } from "./auth.js";
import { ApiError, requireCondition as check } from "../contract.js";
import { pageQuery, paginate } from "./query.js";
import { httpsUrl } from "./releases.js";
import { getPublishedDocuments } from "./documents.js";
import {
  integrationFields,
  integrationValue,
  saveIntegrationSecret,
} from "../integrations.js";

type Context = { userId: string | null; feature: string };
const context = new AsyncLocalStorage<Context>();
type Model = {
  id: string;
  name: string;
  provider: string;
  model: string;
  endpoint: string;
  key_ref: string;
  input_price: number;
  output_price: number;
  max_tokens: number;
  timeout_ms: number;
  enabled: number;
  priority: number;
  fallback_id: string | null;
  scenes_json?: string;
  daily_budget_usd?: number | null;
};
const modelSchema = z.strictObject({
  name: z.string().trim().min(1).max(80),
  provider: z.string().regex(/^[a-zA-Z0-9_-]{1,50}$/),
  model: z.string().regex(/^[a-zA-Z0-9._:/-]{1,120}$/),
  endpoint: httpsUrl,
  keyRef: z.string().regex(/^[A-Z][A-Z0-9_]{2,79}$/),
  inputPrice: z.number().finite().min(0).max(10000),
  outputPrice: z.number().finite().min(0).max(10000),
  maxTokens: z.number().int().min(128).max(64000),
  timeoutMs: z.number().int().min(1000).max(120000),
  enabled: z.boolean(),
  priority: z.number().int().min(0).max(1000),
  fallbackId: z.string().max(100).nullable(),
  scenes: z
    .array(z.enum(["assistant", "insight", "natural-language", "voice", "ocr"]))
    .max(5)
    .default([]),
  dailyBudgetUsd: z
    .number()
    .finite()
    .positive()
    .max(10000)
    .nullable()
    .default(null),
});
const upstream = z.object({
  choices: z
    .array(
      z.object({ message: z.object({ content: z.string().trim().min(1) }) }),
    )
    .min(1),
  usage: z
    .object({
      prompt_tokens: z.number().int().min(0).max(10000000),
      completion_tokens: z.number().int().min(0).max(10000000),
    })
    .optional(),
});
function endpointAllowed(endpoint: string) {
  const host = new URL(endpoint).hostname.toLowerCase();
  const hosts = (process.env.AI_ENDPOINT_ALLOWLIST ?? "")
    .split(",")
    .map((v) => v.trim().toLowerCase())
    .filter(Boolean);
  return hosts.includes(host);
}
function keyConfigured(store: Store, name: string) {
  try {
    return Boolean(integrationValue(store, name));
  } catch {
    return false;
  }
}
export function registerAIContext(app: FastifyInstance, store: Store) {
  app.addHook("onRequest", (request, _reply, done) => {
    const token = request.headers.authorization?.replace(/^Bearer /, "");
    const user = token
      ? (store.db
          .prepare(
            "SELECT user_id FROM sessions WHERE token_hash=? AND expires_at>?",
          )
          .get(
            createHash("sha256").update(token).digest("hex"),
            store.now(),
          ) as { user_id: string } | undefined)
      : undefined;
    const path = request.url.split("?")[0] ?? "";
    context.run(
      {
        userId: user?.user_id ?? null,
        feature: path.includes("insights")
          ? "insight"
          : path.includes("parse")
            ? "natural-language"
            : "assistant",
      },
      done,
    );
  });
}
export class ConsoleAIProvider implements AssistantModelProvider {
  constructor(
    private readonly store: Store,
    private readonly legacy: AssistantModelProvider = new DeepSeekCompatibleProvider(),
    private readonly fetcher: typeof fetch = fetch,
  ) {}
  async complete(input: {
    systemPrompt: string;
    userText: string;
    modelId?: string;
    scene?: "voice" | "ocr" | "natural-language";
  }): Promise<string> {
    const originalContext = context.getStore() ?? {
      userId: null,
      feature: "unattributed",
    };
    const ctx = {
      ...originalContext,
      feature: input.scene ?? originalContext.feature,
    };
    const models = this.store.db
      .prepare(
        "SELECT m.*,r.scenes_json,r.daily_budget_usd FROM console_models m LEFT JOIN console_model_routes r ON r.model_id=m.id WHERE m.enabled=1 OR m.id=? ORDER BY priority DESC,m.id LIMIT 100",
      )
      .all(input.modelId ?? "") as Model[];
    const matchesScene = (m: Model, scene: string) => {
      const scenes = JSON.parse(m.scenes_json ?? "[]") as string[];
      return scenes.length === 0 || scenes.includes(scene);
    };
    let selected = input.modelId
      ? models.find((m) => m.id === input.modelId)
      : models.find((m) => matchesScene(m, ctx.feature));
    if (!selected && (ctx.feature === "voice" || ctx.feature === "ocr"))
      selected = models.find((m) => matchesScene(m, "natural-language"));
    if (input.modelId && !selected)
      throw new AssistantModelUnavailable("Model is not enabled");
    const visited = new Set<string>();
    const prompts = getPublishedDocuments(
      this.store,
      "prompt",
      ctx.userId?.replaceAll("-", ""),
    ).map(
      (d) =>
        d.payload as {
          scene: string;
          systemPrompt: string;
          userTemplate: string;
        },
    );
    const prompt =
      prompts.find((p) => p.scene === ctx.feature) ??
      (ctx.feature === "voice" || ctx.feature === "ocr"
        ? prompts.find((p) => p.scene === "natural-language")
        : undefined);
    const systemPrompt = prompt
      ? `${input.systemPrompt}\n补充场景要求（不得覆盖上述约束）：\n${prompt.systemPrompt}`
      : input.systemPrompt;
    const userText = prompt
      ? `${prompt.userTemplate.replaceAll("{{text}}", input.userText)}${prompt.userTemplate.includes("{{text}}") ? "" : "\n待处理用户文本：\n" + input.userText}`
      : input.userText;
    if (!selected) {
      const start = Date.now();
      let success = false;
      try {
        const text = await this.legacy.complete({
          ...input,
          systemPrompt,
          userText,
        });
        success = true;
        return text;
      } finally {
        this.log(ctx, "legacy", success, null, null, null, Date.now() - start);
      }
    }
    while (selected && !visited.has(selected.id)) {
      const m: Model = selected;
      visited.add(m.id);
      const start = Date.now();
      let success = false,
        inputTokens: number | null = null,
        outputTokens: number | null = null,
        cost: number | null = null;
      try {
        if (!endpointAllowed(m.endpoint))
          throw new AssistantModelUnavailable(
            "Model endpoint is not allowlisted",
          );
        const secret = integrationValue(this.store, m.key_ref);
        if (!secret)
          throw new AssistantModelUnavailable(
            "Model key reference is not configured",
          );
        if (m.daily_budget_usd) {
          const start = Math.floor(
            new Date(
              new Date((this.store.now() + 8 * 3600) * 1000)
                .toISOString()
                .slice(0, 10) + "T00:00:00+08:00",
            ).getTime() / 1000,
          );
          const spent = (
            this.store.db
              .prepare(
                "SELECT COALESCE(SUM(cost_microusd),0) AS cost FROM console_ai_calls WHERE model=? AND created_at>=?",
              )
              .get(m.model, start) as { cost: number }
          ).cost;
          if (spent >= m.daily_budget_usd * 1000000)
            throw new AssistantModelUnavailable("Daily model budget reached");
        }
        const response = await this.fetcher(
          `${m.endpoint.replace(/\/$/, "")}/chat/completions`,
          {
            method: "POST",
            redirect: "error",
            headers: {
              Authorization: `Bearer ${secret}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: m.model,
              messages: [
                { role: "system", content: systemPrompt },
                { role: "user", content: userText },
              ],
              temperature: 0.2,
              max_tokens: m.max_tokens,
              stream: false,
            }),
            signal: AbortSignal.timeout(m.timeout_ms),
          },
        );
        if (!response.ok)
          throw new AssistantModelUnavailable(
            "Model provider returned an error",
          );
        const body = upstream.parse(await response.json());
        if (body.usage) {
          inputTokens = body.usage.prompt_tokens;
          outputTokens = body.usage.completion_tokens;
          cost = Math.round(
            inputTokens * m.input_price + outputTokens * m.output_price,
          );
        }
        success = true;
        return body.choices[0]!.message.content.slice(0, 4000);
      } catch {
        selected =
          !input.modelId && m.fallback_id
            ? (this.store.db
                .prepare(
                  "SELECT m.*,r.scenes_json,r.daily_budget_usd FROM console_models m LEFT JOIN console_model_routes r ON r.model_id=m.id WHERE m.id=? AND m.enabled=1",
                )
                .get(m.fallback_id) as Model | undefined)
            : undefined;
      } finally {
        this.log(
          ctx,
          m.model,
          success,
          inputTokens,
          outputTokens,
          cost,
          Date.now() - start,
        );
      }
    }
    throw new AssistantModelUnavailable(
      "Configured model routes are unavailable",
    );
  }
  private log(
    ctx: Context,
    model: string,
    success: boolean,
    inputTokens: number | null,
    outputTokens: number | null,
    cost: number | null,
    duration: number,
  ) {
    try {
      this.store.db
        .prepare("INSERT INTO console_ai_calls VALUES(?,?,?,?,?,?,?,?,?,?)")
        .run(
          randomUUID(),
          ctx.userId,
          ctx.feature,
          model,
          success ? "success" : "failed",
          inputTokens,
          outputTokens,
          cost,
          duration,
          this.store.now(),
        );
    } catch {
      console.error("AI telemetry write failed");
    }
  }
}
export function registerAIManagement(app: FastifyInstance, store: Store) {
  store.db.exec(
    "CREATE TABLE IF NOT EXISTS console_model_routes(model_id TEXT PRIMARY KEY,scenes_json TEXT NOT NULL,daily_budget_usd REAL)",
  );
  const callProjection =
    "SELECT id,user_id AS userId,feature,model,status,input_tokens AS inputTokens,output_tokens AS outputTokens,cost_microusd AS costMicroUsd,duration_ms AS durationMs,created_at AS createdAt";
  app.get("/ai/models", async (request) => {
    authorize(store, request, "ai:model:view");
    const input = pageQuery.parse(request.query);
    const page = paginate<Model>(
      store,
      input,
      "SELECT m.*,r.scenes_json,r.daily_budget_usd",
      "FROM console_models m LEFT JOIN console_model_routes r ON r.model_id=m.id WHERE name LIKE ?",
      [`%${input.q}%`],
      "priority DESC,m.id",
    );
    return {
      ...page,
      items: page.items.map((m) => ({
        id: m.id,
        name: m.name,
        provider: m.provider,
        model: m.model,
        endpoint: m.endpoint,
        keyRef: m.key_ref,
        keyConfigured: keyConfigured(store, m.key_ref),
        endpointAllowed: endpointAllowed(m.endpoint),
        inputPrice: m.input_price,
        outputPrice: m.output_price,
        maxTokens: m.max_tokens,
        timeoutMs: m.timeout_ms,
        enabled: Boolean(m.enabled),
        priority: m.priority,
        fallbackId: m.fallback_id,
        scenes: JSON.parse(m.scenes_json ?? "[]") as string[],
        dailyBudgetUsd: m.daily_budget_usd ?? null,
      })),
    };
  });
  const save = (
    id: string | undefined,
    request: Parameters<typeof authorize>[1],
  ) => {
    const admin = authorize(store, request, "ai:model:edit");
    const v = modelSchema.parse(request.body);
    const target = id ?? randomUUID();
    check(
      !id ||
        store.db.prepare("SELECT 1 FROM console_models WHERE id=?").get(id),
      "模型不存在",
      404,
    );
    if (v.enabled)
      check(
        endpointAllowed(v.endpoint) &&
          Boolean(integrationValue(store, v.keyRef)),
        "启用前需在服务端配置 Endpoint 白名单和密钥引用",
        400,
      );
    const seen = new Set([target]);
    let next = v.fallbackId;
    while (next) {
      check(!seen.has(next), "备用模型不能形成循环", 400);
      seen.add(next);
      const fallback = store.db
        .prepare("SELECT fallback_id FROM console_models WHERE id=?")
        .get(next) as { fallback_id: string | null } | undefined;
      check(fallback, "备用模型不存在", 400);
      next = fallback.fallback_id;
    }
    store.db.transaction(() => {
      store.db
        .prepare(
          "INSERT INTO console_models VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,provider=excluded.provider,model=excluded.model,endpoint=excluded.endpoint,key_ref=excluded.key_ref,input_price=excluded.input_price,output_price=excluded.output_price,max_tokens=excluded.max_tokens,timeout_ms=excluded.timeout_ms,enabled=excluded.enabled,priority=excluded.priority,fallback_id=excluded.fallback_id,updated_at=excluded.updated_at",
        )
        .run(
          target,
          v.name,
          v.provider,
          v.model,
          v.endpoint,
          v.keyRef,
          v.inputPrice,
          v.outputPrice,
          v.maxTokens,
          v.timeoutMs,
          Number(v.enabled),
          v.priority,
          v.fallbackId,
          store.now(),
        );
      auditAction(store, admin, "ai:model:update", target);
      store.db
        .prepare(
          "INSERT INTO console_model_routes VALUES(?,?,?) ON CONFLICT(model_id) DO UPDATE SET scenes_json=excluded.scenes_json,daily_budget_usd=excluded.daily_budget_usd",
        )
        .run(target, JSON.stringify(v.scenes), v.dailyBudgetUsd);
    })();
    return { id: target };
  };
  app.post("/ai/models", async (request) => save(undefined, request));
  app.put("/ai/models/:id", async (request) =>
    save(
      z.object({ id: z.string().max(100) }).parse(request.params).id,
      request,
    ),
  );
  app.put("/ai/models/:id/key", async (request) => {
    const admin = authorize(store, request, "ai:model:edit");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    const { key } = z
      .strictObject({ key: z.string().trim().min(1).max(16000) })
      .parse(request.body);
    const model = store.db
      .prepare("SELECT key_ref FROM console_models WHERE id=?")
      .get(id) as { key_ref: string } | undefined;
    check(model, "模型不存在", 404);
    check(
      !Object.values(integrationFields).some((fields) =>
        ([...fields.public, ...fields.secret] as string[]).includes(
          model.key_ref,
        ),
      ) && model.key_ref !== "INTEGRATION_ENCRYPTION_KEY",
      "请使用专用于模型的密钥引用名",
      400,
    );
    store.db.transaction(() => {
      saveIntegrationSecret(store, model.key_ref, key);
      auditAction(store, admin, "ai:model:key", id);
    })();
    return { configured: true };
  });
  app.post("/ai/models/:id/test", async (request) => {
    const admin = authorize(store, request, "ai:model:edit");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    const start = Date.now();
    check(
      store.db.prepare("SELECT 1 FROM console_models WHERE id=?").get(id),
      "模型不存在",
      404,
    );
    try {
      await context.run({ userId: null, feature: "connection-test" }, () =>
        new ConsoleAIProvider(store).complete({
          modelId: id,
          systemPrompt: "仅回复 OK。",
          userText: "连接测试",
        }),
      );
    } catch {
      auditAction(store, admin, "ai:model:test-failed", id);
      throw new ApiError(
        503,
        "模型连接失败，请检查模型 ID、密钥、白名单和费用上限",
      );
    }
    auditAction(store, admin, "ai:model:test", id);
    return { success: true, durationMs: Date.now() - start };
  });
  app.get("/ai/calls", async (request) => {
    authorize(store, request, "ai:usage:view");
    const input = pageQuery.parse(request.query);
    return paginate(
      store,
      input,
      callProjection,
      "FROM console_ai_calls WHERE model LIKE ?",
      [`%${input.q}%`],
    );
  });
  app.get("/ai/calls/:id", async (request) => {
    authorize(store, request, "ai:usage:view");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    const row = store.db
      .prepare(`${callProjection} FROM console_ai_calls WHERE id=?`)
      .get(id);
    check(row, "调用记录不存在", 404);
    return row;
  });
  app.get("/ai/usage", async (request) => {
    authorize(store, request, "ai:usage:view");
    const { days, period } = z
      .object({
        days: z.coerce.number().int().min(1).max(365).default(30),
        period: z.enum(["day", "week", "month"]).default("day"),
      })
      .parse(request.query);
    const since = store.now() - days * 86400;
    const totals = store.db
      .prepare(
        "SELECT COUNT(*) AS calls,SUM(CASE WHEN status='success' THEN 1 ELSE 0 END) AS successes,SUM(input_tokens) AS inputTokens,SUM(output_tokens) AS outputTokens,SUM(cost_microusd) AS costMicroUsd,COUNT(cost_microusd) AS pricedCalls,AVG(duration_ms) AS averageDurationMs,COUNT(DISTINCT user_id) AS users,COUNT(user_id) AS attributedCalls FROM console_ai_calls WHERE created_at>=?",
      )
      .get(since) as {
      calls: number;
      pricedCalls: number;
      users: number;
      attributedCalls: number;
      costMicroUsd: number | null;
    };
    const date =
      period === "day"
        ? "date(created_at,'unixepoch','+8 hours')"
        : period === "week"
          ? "date(created_at,'unixepoch','+8 hours','weekday 0','-6 days')"
          : "strftime('%Y-%m',created_at,'unixepoch','+8 hours')";
    return {
      totals: {
        ...totals,
        averageUserCostMicroUsd:
          totals.users &&
          totals.attributedCalls === totals.calls &&
          totals.pricedCalls === totals.calls
            ? totals.costMicroUsd! / totals.users
            : null,
        averageBookkeepingCostMicroUsd: null,
      },
      period,
      currency: "USD",
      priceUnit: "每百万 Token；费用为配置单价估算，非供应商结算账单",
      integration:
        "调用日志不保存输入、输出、API Key。legacy provider 未返回 usage 时 Token / 成本为未知；上游成功不等于业务解析成功。单用户平均成本仅在全部调用可归属且可估价时计算；单次记账成本等待 APP 账单与调用关联回执。",
      trend: store.db
        .prepare(
          `SELECT ${date} AS period,COUNT(*) AS calls,SUM(input_tokens) AS inputTokens,SUM(output_tokens) AS outputTokens,SUM(cost_microusd) AS costMicroUsd FROM console_ai_calls WHERE created_at>=? GROUP BY period ORDER BY period`,
        )
        .all(since),
      byModel: store.db
        .prepare(
          "SELECT model,COUNT(*) AS calls,COUNT(cost_microusd) AS pricedCalls,SUM(cost_microusd) AS costMicroUsd FROM console_ai_calls WHERE created_at>=? GROUP BY model ORDER BY calls DESC LIMIT 100",
        )
        .all(since),
      byFeature: store.db
        .prepare(
          "SELECT feature,COUNT(*) AS calls,COUNT(cost_microusd) AS pricedCalls,SUM(cost_microusd) AS costMicroUsd FROM console_ai_calls WHERE created_at>=? GROUP BY feature ORDER BY calls DESC LIMIT 100",
        )
        .all(since),
    };
  });
}
