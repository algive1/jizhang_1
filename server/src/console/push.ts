import { randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import { requireCondition as check } from "../contract.js";
import {
  ensurePushDeliverySchema,
  queuePushForUser,
} from "../push_delivery.js";
import { authorize, auditAction, assertUserEnabled } from "./auth.js";
import { pageQuery, paginate } from "./query.js";

type Campaign = {
  id: string;
  userId: string;
  title: string;
  body: string;
  route: string | null;
  state: "draft" | "queued" | "stopped";
  deviceCount: number;
  createdAt: number;
  publishedAt: number | null;
};
const projection =
  "SELECT id,user_id AS userId,title,body,route,state,device_count AS deviceCount,created_at AS createdAt,published_at AS publishedAt FROM console_push_campaigns";
function configured(provider: string) {
  const keys =
    provider === "fcm"
      ? ["FCM_PROJECT_ID", "FCM_CLIENT_EMAIL", "FCM_PRIVATE_KEY"]
      : provider === "apns"
        ? ["APNS_KEY_ID", "APNS_TEAM_ID", "APNS_PRIVATE_KEY", "APNS_BUNDLE_ID"]
        : ["VENDOR_PUSH_URL", "VENDOR_PUSH_TOKEN"];
  return keys.every((key) => Boolean(process.env[key]?.trim()));
}
export function registerPushManagement(app: FastifyInstance, store: Store) {
  ensurePushDeliverySchema(store);
  const campaign = (id: string) => {
    const row = store.db.prepare(`${projection} WHERE id=?`).get(id) as
      | Campaign
      | undefined;
    check(row, "推送任务不存在", 404);
    return row;
  };
  app.get("/push/campaigns", async (request) => {
    authorize(store, request, "operations:push:view");
    const query = pageQuery.parse(request.query);
    return paginate(
      store,
      query,
      projection.split(" FROM ")[0]!,
      "FROM console_push_campaigns WHERE title LIKE ?",
      [`%${query.q}%`],
    );
  });
  app.post("/push/campaigns", async (request) => {
    const admin = authorize(store, request, "operations:push:edit");
    const input = z
      .strictObject({
        userId: z.string().min(1).max(100),
        title: z.string().trim().min(1).max(80),
        body: z.string().trim().min(1).max(500),
        route: z
          .enum(["/profile/messages", "/profile", "/"])
          .nullable()
          .default(null),
      })
      .parse(request.body);
    check(
      store.db.prepare("SELECT 1 FROM users WHERE id=?").get(input.userId),
      "目标用户不存在",
      404,
    );
    const id = randomUUID();
    store.db.transaction(() => {
      store.db
        .prepare(
          "INSERT INTO console_push_campaigns(id,user_id,title,body,route,created_by,created_at) VALUES(?,?,?,?,?,?,?)",
        )
        .run(
          id,
          input.userId,
          input.title,
          input.body,
          input.route,
          admin.id,
          store.now(),
        );
      auditAction(store, admin, "push:create-draft", id);
    })();
    return { id };
  });
  app.get("/push/campaigns/:id", async (request) => {
    authorize(store, request, "operations:push:view");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    const row = campaign(id);
    const providers = store.db
      .prepare(
        "SELECT provider,COUNT(*) AS devices FROM push_devices WHERE user_id=? GROUP BY provider",
      )
      .all(row.userId) as Array<{ provider: string; devices: number }>;
    return {
      campaign: row,
      providers: providers.map((p) => ({
        ...p,
        configured: configured(p.provider),
      })),
      delivery: store.db
        .prepare(
          "SELECT status,COUNT(*) AS count FROM push_outbox o JOIN console_push_jobs j ON j.job_id=o.id WHERE j.campaign_id=? GROUP BY status",
        )
        .all(id),
    };
  });
  app.get("/push/campaigns/:id/jobs", async (request) => {
    authorize(store, request, "operations:push:view");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    campaign(id);
    return paginate(
      store,
      pageQuery.parse(request.query),
      "SELECT o.id,platform,provider,status,attempts,created_at AS createdAt,sent_at AS sentAt",
      "FROM push_outbox o JOIN console_push_jobs j ON j.job_id=o.id WHERE j.campaign_id=?",
      [id],
      "created_at DESC,o.id",
    );
  });
  app.post("/push/campaigns/:id/publish", async (request) => {
    const admin = authorize(store, request, "operations:push:publish");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    z.strictObject({ confirmed: z.literal(true) }).parse(request.body);
    return store.db.transaction(() => {
      const row = campaign(id);
      if (row.state === "queued") return { deviceCount: row.deviceCount };
      check(row.state === "draft", "已停止的任务不能重新发布", 409);
      assertUserEnabled(store, row.userId);
      const providers = store.db
        .prepare(
          "SELECT provider,COUNT(*) AS devices FROM push_devices WHERE user_id=? GROUP BY provider",
        )
        .all(row.userId) as Array<{ provider: string; devices: number }>;
      const count = providers.reduce((sum, p) => sum + p.devices, 0);
      check(
        count > 0 && count <= 100,
        "目标用户需有 1～100 台已注册推送设备",
        400,
      );
      check(
        providers.every((p) => configured(p.provider)),
        "请先在服务端配置目标设备的推送 Provider",
        400,
      );
      const link = store.db.prepare(
        "INSERT INTO console_push_jobs(job_id,campaign_id) VALUES(?,?)",
      );
      const deviceCount = queuePushForUser(store, row.userId, row, (jobId) => {
        link.run(jobId, id);
      });
      store.db
        .prepare(
          "UPDATE console_push_campaigns SET state='queued',device_count=?,published_at=? WHERE id=?",
        )
        .run(deviceCount, store.now(), id);
      auditAction(store, admin, "push:enqueue", id);
      return { deviceCount };
    })();
  });
  app.post("/push/campaigns/:id/stop", async (request) => {
    const admin = authorize(store, request, "operations:push:publish");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    campaign(id);
    return store.db.transaction(() => {
      const cancelled = store.db
        .prepare(
          "UPDATE push_outbox SET status='cancelled' WHERE status='pending' AND id IN (SELECT job_id FROM console_push_jobs WHERE campaign_id=?)",
        )
        .run(id).changes;
      store.db
        .prepare("UPDATE console_push_campaigns SET state='stopped' WHERE id=?")
        .run(id);
      auditAction(store, admin, "push:stop", id);
      return { cancelled };
    })();
  });
}
