import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.js";
import { encodePassword } from "../src/console/auth.js";

test("event chains validate privacy, correlate sources, deduplicate, filter, and enforce detail permission", async (t) => {
  const { app, store } = await createApp(":memory:");
  t.after(() => app.close());
  store.db
    .prepare(
      "INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)",
    )
    .run(
      "test-admin",
      "event_admin",
      await encodePassword("event-admin-password"),
      "super",
      store.now(),
    );
  const adminLogin = (
    await app.inject({
      method: "POST",
      url: "/api/v1/console/auth/login",
      payload: { username: "event_admin", password: "event-admin-password" },
    })
  ).json().data;
  const admin = { authorization: `Bearer ${adminLogin.token}` };
  const registration = (
    await app.inject({
      method: "POST",
      url: "/api/v1/auth/register",
      payload: { username: "event_user", password: "event-user-password" },
    })
  ).json();
  const user = { authorization: `Bearer ${registration.token}` };
  const base = {
    traceId: "trace-1",
    occurredAt: store.now() * 1000,
    packageName: "com.eg.android.AlipayGphone",
    appVersion: "1.2.0",
    ruleVersion: 31,
    status: "success",
  };
  const events = [
    {
      ...base,
      eventId: "notice-1",
      stage: "notification",
      metadata: { ruleMatched: true },
    },
    {
      ...base,
      eventId: "page-1",
      stage: "page",
      metadata: { structureHash: "a".repeat(64) },
    },
    {
      ...base,
      eventId: "merge-1",
      stage: "matched",
      metadata: { relatedEventIds: ["notice-1", "page-1"] },
    },
    {
      ...base,
      eventId: "save-1",
      stage: "saved",
      status: "failed",
      reason: "database_write_failed",
      metadata: { durationMs: 20 },
    },
  ];
  const body = { diagnosticConsent: true, events };
  const endpoint = "/api/v1/auto-accounting/events";
  assert.equal(
    (await app.inject({ method: "POST", url: endpoint, payload: body }))
      .statusCode,
    401,
  );
  const upload = await app.inject({
    method: "POST",
    url: endpoint,
    headers: user,
    payload: body,
  });
  assert.equal(upload.statusCode, 200);
  assert.equal(upload.json().accepted, 4);
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: endpoint,
        headers: user,
        payload: body,
      })
    ).json().duplicates,
    4,
  );
  const detail = await app.inject({
    url: `/api/v1/console/events/trace/${registration.user.id}/trace-1`,
    headers: admin,
  });
  assert.equal(detail.statusCode, 200);
  assert.equal(detail.json().data.events.length, 4);
  assert.deepEqual(detail.json().data.observedStages.sort(), [
    "matched",
    "notification",
    "page",
    "saved",
  ]);
  const failures = (
    await app.inject({
      url: "/api/v1/console/events?status=failed&reason=database_write_failed",
      headers: admin,
    })
  ).json().data;
  assert.equal(failures.total, 1);
  assert.equal(failures.items[0].reason, "database_write_failed");
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: endpoint,
        headers: user,
        payload: { ...body, diagnosticConsent: false },
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: endpoint,
        headers: user,
        payload: {
          diagnosticConsent: true,
          events: [
            {
              ...events[0],
              eventId: "leak",
              metadata: { notification: "手机号 13800138000" },
            },
          ],
        },
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: endpoint,
        headers: user,
        payload: {
          diagnosticConsent: true,
          events: [{ ...events[0], eventId: "leak", merchant: "私密店铺" }],
        },
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: endpoint,
        headers: user,
        payload: {
          diagnosticConsent: true,
          events: [
            {
              ...events[0],
              eventId: "bad-time",
              occurredAt: store.now() * 1000 + 3600000,
            },
          ],
        },
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: endpoint,
        headers: user,
        payload: {
          diagnosticConsent: true,
          events: [
            {
              ...events[0],
              eventId: "bad-link",
              traceId: "trace-2",
              stage: "matched",
              metadata: { relatedEventIds: ["notice-1"] },
            },
          ],
        },
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (
      store.db.prepare("SELECT COUNT(*) AS n FROM console_events").get() as {
        n: number;
      }
    ).n,
    4,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: endpoint,
        headers: user,
        payload: {
          diagnosticConsent: true,
          events: [{ ...events[0], traceId: "different" }],
        },
      })
    ).statusCode,
    409,
  );
  await app.inject({
    method: "POST",
    url: "/api/v1/console/administrators",
    headers: admin,
    payload: {
      username: "restricted_events",
      password: "restricted-password",
      roleId: "analyst",
    },
  });
  const restricted = (
    await app.inject({
      method: "POST",
      url: "/api/v1/console/auth/login",
      payload: {
        username: "restricted_events",
        password: "restricted-password",
      },
    })
  ).json().data;
  assert.equal(
    (
      await app.inject({
        url: `/api/v1/console/events/trace/${registration.user.id}/trace-1`,
        headers: { authorization: `Bearer ${restricted.token}` },
      })
    ).statusCode,
    403,
  );
});
