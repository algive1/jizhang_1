import { createHash, randomUUID } from "node:crypto";
import { createApp } from "../../server/src/app.js";
import { encodePassword } from "../../server/src/console/auth.js";
process.env.PUSH_WORKER_ENABLED = "false";
const { app, store } = await createApp(":memory:");
for (const [username, role] of [
  ["browser_admin", "super"],
  ["browser_support", "support"],
]) {
  store.db
    .prepare(
      "INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)",
    )
    .run(
      randomUUID(),
      username,
      await encodePassword("browser-test-password-2026"),
      role,
      store.now(),
    );
}
const commerceAdmin = store.db
  .prepare("SELECT id FROM console_admins WHERE username='browser_admin'")
  .get() as { id: string };
store.db
  .prepare(
    "INSERT INTO console_sessions(token_hash,admin_id,expires_at,session_id,created_at,last_seen_at) VALUES(?,?,?,?,?,?)",
  )
  .run(
    createHash("sha256").update("browser-commerce-test-session").digest("hex"),
    commerceAdmin.id,
    store.now() + 3600,
    randomUUID(),
    store.now(),
    store.now(),
  );
const user = (
  await app.inject({
    method: "POST",
    url: "/api/v1/auth/register",
    payload: {
      username: "browser_user",
      password: "browser-user-password",
      displayName: "浏览器测试用户",
    },
  })
).json();
store.db
  .prepare("INSERT INTO console_ai_calls VALUES(?,?,?,?,?,?,?,?,?,?)")
  .run(
    "browser-ai-call",
    user.user.id,
    "assistant",
    "legacy",
    "failed",
    null,
    null,
    null,
    5,
    store.now(),
  );
await app.inject({
  method: "POST",
  url: "/api/v1/support/tickets",
  headers: { authorization: `Bearer ${user.token}` },
  payload: {
    installationId: "b".repeat(32),
    subject: "浏览器测试反馈",
    message: "自动记账遇到问题，联系方式 13800138000",
    contact: "test@example.com",
  },
});
await app.inject({
  method: "POST",
  url: "/api/v1/auto-accounting/events",
  headers: { authorization: `Bearer ${user.token}` },
  payload: {
    diagnosticConsent: true,
    events: [
      {
        eventId: "browser-notice",
        traceId: "browser-trace",
        occurredAt: Date.now() - 1000,
        stage: "notification",
        status: "success",
        packageName: "com.test.payment",
        appVersion: "1.2.0",
        metadata: { ruleMatched: true },
      },
      {
        eventId: "browser-page",
        traceId: "browser-trace",
        occurredAt: Date.now() - 900,
        stage: "page",
        status: "success",
        packageName: "com.test.payment",
        appVersion: "1.2.0",
        metadata: { structureHash: "a".repeat(64) },
      },
      {
        eventId: "browser-match",
        traceId: "browser-trace",
        occurredAt: Date.now() - 800,
        stage: "matched",
        status: "success",
        packageName: "com.test.payment",
        appVersion: "1.2.0",
        metadata: { relatedEventIds: ["browser-notice", "browser-page"] },
      },
      {
        eventId: "browser-failed",
        traceId: "browser-trace",
        occurredAt: Date.now() - 700,
        stage: "saved",
        status: "failed",
        reason: "database_write_failed",
        packageName: "com.test.payment",
        appVersion: "1.2.0",
        metadata: {},
      },
    ],
  },
});
await app.listen({ port: 8790, host: "127.0.0.1" });
for (const signal of ["SIGTERM", "SIGINT"])
  process.on(signal, () => {
    void app.close();
  });
