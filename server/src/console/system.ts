import {
  createHash,
  createHmac,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import { createReadStream } from "node:fs";
import { mkdir, stat } from "node:fs/promises";
import { basename, join, resolve } from "node:path";
import Database from "better-sqlite3";
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import { requireCondition as check } from "../contract.js";
import { authorize, auditAction } from "./auth.js";
import { pageQuery, paginate, redact } from "./query.js";
import { semver } from "./releases.js";

type UpdateJob = {
  id: string;
  version: string;
  image: string;
  action: string;
  status: string;
  backup_id: string | null;
};
export function registerSystem(app: FastifyInstance, store: Store) {
  store.db.exec(
    "CREATE TABLE IF NOT EXISTS system_backups(id TEXT PRIMARY KEY,filename TEXT NOT NULL,size_bytes INTEGER NOT NULL,sha256 TEXT NOT NULL,created_at INTEGER NOT NULL);CREATE TABLE IF NOT EXISTS system_updates(id TEXT PRIMARY KEY,version TEXT NOT NULL,image TEXT NOT NULL,action TEXT NOT NULL,reason TEXT NOT NULL,status TEXT NOT NULL,backup_id TEXT,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,actor_id TEXT NOT NULL,message TEXT NOT NULL DEFAULT '')",
  );
  const started = Date.now();
  let backingUp = false;
  app.get("/system/status", async (request) => {
    authorize(store, request, "system:maintenance:view");
    return {
      version: process.env.BACKEND_VERSION ?? "development",
      image: process.env.BACKEND_IMAGE ?? null,
      databaseVersion: store.db.pragma("user_version", { simple: true }),
      uptimeSeconds: Math.floor((Date.now() - started) / 1000),
      testingFreeAccess: process.env.ALL_FEATURES_FREE_FOR_TESTING === "true",
      deploymentConfigured: Boolean(
        process.env.BACKEND_DEPLOY_URL && process.env.BACKEND_DEPLOY_SECRET,
      ),
      imageRepository: process.env.BACKEND_IMAGE_REPOSITORY ?? "",
      latestBackup:
        store.db
          .prepare(
            "SELECT id,filename,size_bytes AS sizeBytes,sha256,created_at AS createdAt FROM system_backups ORDER BY created_at DESC LIMIT 1",
          )
          .get() ?? null,
    };
  });
  app.get("/system/backups", async (request) => {
    authorize(store, request, "system:maintenance:view");
    return paginate(
      store,
      pageQuery.parse(request.query),
      "SELECT id,filename,size_bytes AS sizeBytes,sha256,created_at AS createdAt",
      "FROM system_backups",
    );
  });
  app.post("/system/backups", async (request) => {
    const admin = authorize(store, request, "system:backup");
    check(!backingUp, "备份正在执行", 409);
    backingUp = true;
    try {
      const id = randomUUID(),
        filename = `backend-${store.now()}-${id}.sqlite`,
        directory = resolve(process.env.BACKUP_DIR ?? "backups");
      await mkdir(directory, { recursive: true });
      const path = join(directory, basename(filename));
      await store.db.backup(path);
      const snapshot = new Database(path, {
        readonly: true,
        fileMustExist: true,
      });
      try {
        check(
          snapshot.pragma("integrity_check", { simple: true }) === "ok",
          "备份完整性校验失败",
          500,
        );
      } finally {
        snapshot.close();
      }
      const digest = createHash("sha256");
      for await (const chunk of createReadStream(path)) digest.update(chunk);
      const bytes = (await stat(path)).size;
      store.db.transaction(() => {
        store.db
          .prepare("INSERT INTO system_backups VALUES(?,?,?,?,?)")
          .run(id, filename, bytes, digest.digest("hex"), store.now());
        auditAction(store, admin, "system:backup", id);
      })();
      return { id, filename, sizeBytes: bytes };
    } finally {
      backingUp = false;
    }
  });
  app.get("/system/updates", async (request) => {
    authorize(store, request, "system:maintenance:view");
    return paginate(
      store,
      pageQuery.parse(request.query),
      "SELECT id,version,image,action,reason,status,backup_id AS backupId,message,created_at AS createdAt,updated_at AS updatedAt",
      "FROM system_updates",
    );
  });
  app.post("/system/updates", async (request) => {
    const admin = authorize(store, request, "system:update");
    const input = z
      .strictObject({
        version: semver,
        image: z
          .string()
          .max(400)
          .regex(/^[a-zA-Z0-9._:/-]+@sha256:[a-f0-9]{64}$/),
        action: z.enum(["update", "rollback"]),
        reason: z.string().trim().min(1).max(300),
      })
      .parse(request.body);
    const repository = process.env.BACKEND_IMAGE_REPOSITORY;
    check(
      repository && input.image.split("@")[0] === repository,
      "镜像必须来自部署配置指定的仓库并固定 SHA256 摘要",
      400,
    );
    const id = randomUUID();
    store.db.transaction(() => {
      store.db
        .prepare(
          "INSERT INTO system_updates(id,version,image,action,reason,status,created_at,updated_at,actor_id) VALUES(?,?,?,?,?,'draft',?,?,?)",
        )
        .run(
          id,
          input.version,
          input.image,
          input.action,
          input.reason,
          store.now(),
          store.now(),
          admin.id,
        );
      auditAction(store, admin, "system:update:draft", id);
    })();
    return { id };
  });
  app.post("/system/updates/:id/dispatch", async (request) => {
    const admin = authorize(store, request, "system:update"),
      { id } = z.object({ id: z.uuid() }).parse(request.params);
    z.strictObject({ confirmed: z.literal(true) }).parse(request.body);
    const row = store.db
      .prepare("SELECT * FROM system_updates WHERE id=?")
      .get(id) as UpdateJob | undefined;
    check(row, "更新任务不存在", 404);
    check(
      ["draft", "dispatching"].includes(row.status),
      "任务已经执行，请刷新查看结果",
      409,
    );
    const url = process.env.BACKEND_DEPLOY_URL,
      secret = process.env.BACKEND_DEPLOY_SECRET;
    check(
      url && secret && secret.length >= 32,
      "尚未配置受控部署服务，任务保留为草稿",
      503,
    );
    const endpoint = new URL(url);
    check(
      endpoint.protocol === "https:" &&
        !endpoint.username &&
        !endpoint.password,
      "部署服务必须使用 HTTPS 且不能在 URL 中包含凭据",
      503,
    );
    check(
      row.image.split("@")[0] === process.env.BACKEND_IMAGE_REPOSITORY,
      "镜像仓库配置已变化，请重新创建任务",
      409,
    );
    const backup = store.db
      .prepare(
        "SELECT id FROM system_backups WHERE created_at>? ORDER BY created_at DESC LIMIT 1",
      )
      .get(store.now() - 3600) as { id: string } | undefined;
    check(backup, "执行前请完成一次新的后台数据库备份", 409);
    check(
      !store.db
        .prepare(
          "SELECT 1 FROM system_updates WHERE id<>? AND status IN ('dispatching','accepted','running')",
        )
        .get(id),
      "另一个更新任务正在执行",
      409,
    );
    const body = JSON.stringify({
        id: row.id,
        version: row.version,
        image: row.image,
        action: row.action,
        backupId: row.backup_id ?? backup.id,
        databaseVersion: store.db.pragma("user_version", { simple: true }),
      }),
      timestamp = String(store.now());
    store.db.transaction(() => {
      store.db
        .prepare(
          "UPDATE system_updates SET status='dispatching',backup_id=COALESCE(backup_id,?),updated_at=? WHERE id=?",
        )
        .run(backup.id, store.now(), id);
      auditAction(store, admin, "system:update:dispatch", id);
    })();
    const response = await fetch(url, {
      method: "POST",
      redirect: "error",
      headers: {
        "Content-Type": "application/json",
        "X-Deploy-Timestamp": timestamp,
        "X-Deploy-Signature": createHmac("sha256", secret)
          .update(`${timestamp}.${body}`)
          .digest("hex"),
        "Idempotency-Key": id,
      },
      body,
      signal: AbortSignal.timeout(10000),
    });
    const result = (await response.json()) as { id?: string; status?: string };
    check(
      response.ok && result.id === id && result.status === "accepted",
      "部署服务未确认接收；可使用同一任务编号重新查询或提交",
      502,
    );
    store.db
      .prepare(
        "UPDATE system_updates SET status='accepted',updated_at=? WHERE id=? AND status='dispatching'",
      )
      .run(store.now(), id);
    return { id, status: "accepted" };
  });
}
export function registerDeploymentCallback(app: FastifyInstance, store: Store) {
  app.post(
    "/api/v1/system/deployment-result",
    {
      config: { rawBody: true, rateLimit: { max: 30, timeWindow: "1 minute" } },
    },
    async (request) => {
      const secret = process.env.BACKEND_DEPLOY_SECRET,
        raw = String(
          (request as unknown as { rawBody?: string }).rawBody ?? "",
        ),
        timestamp = String(request.headers["x-deploy-timestamp"] ?? ""),
        signature = String(request.headers["x-deploy-signature"] ?? "");
      check(
        secret &&
          /^\d{10}$/.test(timestamp) &&
          Math.abs(store.now() - Number(timestamp)) <= 300 &&
          /^[a-f0-9]{64}$/.test(signature),
        "部署回执认证失败",
        401,
      );
      const expected = createHmac("sha256", secret)
        .update(`${timestamp}.${raw}`)
        .digest();
      check(
        timingSafeEqual(expected, Buffer.from(signature, "hex")),
        "部署回执认证失败",
        401,
      );
      const input = z
        .strictObject({
          id: z.uuid(),
          image: z.string().max(400),
          status: z.enum(["running", "succeeded", "failed"]),
          message: z.string().trim().max(1000),
        })
        .parse(request.body);
      const row = store.db
        .prepare("SELECT * FROM system_updates WHERE id=?")
        .get(input.id) as UpdateJob | undefined;
      check(
        row && row.image === input.image && row.status !== "draft",
        "更新任务或镜像不匹配",
        409,
      );
      if (["succeeded", "failed"].includes(row.status)) {
        check(row.status === input.status, "任务已结束，不能覆盖结果", 409);
        return { accepted: true };
      }
      store.db
        .prepare(
          "UPDATE system_updates SET status=?,message=?,updated_at=? WHERE id=?",
        )
        .run(input.status, redact(input.message), store.now(), input.id);
      return { accepted: true };
    },
  );
}
