import test from "node:test";
import assert from "node:assert/strict";
import { createApp } from "../src/app.js";
import { encodePassword } from "../src/console/auth.js";

test("模型按场景路由、费用上限停止调用，密钥不回显与并发重试只调用一次", async (t) => {
  const keys = [
    "AI_ENDPOINT_ALLOWLIST",
    "INTEGRATION_ENCRYPTION_KEY",
    "ALL_FEATURES_FREE_FOR_TESTING",
  ];
  const old = keys.map((k) => process.env[k]);
  process.env.AI_ENDPOINT_ALLOWLIST = "models.example.test";
  process.env.INTEGRATION_ENCRYPTION_KEY = "ab".repeat(32);
  process.env.ALL_FEATURES_FREE_FOR_TESTING = "true";
  const fetcher = globalThis.fetch;
  let calls = 0,
    finish: (value: Response) => void = () => {};
  const used: string[] = [];
  globalThis.fetch = async (_url, options) => {
    calls++;
    used.push(JSON.parse(String(options?.body)).model);
    assert.equal(
      (options?.headers as Record<string, string>).Authorization,
      "Bearer encrypted-model-key",
    );
    return new Promise<Response>((resolve) => {
      finish = resolve;
    });
  };
  const { app, store } = await createApp(":memory:");
  t.after(async () => {
    await app.close();
    globalThis.fetch = fetcher;
    keys.forEach((k, i) => {
      if (old[i] === undefined) delete process.env[k];
      else process.env[k] = old[i];
    });
  });
  store.db
    .prepare(
      "INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)",
    )
    .run(
      "routing",
      "routing_admin",
      await encodePassword("routing-admin-password"),
      "super",
      store.now(),
    );
  const login = (
      await app.inject({
        method: "POST",
        url: "/api/v1/console/auth/login",
        payload: {
          username: "routing_admin",
          password: "routing-admin-password",
        },
      })
    ).json(),
    admin = { authorization: `Bearer ${login.data.token}` };
  const model = {
    name: "测试",
    provider: "openai-compatible",
    model: "voice-model",
    endpoint: "https://models.example.test",
    keyRef: "ROUTING_MODEL_KEY",
    inputPrice: 2,
    outputPrice: 4,
    maxTokens: 512,
    timeoutMs: 1000,
    enabled: false,
    priority: 100,
    fallbackId: null,
    scenes: ["natural-language"],
    dailyBudgetUsd: 0.0004,
  };
  const id = (
    await app.inject({
      method: "POST",
      url: "/api/v1/console/ai/models",
      headers: admin,
      payload: model,
    })
  ).json().data.id;
  const write = await app.inject({
    method: "PUT",
    url: `/api/v1/console/ai/models/${id}/key`,
    headers: admin,
    payload: { key: "encrypted-model-key" },
  });
  assert.equal(write.statusCode, 200);
  assert.ok(!write.body.includes("encrypted-model-key"));
  assert.equal(
    (
      await app.inject({
        method: "PUT",
        url: `/api/v1/console/ai/models/${id}`,
        headers: admin,
        payload: { ...model, enabled: true },
      })
    ).statusCode,
    200,
  );
  const chatId = (
    await app.inject({
      method: "POST",
      url: "/api/v1/console/ai/models",
      headers: admin,
      payload: {
        ...model,
        model: "chat-model",
        scenes: ["assistant"],
        dailyBudgetUsd: null,
        enabled: true,
        priority: 10,
      },
    })
  ).json().data.id;
  assert.ok(chatId);
  const user = (
      await app.inject({
        method: "POST",
        url: "/api/v1/auth/register",
        payload: {
          username: "routing_user",
          password: "routing-user-password",
        },
      })
    ).json(),
    headers = { authorization: `Bearer ${user.token}` };
  const voice = {
    requestId: "voice-request-0001",
    text: "早餐20",
    schemaVersion: "voice_transaction_v1",
  };
  const first = app.inject({
    method: "POST",
    url: "/api/v1/assistant/parse-transaction",
    headers,
    payload: voice,
  });
  while (calls === 0) await new Promise((r) => setImmediate(r));
  const duplicate = app.inject({
    method: "POST",
    url: "/api/v1/assistant/parse-transaction",
    headers,
    payload: voice,
  });
  finish(
    new Response(
      JSON.stringify({
        choices: [
          {
            message: {
              content: JSON.stringify([
                {
                  type: "expense",
                  amount: 20,
                  category: "餐饮",
                  account: "未指定",
                  occurredAt: new Date().toISOString(),
                  confidence: 0.9,
                  rawFragment: "早餐20",
                },
              ]),
            },
          },
        ],
        usage: { prompt_tokens: 100, completion_tokens: 50 },
      }),
    ),
  );
  assert.equal((await first).statusCode, 200);
  assert.equal((await duplicate).statusCode, 200);
  assert.equal(calls, 1);
  assert.equal(used[0], "voice-model");
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/v1/assistant/parse-transaction",
        headers,
        payload: { ...voice, requestId: "voice-request-0002" },
      })
    ).statusCode,
    503,
  );
  assert.equal(calls, 1, "达到费用上限不再调用供应商");
  const chat = app.inject({
    method: "POST",
    url: "/api/v1/assistant/chat",
    headers,
    payload: { requestId: "chat-request-0001", text: "如何整理预算" },
  });
  while (calls === 1) await new Promise((r) => setImmediate(r));
  finish(
    new Response(
      JSON.stringify({
        choices: [{ message: { content: "建议记录每日收支" } }],
      }),
    ),
  );
  assert.equal((await chat).statusCode, 200);
  assert.equal(used[1], "chat-model");
});
