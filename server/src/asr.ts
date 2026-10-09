import { createHash, createHmac } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "./store.js";
import { ApiError, requireCondition as check } from "./contract.js";
import { integrationValue } from "./integrations.js";
import { membershipCurrent } from "./payment.js";
import { authorize, auditAction } from "./console/auth.js";
import { pageQuery, paginate } from "./console/query.js";

const hash = (v: string) => createHash("sha256").update(v).digest("hex");
const hmac = (key: string | Buffer, value: string) =>
  createHmac("sha256", key).update(value).digest();
export function tencentAuthorization(
  secretId: string,
  secretKey: string,
  body: string,
  timestamp: number,
) {
  const date = new Date(timestamp * 1000).toISOString().slice(0, 10),
    scope = `${date}/asr/tc3_request`;
  const canonical = `POST\n/\n\ncontent-type:application/json; charset=utf-8\nhost:asr.tencentcloudapi.com\n\ncontent-type;host\n${hash(body)}`;
  const key = hmac(hmac(hmac(`TC3${secretKey}`, date), "asr"), "tc3_request");
  const signature = hmac(
    key,
    `TC3-HMAC-SHA256\n${timestamp}\n${scope}\n${hash(canonical)}`,
  ).toString("hex");
  return `TC3-HMAC-SHA256 Credential=${secretId}/${scope}, SignedHeaders=content-type;host, Signature=${signature}`;
}
export async function recognizeTencent(
  store: Store,
  audio: string,
  format: string,
  fetcher: typeof fetch = fetch,
) {
  const id = integrationValue(store, "TENCENT_ASR_SECRET_ID"),
    key = integrationValue(store, "TENCENT_ASR_SECRET_KEY");
  check(id && key, "腾讯语音识别尚未配置", 503);
  const payload = {
    ProjectId: 0,
    SubServiceType: 2,
    EngSerViceType: integrationValue(store, "TENCENT_ASR_ENGINE") ?? "16k_zh",
    SourceType: 1,
    VoiceFormat: format,
    Data: audio,
    DataLen: Buffer.from(audio, "base64").length,
    ConvertNumMode: 1,
    HotwordId: integrationValue(store, "TENCENT_ASR_HOTWORD_ID") ?? undefined,
  };
  const body = JSON.stringify(payload),
    timestamp = Math.floor(Date.now() / 1000);
  const response = await fetcher("https://asr.tencentcloudapi.com/", {
    method: "POST",
    redirect: "error",
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "X-TC-Action": "SentenceRecognition",
      "X-TC-Version": "2019-06-14",
      "X-TC-Timestamp": String(timestamp),
      Authorization: tencentAuthorization(id, key, body, timestamp),
    },
    body,
    signal: AbortSignal.timeout(18000),
  });
  const data = (await response.json()) as {
    Response?: {
      Result?: string;
      AudioDuration?: number;
      RequestId?: string;
      Error?: unknown;
    };
  };
  check(
    response.ok && data.Response && !data.Response.Error,
    "腾讯语音识别暂不可用，请稍后重试",
    503,
  );
  const v = data.Response;
  check(
    typeof v.Result === "string" &&
      v.Result.length <= 4000 &&
      typeof v.AudioDuration === "number" &&
      Number.isFinite(v.AudioDuration),
    "语音识别响应无效",
    502,
  );
  return {
    text: v.Result,
    durationMs: Math.round(v.AudioDuration * 1000),
    requestId: v.RequestId ?? "",
  };
}
const policySchema = z.strictObject({
  enabled: z.boolean(),
  dailyLimit: z.number().int().min(1).max(1000),
  maxSeconds: z.number().int().min(1).max(60),
});
export function registerAsr(
  app: FastifyInstance,
  store: Store,
  authenticate: (header: string | undefined) => { id: string },
) {
  store.db.exec(
    "CREATE TABLE IF NOT EXISTS asr_policy(id INTEGER PRIMARY KEY CHECK(id=1),data_json TEXT NOT NULL);CREATE TABLE IF NOT EXISTS asr_requests(user_id TEXT NOT NULL,request_id TEXT NOT NULL,body_hash TEXT NOT NULL,status TEXT NOT NULL,audio_duration_ms INTEGER,latency_ms INTEGER,provider_request_id TEXT,created_at INTEGER NOT NULL,PRIMARY KEY(user_id,request_id))",
  );
  const policy = () =>
    policySchema.parse(
      JSON.parse(
        (
          store.db
            .prepare("SELECT data_json FROM asr_policy WHERE id=1")
            .get() as { data_json: string } | undefined
        )?.data_json ?? '{"enabled":false,"dailyLimit":30,"maxSeconds":60}',
      ),
    );
  const cache = new Map<
    string,
    { text: string; durationMs: number; requestId: string }
  >();
  app.addHook("onClose", async () => cache.clear());
  app.get("/api/v1/asr/config", async () => policy());
  app.get("/api/v1/console/asr/policy", async (request) => {
    authorize(store, request, "ai:model:view");
    return { data: policy() };
  });
  app.put("/api/v1/console/asr/policy", async (request) => {
    const admin = authorize(store, request, "ai:model:edit"),
      input = policySchema.parse(request.body);
    if (input.enabled)
      check(
        integrationValue(store, "TENCENT_ASR_SECRET_ID") &&
          integrationValue(store, "TENCENT_ASR_SECRET_KEY"),
        "启用前请配置腾讯云凭据",
        400,
      );
    store.db.transaction(() => {
      store.db
        .prepare(
          "INSERT INTO asr_policy VALUES(1,?) ON CONFLICT(id) DO UPDATE SET data_json=excluded.data_json",
        )
        .run(JSON.stringify(input));
      auditAction(store, admin, "asr:policy:update", "tencent");
    })();
    return { data: policy() };
  });
  app.get("/api/v1/console/asr/usage", async (request) => {
    authorize(store, request, "ai:usage:view");
    return {
      data: paginate(
        store,
        pageQuery.parse(request.query),
        "SELECT user_id AS userId,request_id AS requestId,status,audio_duration_ms AS durationMs,latency_ms AS latencyMs,provider_request_id AS providerRequestId,created_at AS createdAt",
        "FROM asr_requests",
        [],
      ),
    };
  });
  app.post(
    "/api/v1/asr/recognize",
    {
      bodyLimit: 4 * 1024 * 1024,
      config: { rateLimit: { max: 10, timeWindow: "1 minute" } },
    },
    async (request) => {
      const user = authenticate(request.headers.authorization),
        p = policy();
      check(p.enabled, "云端语音识别尚未启用", 503);
      check(
        membershipCurrent(store, user.id).entitlements.some(
          (e) => e.key === "voiceAi",
        ),
        "云端语音识别需要对应会员权益",
        403,
      );
      const input = z
        .strictObject({
          requestId: z.string().regex(/^[a-f0-9]{32}$/),
          audio: z
            .string()
            .min(4)
            .max(3 * 1024 * 1024)
            .regex(
              /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/,
            ),
          format: z.enum(["m4a", "wav"]),
          durationMs: z
            .number()
            .int()
            .min(100)
            .max(p.maxSeconds * 1000),
          consent: z.literal(true),
        })
        .parse(request.body);
      const key = `${user.id}:${input.requestId}`,
        digest = hash(`${input.format}:${input.audio}`),
        old = store.db
          .prepare(
            "SELECT body_hash FROM asr_requests WHERE user_id=? AND request_id=?",
          )
          .get(user.id, input.requestId) as { body_hash: string } | undefined;
      if (old) {
        check(old.body_hash === digest, "请求编号已用于另一段录音", 409);
        const result = cache.get(key);
        check(result, "该录音已提交，请勿重复上传；失败时请重新录音", 409);
        return result;
      }
      const dayStart = Math.floor(
        Date.parse(
          new Date((store.now() + 8 * 3600) * 1000).toISOString().slice(0, 10) +
            "T00:00:00+08:00",
        ) / 1000,
      );
      const used = (
        store.db
          .prepare(
            "SELECT COUNT(*) AS n FROM asr_requests WHERE user_id=? AND created_at>=? AND status IN ('processing','success')",
          )
          .get(user.id, dayStart) as { n: number }
      ).n;
      check(used < p.dailyLimit, "今日云端语音识别次数已用完", 429);
      store.db
        .prepare(
          "INSERT INTO asr_requests VALUES(?,?,?,'processing',NULL,NULL,NULL,?)",
        )
        .run(user.id, input.requestId, digest, store.now());
      const start = Date.now();
      try {
        const result = await recognizeTencent(store, input.audio, input.format);
        check(
          result.durationMs <= p.maxSeconds * 1000,
          "录音超过时长限制",
          400,
        );
        store.db
          .prepare(
            "UPDATE asr_requests SET status='success',audio_duration_ms=?,latency_ms=?,provider_request_id=? WHERE user_id=? AND request_id=?",
          )
          .run(
            result.durationMs,
            Date.now() - start,
            result.requestId,
            user.id,
            input.requestId,
          );
        if (cache.size >= 100) cache.delete(cache.keys().next().value!);
        cache.set(key, result);
        setTimeout(() => cache.delete(key), 300000).unref();
        return result;
      } catch (error) {
        store.db
          .prepare(
            "UPDATE asr_requests SET status='failed',latency_ms=? WHERE user_id=? AND request_id=?",
          )
          .run(Date.now() - start, user.id, input.requestId);
        if (error instanceof ApiError) throw error;
        throw new ApiError(503, "云端语音识别失败，请稍后重试");
      }
    },
  );
}
