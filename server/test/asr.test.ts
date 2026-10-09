import test from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createApp } from "../src/app.js";
import { encodePassword } from "../src/console/auth.js";

test("腾讯 ASR 的鉴权、权益、额度、重复提交和录音隐私", async (t) => {
  const keys = [
    "TENCENT_ASR_SECRET_ID",
    "TENCENT_ASR_SECRET_KEY",
    "ALL_FEATURES_FREE_FOR_TESTING",
  ];
  const old = keys.map((k) => process.env[k]);
  process.env.TENCENT_ASR_SECRET_ID = "test-id";
  process.env.TENCENT_ASR_SECRET_KEY = "test-key";
  process.env.ALL_FEATURES_FREE_FOR_TESTING = "false";
  const fetcher = globalThis.fetch;
  t.after(() => {
    globalThis.fetch = fetcher;
    keys.forEach((k, i) => {
      if (old[i] === undefined) delete process.env[k];
      else process.env[k] = old[i];
    });
  });
  const { app, store } = await createApp(":memory:");
  t.after(() => app.close());
  store.db
    .prepare(
      "INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)",
    )
    .run(
      randomUUID(),
      "asr_admin",
      await encodePassword("asr-admin-password"),
      "super",
      store.now(),
    );
  const token = (
    await app.inject({
      method: "POST",
      url: "/api/v1/console/auth/login",
      payload: { username: "asr_admin", password: "asr-admin-password" },
    })
  ).json().data.token;
  const admin = { authorization: `Bearer ${token}` };
  const user = (
      await app.inject({
        method: "POST",
        url: "/api/v1/auth/register",
        payload: { username: "asr_user", password: "asr-user-password" },
      })
    ).json(),
    headers = { authorization: `Bearer ${user.token}` };
  const payload = {
    requestId: "a".repeat(32),
    audio: Buffer.from("private-audio-bytes").toString("base64"),
    format: "m4a",
    durationMs: 1000,
    consent: true,
  };
  const call = (body: typeof payload) =>
    app.inject({
      method: "POST",
      url: "/api/v1/asr/recognize",
      headers,
      payload: body,
    });
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/v1/asr/recognize",
        payload,
      })
    ).statusCode,
    401,
  );
  assert.equal((await call(payload)).statusCode, 503);
  assert.equal(
    (
      await app.inject({
        method: "PUT",
        url: "/api/v1/console/asr/policy",
        headers: admin,
        payload: { enabled: true, dailyLimit: 1, maxSeconds: 60 },
      })
    ).statusCode,
    200,
  );
  assert.equal((await call(payload)).statusCode, 403);
  store.db
    .prepare("INSERT INTO membership_adjustments VALUES(?,?,?,?,?,?,?)")
    .run(
      user.user.id,
      "pro",
      "monthly",
      store.now(),
      store.now() + 86400,
      store.now(),
      "test",
    );
  let calls = 0,
    finish: (value: Response) => void = () => {};
  globalThis.fetch = async (url, options) => {
    calls++;
    assert.equal(url, "https://asr.tencentcloudapi.com/");
    const body = JSON.parse(String(options?.body));
    assert.equal(body.Data, payload.audio);
    assert.equal(body.DataLen, 19);
    assert.equal(body.VoiceFormat, "m4a");
    const requestHeaders = options?.headers as Record<string, string>;
    assert.equal(requestHeaders["X-TC-Action"], "SentenceRecognition");
    assert.match(
      requestHeaders.Authorization!,
      /^TC3-HMAC-SHA256 Credential=test-id\//,
    );
    return new Promise<Response>((resolve) => {
      finish = resolve;
    });
  };
  assert.equal((await call({ ...payload, consent: false })).statusCode, 400);
  assert.equal((await call({ ...payload, durationMs: 61000 })).statusCode, 400);
  const first = call(payload);
  while (calls === 0) await new Promise((resolve) => setImmediate(resolve));
  assert.equal((await call(payload)).statusCode, 409, "正在识别时不得重复调用");
  finish(
    new Response(
      JSON.stringify({
        Response: {
          Result: "秘密识别文字",
          AudioDuration: 1,
          RequestId: "supplier-id",
        },
      }),
    ),
  );
  assert.equal((await first).json().text, "秘密识别文字");
  assert.equal((await call(payload)).json().text, "秘密识别文字");
  assert.equal(calls, 1);
  assert.equal(
    (await call({ ...payload, audio: Buffer.from("other").toString("base64") }))
      .statusCode,
    409,
  );
  assert.equal(
    (await call({ ...payload, requestId: "b".repeat(32) })).statusCode,
    429,
  );
  const metadata = JSON.stringify(
    store.db.prepare("SELECT * FROM asr_requests").all(),
  );
  assert.ok(!metadata.includes("秘密识别文字"));
  assert.ok(!metadata.includes(payload.audio));
});
