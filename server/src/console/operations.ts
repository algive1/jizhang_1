import { randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import { requireCondition as check } from "../contract.js";
import { authorize, auditAction } from "./auth.js";
import { pageQuery, paginate, redact } from "./query.js";
import { createAnnouncement } from "../message_center.js";
import { replySupportTicket } from '../support.js';

const operationKind = z.enum(["faq", "banner", "activity"]);
const input = z.strictObject({
  kind: operationKind,
  title: z.string().trim().min(1).max(100),
  body: z.string().trim().min(1).max(4000),
  enabled: z.boolean(),
});
export function registerOperations(app: FastifyInstance, store: Store) {
  app.get("/diagnostics", async (request) => {
    authorize(store, request, "auto-accounting:event:list");
    const query = pageQuery.parse(request.query);
    return paginate(
      store,
      query,
      "SELECT user_id||':'||event_id AS id,user_id AS userId,event_id AS eventId,occurred_at AS occurredAt,level,kind",
      "FROM diagnostic_events WHERE kind LIKE ?",
      [`%${query.q}%`],
      "occurred_at DESC",
    );
  });
  app.get("/backups", async (request) => {
    authorize(store, request, "backup:status:view");
    const query = pageQuery.parse(request.query);
    return paginate(
      store,
      query,
      "SELECT user_id AS userId,dataset_id AS datasetId,revision,has_snapshot AS hasSnapshot,snapshot_size AS size,snapshot_sha256 AS checksum,updated_at AS updatedAt",
      "FROM cloud_datasets WHERE user_id LIKE ?",
      [`%${query.q}%`],
      "updated_at DESC",
    );
  });
  app.get("/backups/summary", async (request) => {
    authorize(store, request, "backup:status:view");
    return {
      storage: store.db
        .prepare(
          "SELECT COUNT(*) AS datasets,SUM(has_snapshot) AS snapshots,COALESCE(SUM(snapshot_size),0) AS bytes FROM cloud_datasets",
        )
        .get(),
      encryption:
        "现有备份格式为 gzip 压缩，尚未端到端加密。管理 API 不读取或返回 snapshot_blob。",
      integration:
        "TODO：加密备份 v3、备份任务遥测与恢复记录；现有账号备份通道保持兼容。",
    };
  });
  app.get("/feedback", async (request) => {
    authorize(store, request, "feedback:view");
    const query = pageQuery
      .extend({
        userId: z.string().max(100).optional(),
        status: z
          .enum(["open", "in_progress", "resolved", "closed"])
          .optional(),
      })
      .parse(request.query);
    const filters = ["subject LIKE ?"],
      args: unknown[] = [`%${query.q}%`];
    if (query.userId) {
      filters.push("user_id=?");
      args.push(query.userId);
    }
    if (query.status) {
      filters.push("status=?");
      args.push(query.status);
    }
    const page = paginate<{
      id: string;
      userId: string | null;
      subject: string;
      status: string;
      appVersion: string | null;
      createdAt: number;
      updatedAt: number;
    }>(
      store,
      query,
      "SELECT id,user_id AS userId,subject,status,app_version AS appVersion,created_at AS createdAt,updated_at AS updatedAt",
      `FROM support_tickets WHERE ${filters.join(" AND ")}`,
      args,
      "updated_at DESC",
    );
    return {
      ...page,
      items: page.items.map((row) => ({
        ...row,
        subject: redact(row.subject),
      })),
    };
  });
  app.get("/feedback/:id", async (request) => {
    authorize(store, request, "feedback:view");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    const ticket = store.db
      .prepare(
        "SELECT id,subject,status,app_version AS appVersion FROM support_tickets WHERE id=?",
      )
      .get(id) as
      | {
          id: string;
          subject: string;
          status: string;
          appVersion: string | null;
        }
      | undefined;
    check(ticket, "反馈不存在", 404);
    const messages = paginate<{
      id: string;
      authorType: string;
      body: string;
      createdAt: number;
    }>(
      store,
      pageQuery.parse(request.query),
      "SELECT id,author_type AS authorType,body,created_at AS createdAt",
      "FROM support_ticket_messages WHERE ticket_id=?",
      [id],
      "created_at ASC,id",
    );
    return {
      ticket: { ...ticket, subject: redact(ticket.subject) },
      messages: {
        ...messages,
        items: messages.items.map((row) => ({
          ...row,
          body: redact(row.body),
        })),
      },
    };
  });
  app.patch("/feedback/:id/status", async (request) => {
    const admin = authorize(store, request, "feedback:edit");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    const { status } = z
      .strictObject({
        status: z.enum(["open", "in_progress", "resolved", "closed"]),
      })
      .parse(request.body);
    check(
      store.db.prepare("SELECT 1 FROM support_tickets WHERE id=?").get(id),
      "反馈不存在",
      404,
    );
    store.db.transaction(() => {
      store.db
        .prepare(
          "UPDATE support_tickets SET status=?,updated_at=?,resolved_at=? WHERE id=?",
        )
        .run(
          status,
          store.now(),
          status === "resolved" || status === "closed" ? store.now() : null,
          id,
        );
      auditAction(store, admin, "feedback:status:" + status, id);
    })();
    return { ok: true };
  });
  app.post('/feedback/:id/messages',async request=>{
    const admin=authorize(store,request,'feedback:edit'),{id}=z.object({id:z.uuid()}).parse(request.params),{body}=z.strictObject({body:z.string().trim().min(1).max(4000)}).parse(request.body);
    return store.db.transaction(()=>{const result=replySupportTicket(store,id,body);auditAction(store,admin,'feedback:reply',id);return {...result,body:redact(result.body)};})();
  });
  app.get("/operations", async (request) => {
    authorize(store, request, "operations:view");
    const query = pageQuery
      .extend({ kind: operationKind.optional() })
      .parse(request.query);
    return paginate(
      store,
      query,
      "SELECT id,kind,title,body,enabled,updated_at AS updatedAt",
      `FROM console_operations WHERE title LIKE ?${query.kind ? " AND kind=?" : ""}`,
      query.kind ? [`%${query.q}%`, query.kind] : [`%${query.q}%`],
      "updated_at DESC",
    );
  });
  const save = (
    id: string | undefined,
    request: Parameters<typeof authorize>[1],
  ) => {
    const admin = authorize(store, request, "operations:edit");
    const value = input.parse(request.body);
    const target = id ?? randomUUID();
    check(
      !id ||
        store.db.prepare("SELECT 1 FROM console_operations WHERE id=?").get(id),
      "内容不存在",
      404,
    );
    store.db.transaction(() => {
      store.db
        .prepare(
          "INSERT INTO console_operations VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET kind=excluded.kind,title=excluded.title,body=excluded.body,enabled=excluded.enabled,updated_at=excluded.updated_at",
        )
        .run(
          target,
          value.kind,
          value.title,
          value.body,
          Number(value.enabled),
          store.now(),
        );
      auditAction(store, admin, "operations:update", target);
    })();
    return { id: target };
  };
  app.post("/operations", async (request) => save(undefined, request));
  app.put("/operations/:id", async (request) =>
    save(
      z.object({ id: z.string().max(100) }).parse(request.params).id,
      request,
    ),
  );
  app.get("/announcements", async (request) => {
    authorize(store, request, "operations:view");
    const query = pageQuery.parse(request.query);
    return paginate(
      store,
      query,
      "SELECT id,title,body,published_at AS publishedAt,expires_at AS expiresAt",
      "FROM announcements WHERE title LIKE ?",
      [`%${query.q}%`],
      "published_at DESC",
    );
  });
  app.post("/announcements", async (request) => {
    const admin = authorize(store, request, "operations:publish");
    const value = z
      .strictObject({
        title: z.string().trim().min(1).max(100),
        body: z.string().trim().min(1).max(4000),
      })
      .parse(request.body);
    return store.db.transaction(() => {
      const announcement = createAnnouncement(store, value);
      auditAction(store, admin, "announcement:publish", announcement.id);
      return announcement;
    })();
  });
}
export function registerPublicOperations(app: FastifyInstance, store: Store) {
  app.get("/api/v1/app/operations", async (request) => {
    const { kind } = z.object({ kind: operationKind }).parse(request.query);
    return {
      items: store.db
        .prepare(
          "SELECT id,title,body,updated_at AS updatedAt FROM console_operations WHERE kind=? AND enabled=1 ORDER BY updated_at DESC LIMIT 50",
        )
        .all(kind),
      integration:
        "TODO：APP 接入 Banner / FAQ / 活动渲染；公告沿用现有消息中心。",
    };
  });
}
