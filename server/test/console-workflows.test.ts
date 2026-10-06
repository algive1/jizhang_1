import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.js";
import { encodePassword } from "../src/console/auth.js";
import { ensureConsoleSchema } from "../src/console/schema.js";

async function fixture() {
  const previous = process.env.PUSH_WORKER_ENABLED;
  process.env.PUSH_WORKER_ENABLED = "false";
  const value = await createApp(":memory:");
  if (previous === undefined) delete process.env.PUSH_WORKER_ENABLED;
  else process.env.PUSH_WORKER_ENABLED = previous;
  value.store.db
    .prepare(
      "INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)",
    )
    .run(
      "workflow-admin",
      "workflow_admin",
      await encodePassword("workflow-test-password"),
      "super",
      value.store.now(),
    );
  const login = async () =>
    (
      await value.app.inject({
        method: "POST",
        url: "/api/v1/console/auth/login",
        payload: {
          username: "workflow_admin",
          password: "workflow-test-password",
        },
      })
    ).json().data.token as string;
  const token = await login();
  return {
    ...value,
    token,
    login,
    headers: { authorization: `Bearer ${token}` },
  };
}
test("release detail locks published content and rejects concurrent draft edits", async (t) => {
  const { app, store, headers } = await fixture();
  t.after(() => app.close());
  ensureConsoleSchema(store); // Reopening must not rerun ALTER migrations.
  const input = {
    platform: "android",
    versionName: "4.0.0",
    versionCode: 400,
    minimumVersion: "1.0.0",
    downloadUrl: "https://example.test/app.apk",
    changelog: "初始",
    rollout: 100,
  };
  const id = (
    await app.inject({
      method: "POST",
      url: "/api/v1/console/releases",
      headers,
      payload: input,
    })
  ).json().data.id;
  const url = `/api/v1/console/releases/${id}`;
  const first = (await app.inject({ url, headers })).json().data;
  assert.equal(first.revision, 1);
  assert.equal(first.updatedBy, "workflow_admin");
  assert.equal(
    (
      await app.inject({
        method: "PUT",
        url,
        headers,
        payload: { ...input, revision: 1, changelog: "修订" },
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (
      await app.inject({
        method: "PUT",
        url,
        headers,
        payload: { ...input, revision: 1 },
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (
      await app.inject({
        method: "PATCH",
        url: url + "/state",
        headers,
        payload: { status: "published" },
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (
      await app.inject({
        method: "PUT",
        url,
        headers,
        payload: { ...input, revision: 3 },
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (await app.inject({ url, headers })).json().data.changelog,
    "修订",
  );
  assert.equal(
    (await app.inject({ url: "/api/v1/console/releases/missing", headers }))
      .statusCode,
    404,
  );
});
test("login records and session revocation do not disclose authentication material", async (t) => {
  const { app, store, token, login, headers } = await fixture();
  t.after(() => app.close());
  await app.inject({
    method: "POST",
    url: "/api/v1/console/auth/login",
    payload: { username: "workflow_admin", password: "wrong-password-2026" },
  });
  const other = await login();
  const result = await app.inject({ url: "/api/v1/console/sessions", headers });
  assert.equal(result.statusCode, 200);
  assert.ok(!result.body.includes(token));
  assert.ok(!result.body.includes(other));
  assert.ok(!result.body.includes("tokenHash"));
  const sessions = result.json().data.items;
  assert.equal(sessions.length, 2);
  assert.equal(
    (
      await app.inject({
        method: "DELETE",
        url: `/api/v1/console/sessions/${sessions.find((s: { current: boolean }) => s.current).id}`,
        headers,
      })
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await app.inject({
        method: "DELETE",
        url: `/api/v1/console/sessions/${sessions.find((s: { current: boolean }) => !s.current).id}`,
        headers,
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (
      await app.inject({
        url: "/api/v1/console/auth/me",
        headers: { authorization: `Bearer ${other}` },
      })
    ).statusCode,
    401,
  );
  const records = (
    await app.inject({ url: "/api/v1/console/logins", headers })
  ).json().data;
  assert.equal(records.total, 3);
  assert.ok(records.items.some((r: { success: number }) => !r.success));
  store.db
    .prepare("INSERT INTO console_ai_calls VALUES(?,?,?,?,?,?,?,?,?,?)")
    .run(
      "test-call",
      null,
      "assistant",
      "legacy",
      "failed",
      null,
      null,
      null,
      5,
      store.now(),
    );
  assert.equal(
    (
      await app.inject({ url: "/api/v1/console/ai/calls/test-call", headers })
    ).json().data.model,
    "legacy",
  );
  assert.equal(
    (await app.inject({ url: "/api/v1/console/ai/calls/missing", headers }))
      .statusCode,
    404,
  );
});
test("push drafts require publication permission and providers, queue idempotently and stop safely", async (t) => {
  const { app, store, headers } = await fixture();
  t.after(() => app.close());
  const previous = {
    url: process.env.VENDOR_PUSH_URL,
    key: process.env.VENDOR_PUSH_TOKEN,
  };
  delete process.env.VENDOR_PUSH_URL;
  delete process.env.VENDOR_PUSH_TOKEN;
  t.after(() => {
    for (const [name, value] of [
      ["VENDOR_PUSH_URL", previous.url],
      ["VENDOR_PUSH_TOKEN", previous.key],
    ]) {
      if (value === undefined) delete process.env[name!];
      else process.env[name!] = value;
    }
  });
  const user = (
    await app.inject({
      method: "POST",
      url: "/api/v1/auth/register",
      payload: {
        username: "push_workflow",
        password: "push-workflow-password",
      },
    })
  ).json();
  await app.inject({
    method: "POST",
    url: "/api/v1/push/devices",
    headers: { authorization: `Bearer ${user.token}` },
    payload: {
      deviceId: "c".repeat(32),
      platform: "android",
      provider: "vendor",
      token: "test-only-private-device-token",
    },
  });
  await app.inject({
    method: "POST",
    url: "/api/v1/console/administrators",
    headers,
    payload: {
      username: "push_operator",
      password: "push-operator-password",
      roleId: "operations",
    },
  });
  const operatorToken = (
    await app.inject({
      method: "POST",
      url: "/api/v1/console/auth/login",
      payload: {
        username: "push_operator",
        password: "push-operator-password",
      },
    })
  ).json().data.token;
  const operator = { authorization: `Bearer ${operatorToken}` };
  const create = await app.inject({
    method: "POST",
    url: "/api/v1/console/push/campaigns",
    headers: operator,
    payload: {
      userId: user.user.id,
      title: "测试通知",
      body: "测试正文",
      route: "/profile/messages",
    },
  });
  assert.equal(create.statusCode, 200);
  const id = create.json().data.id,
    url = `/api/v1/console/push/campaigns/${id}`;
  assert.equal(
    (
      store.db.prepare("SELECT COUNT(*) AS n FROM push_outbox").get() as {
        n: number;
      }
    ).n,
    0,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: url + "/publish",
        headers: operator,
        payload: { confirmed: true },
      })
    ).statusCode,
    403,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: url + "/publish",
        headers,
        payload: { confirmed: true },
      })
    ).statusCode,
    400,
  );
  process.env.VENDOR_PUSH_URL = "https://push.example.test";
  process.env.VENDOR_PUSH_TOKEN = "test-only-vendor-key";
  for (let i = 0; i < 2; i++)
    assert.equal(
      (
        await app.inject({
          method: "POST",
          url: url + "/publish",
          headers,
          payload: { confirmed: true },
        })
      ).json().data.deviceCount,
      1,
    );
  const jobs = await app.inject({ url: url + "/jobs", headers });
  assert.equal(jobs.json().data.total, 1);
  assert.ok(!jobs.body.includes("token"));
  assert.ok(!jobs.body.includes("test-only-vendor-key"));
  assert.equal(
    (await app.inject({ method: "POST", url: url + "/stop", headers })).json()
      .data.cancelled,
    1,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: url + "/publish",
        headers,
        payload: { confirmed: true },
      })
    ).statusCode,
    409,
  );
  assert.equal(
    (await app.inject({ url, headers })).json().data.delivery[0].status,
    "cancelled",
  );
});
test("password changes verify the old password and revoke sessions; resets require admin privilege", async (t) => {
  const { app, headers } = await fixture();
  t.after(() => app.close());
  const input = {
    currentPassword: "wrong-test-password",
    newPassword: "changed-test-password",
  };
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/v1/console/auth/password",
        headers,
        payload: input,
      })
    ).statusCode,
    400,
  );
  await app.inject({
    method: "POST",
    url: "/api/v1/console/administrators",
    headers,
    payload: {
      username: "reset_support",
      password: "initial-test-password",
      roleId: "support",
    },
  });
  const supportToken = (
    await app.inject({
      method: "POST",
      url: "/api/v1/console/auth/login",
      payload: { username: "reset_support", password: "initial-test-password" },
    })
  ).json().data.token;
  const supportHeaders = { authorization: `Bearer ${supportToken}` };
  const supportId = (
    await app.inject({
      url: "/api/v1/console/auth/me",
      headers: supportHeaders,
    })
  ).json().data.id;
  const url = `/api/v1/console/administrators/${supportId}/password`;
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url,
        headers: supportHeaders,
        payload: { password: "reset-test-password" },
      })
    ).statusCode,
    403,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url,
        headers,
        payload: { password: "reset-test-password" },
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (
      await app.inject({
        url: "/api/v1/console/auth/me",
        headers: supportHeaders,
      })
    ).statusCode,
    401,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/v1/console/auth/password",
        headers,
        payload: { ...input, currentPassword: "workflow-test-password" },
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (await app.inject({ url: "/api/v1/console/auth/me", headers })).statusCode,
    401,
  );
  const relogin = await app.inject({
    method: "POST",
    url: "/api/v1/console/auth/login",
    payload: { username: "workflow_admin", password: input.newPassword },
  });
  assert.equal(relogin.statusCode, 200);
  assert.ok(!relogin.body.includes("password_hash"));
});
test("batch user status is atomic and revokes every affected APP session", async (t) => {
  const { app, headers } = await fixture();
  t.after(() => app.close());
  const users = [];
  for (const username of ["batch_first", "batch_second"])
    users.push(
      (
        await app.inject({
          method: "POST",
          url: "/api/v1/auth/register",
          payload: { username, password: "batch-test-password" },
        })
      ).json(),
    );
  const url = "/api/v1/console/users/batch-status";
  const ids = users.map((u) => u.user.id as string);
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url,
        headers,
        payload: { ids: [ids[0], "missing"], disabled: true },
      })
    ).statusCode,
    404,
  );
  assert.equal(
    (
      await app.inject({
        url: "/api/v1/auth/me",
        headers: { authorization: `Bearer ${users[0].token}` },
      })
    ).statusCode,
    200,
  );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url,
        headers,
        payload: { ids, disabled: true },
      })
    ).json().data.changed,
    2,
  );
  for (const u of users)
    assert.equal(
      (
        await app.inject({
          url: "/api/v1/auth/me",
          headers: { authorization: `Bearer ${u.token}` },
        })
      ).statusCode,
      401,
    );
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url,
        headers,
        payload: { ids, disabled: false },
      })
    ).json().data.changed,
    2,
  );
});
