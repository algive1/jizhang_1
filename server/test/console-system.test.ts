import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { mkdtemp, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createApp } from "../src/app.js";
import { encodePassword } from "../src/console/auth.js";

test("后端备份真实落盘并校验，更新仅接收签名回执且拒绝覆盖终态", async (t) => {
  const keys = [
    "BACKUP_DIR",
    "BACKEND_IMAGE_REPOSITORY",
    "BACKEND_DEPLOY_SECRET",
    "BACKEND_DEPLOY_URL",
  ];
  const old = keys.map((k) => process.env[k]);
  const fetcher = globalThis.fetch;
  const directory = await mkdtemp(join(tmpdir(), "backend-system-"));
  process.env.BACKUP_DIR = directory;
  process.env.BACKEND_IMAGE_REPOSITORY = "registry.example/backend";
  process.env.BACKEND_DEPLOY_SECRET = "secret".repeat(8);
  process.env.BACKEND_DEPLOY_URL = "https://deploy.example.test/tasks";
  const { app, store } = await createApp(":memory:");
  t.after(async () => {
    await app.close();
    globalThis.fetch = fetcher;
    await rm(directory, { recursive: true, force: true });
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
      "system-test",
      "system_admin",
      await encodePassword("system-admin-password"),
      "super",
      store.now(),
    );
  const login = (
    await app.inject({
      method: "POST",
      url: "/api/v1/console/auth/login",
      payload: { username: "system_admin", password: "system-admin-password" },
    })
  ).json();
  const headers = { authorization: `Bearer ${login.data.token}` };
  assert.equal(
    (await app.inject({ url: "/api/v1/console/system/status" })).statusCode,
    401,
  );
  const backup = await app.inject({
    method: "POST",
    url: "/api/v1/console/system/backups",
    headers,
  });
  assert.equal(backup.statusCode, 200, backup.body);
  assert.ok(
    (await stat(join(directory, backup.json().data.filename))).size > 0,
  );
  const image = "registry.example/backend@sha256:" + "a".repeat(64);
  const create = await app.inject({
    method: "POST",
    url: "/api/v1/console/system/updates",
    headers,
    payload: { version: "1.0.1", image, action: "update", reason: "test" },
  });
  assert.equal(create.statusCode, 200, create.body);
  const id = create.json().data.id;
  const result = { id, image, status: "succeeded", message: "健康检查通过" };
  const callback = (body: typeof result, signed = true) => {
    const raw = JSON.stringify(body),
      timestamp = String(store.now());
    return app.inject({
      method: "POST",
      url: "/api/v1/system/deployment-result",
      headers: {
        "Content-Type": "application/json",
        "X-Deploy-Timestamp": timestamp,
        "X-Deploy-Signature": signed
          ? createHmac("sha256", process.env.BACKEND_DEPLOY_SECRET!)
              .update(`${timestamp}.${raw}`)
              .digest("hex")
          : "b".repeat(64),
      },
      payload: raw,
    });
  };
  assert.equal((await callback(result, false)).statusCode, 401);
  assert.equal((await callback(result)).statusCode, 409, "草稿不能伪报已执行");
  globalThis.fetch = async (url, options) => {
    assert.equal(url, "https://deploy.example.test/tasks");
    const body = String(options?.body),
      payload = JSON.parse(body),
      requestHeaders = options?.headers as Record<string, string>;
    assert.equal(payload.id, id);
    assert.equal(payload.image, image);
    assert.equal(payload.backupId, backup.json().data.id);
    assert.equal(requestHeaders["Idempotency-Key"], id);
    assert.equal(
      requestHeaders["X-Deploy-Signature"],
      createHmac("sha256", process.env.BACKEND_DEPLOY_SECRET!)
        .update(`${requestHeaders["X-Deploy-Timestamp"]}.${body}`)
        .digest("hex"),
    );
    return new Response(JSON.stringify({ id, status: "accepted" }));
  };
  const dispatch = await app.inject({
    method: "POST",
    url: `/api/v1/console/system/updates/${id}/dispatch`,
    headers,
    payload: { confirmed: true },
  });
  assert.equal(dispatch.statusCode, 200, dispatch.body);
  assert.equal((await callback({ ...result, image: "other" })).statusCode, 409);
  assert.equal((await callback(result)).statusCode, 200);
  assert.equal((await callback(result)).statusCode, 200);
  assert.equal(
    (await callback({ ...result, status: "running" })).statusCode,
    409,
  );
  store.db.prepare("UPDATE console_admins SET role_id='support'").run();
  assert.equal(
    (
      await app.inject({
        method: "POST",
        url: "/api/v1/console/system/backups",
        headers,
      })
    ).statusCode,
    403,
  );
});
