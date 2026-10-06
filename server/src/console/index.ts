import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import { ensureConsoleSchema } from "./schema.js";
import { bootstrapAdmin, authorize, registerAuth } from "./auth.js";
import { registerUsers } from "./users.js";
import { registerDashboard } from "./dashboard.js";
import { registerReleases } from "./releases.js";
import { getPublishedDocuments, registerDocuments } from "./documents.js";
import { pageQuery, paginate } from "./query.js";
import { registerEventManagement, registerEventIngestion } from "./events.js";
import { registerAIManagement } from "./ai.js";
import { registerOperations, registerPublicOperations } from "./operations.js";
import { registerPushManagement } from "./push.js";

export type Authenticate = (header: string | undefined) => {
  id: string;
  username: string;
};
export async function registerConsole(
  app: FastifyInstance,
  store: Store,
  authenticate: Authenticate,
) {
  ensureConsoleSchema(store);
  await bootstrapAdmin(store);
  await app.register(
    async (consoleApp) => {
      consoleApp.addHook("onSend", async (_request, reply, payload) => {
        reply.header("Cache-Control", "no-store");
        return payload;
      });
      consoleApp.addHook(
        "preSerialization",
        async (_request, reply, payload) =>
          reply.statusCode < 400 ? { data: payload } : payload,
      );
      registerAuth(consoleApp, store);
      registerUsers(consoleApp, store);
      registerDashboard(consoleApp, store);
      registerReleases(consoleApp, store);
      registerDocuments(consoleApp, store);
      registerEventManagement(consoleApp, store);
      registerAIManagement(consoleApp, store);
      registerOperations(consoleApp, store);
      registerPushManagement(consoleApp, store);
      consoleApp.get("/audit", async (request) => {
        authorize(store, request, "system:audit");
        const input = pageQuery.parse(request.query);
        return paginate(
          store,
          input,
          "SELECT l.id,a.username AS actor,l.action,l.target,l.created_at AS createdAt",
          "FROM console_audit l LEFT JOIN console_admins a ON a.id=l.admin_id WHERE l.action LIKE ?",
          [`%${input.q}%`],
          "l.id DESC",
        );
      });
    },
    { prefix: "/api/v1/console" },
  );
  registerEventIngestion(app, store, authenticate);
  registerPublicOperations(app, store);
  const publicQuery = z.object({
    installationId: z
      .string()
      .regex(/^[a-f0-9]{32}$/)
      .optional(),
  });
  app.get("/api/v1/app/config", async (request) => {
    const { installationId } = publicQuery.parse(request.query);
    return {
      documents: getPublishedDocuments(store, "config", installationId),
      integration: "客户端需校验与缓存；未接入前不改变本地设置",
    };
  });
  app.get("/api/v1/app/rules", async (request) => {
    const { installationId } = publicQuery.parse(request.query);
    return {
      documents: getPublishedDocuments(store, "rule", installationId),
      integration: "客户端需保留本地默认规则",
    };
  });
  app.post("/api/v1/app/heartbeat", async (request) => {
    const user = authenticate(request.headers.authorization);
    const v = z
      .strictObject({
        installationId: z.string().regex(/^[a-f0-9]{32}$/),
        platform: z.enum(["android", "ios"]),
        appVersion: z.string().regex(/^\d+\.\d+\.\d+$/),
        androidVersion: z.string().max(30).optional(),
        brand: z.string().max(50).optional(),
        model: z.string().max(80).optional(),
        autoEnabled: z.boolean().optional(),
        backupEnabled: z.boolean().optional(),
      })
      .parse(request.body);
    store.db
      .prepare(
        "INSERT INTO console_devices VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(user_id,installation_id) DO UPDATE SET platform=excluded.platform,app_version=excluded.app_version,android_version=excluded.android_version,brand=excluded.brand,model=excluded.model,auto_enabled=excluded.auto_enabled,backup_enabled=excluded.backup_enabled,last_seen_at=excluded.last_seen_at",
      )
      .run(
        user.id,
        v.installationId,
        v.platform,
        v.appVersion,
        v.androidVersion ?? null,
        v.brand ?? null,
        v.model ?? null,
        v.autoEnabled == null ? null : Number(v.autoEnabled),
        v.backupEnabled == null ? null : Number(v.backupEnabled),
        store.now(),
      );
    return { ok: true };
  });
}
