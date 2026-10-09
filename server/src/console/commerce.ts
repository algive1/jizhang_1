import { createHash, randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import { catalogSchema, getMembershipCatalog } from "../membership_catalog.js";
import {
  adjustMembership,
  membershipAdjustmentSchema,
} from "../membership_admin.js";
import { membershipCurrent } from "../payment.js";
import {
  integrationFields,
  integrationStatus,
  saveIntegration,
} from "../integrations.js";
import { requireCondition as check } from "../contract.js";
import { authorize, auditAction } from "./auth.js";
import { pageQuery, paginate } from "./query.js";

export function registerCommerce(app: FastifyInstance, store: Store) {
  store.db
    .exec(`CREATE TABLE IF NOT EXISTS console_membership_revisions(revision INTEGER PRIMARY KEY,catalog_json TEXT NOT NULL,note TEXT NOT NULL,created_by TEXT,created_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS console_membership_history(id TEXT PRIMARY KEY,user_id TEXT NOT NULL,actor_id TEXT NOT NULL,product_id TEXT,duration_days INTEGER NOT NULL,reason TEXT NOT NULL,created_at INTEGER NOT NULL);`);
  const currentHash = () =>
    createHash("sha256")
      .update(JSON.stringify(getMembershipCatalog(store)))
      .digest("hex");
  const latestRevision = () =>
    Number(
      (
        store.db
          .prepare(
            "SELECT MAX(revision) AS n FROM console_membership_revisions",
          )
          .get() as { n: number | null }
      ).n ?? 0,
    );
  app.get("/membership/catalog", async (req) => {
    authorize(store, req, "membership:view");
    const latest = store.db
      .prepare(
        "SELECT revision,catalog_json AS catalogJson,note FROM console_membership_revisions ORDER BY revision DESC LIMIT 1",
      )
      .get() as
      | { revision: number; catalogJson: string; note: string }
      | undefined;
    return {
      catalog: getMembershipCatalog(store),
      draft: latest
        ? JSON.parse(latest.catalogJson)
        : getMembershipCatalog(store),
      revision: latest?.revision ?? 0,
      publishedHash: currentHash(),
      note: latest?.note ?? "",
    };
  });
  app.post("/membership/catalog", async (req) => {
    const admin = authorize(store, req, "membership:edit");
    const input = z
      .strictObject({
        catalog: catalogSchema,
        baseRevision: z.number().int().nonnegative(),
        note: z.string().trim().min(1).max(300),
      })
      .parse(req.body);
    return store.db.transaction(() => {
      check(
        latestRevision() === input.baseRevision,
        "套餐已被其他管理员修改，请刷新",
        409,
      );
      const revision = input.baseRevision + 1;
      store.db
        .prepare("INSERT INTO console_membership_revisions VALUES(?,?,?,?,?)")
        .run(
          revision,
          JSON.stringify(input.catalog),
          input.note,
          admin.id,
          store.now(),
        );
      auditAction(store, admin, "membership:draft", String(revision));
      return { revision };
    })();
  });
  app.get("/membership/history", async (req) => {
    authorize(store, req, "membership:view");
    return paginate(
      store,
      pageQuery.parse(req.query),
      "SELECT revision AS id,revision,note,created_at AS createdAt,created_by AS createdBy",
      "FROM console_membership_revisions",
      [],
      "revision DESC",
    );
  });
  app.post("/membership/catalog/:revision/publish", async (req) => {
    const admin = authorize(store, req, "membership:publish");
    const { revision } = z
      .object({ revision: z.coerce.number().int().positive() })
      .parse(req.params);
    const { publishedHash } = z
      .strictObject({ publishedHash: z.string().length(64) })
      .parse(req.body);
    return store.db.transaction(() => {
      check(
        currentHash() === publishedHash,
        "线上套餐已变化，请刷新后重新发布",
        409,
      );
      const row = store.db
        .prepare(
          "SELECT catalog_json FROM console_membership_revisions WHERE revision=?",
        )
        .get(revision) as { catalog_json: string } | undefined;
      check(row, "套餐修订不存在", 404);
      const catalog = catalogSchema.parse(JSON.parse(row.catalog_json));
      store.db
        .prepare("UPDATE membership_catalog SET data_json=? WHERE id=1")
        .run(JSON.stringify(catalog));
      auditAction(store, admin, "membership:publish", String(revision));
      return { catalog, publishedHash: currentHash() };
    })();
  });
  app.get("/membership/users/:id", async (req) => {
    authorize(store, req, "membership:view");
    const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
    check(
      store.db.prepare("SELECT 1 FROM users WHERE id=?").get(id),
      "用户不存在",
      404,
    );
    return {
      snapshot: membershipCurrent(store, id, true),
      history: store.db
        .prepare(
          "SELECT h.id,h.product_id AS productId,h.duration_days AS durationDays,h.reason,h.created_at AS createdAt,a.username AS actor FROM console_membership_history h LEFT JOIN console_admins a ON a.id=h.actor_id WHERE h.user_id=? ORDER BY h.created_at DESC,h.id DESC LIMIT 100",
        )
        .all(id),
    };
  });
  app.put("/membership/users/:id", async (req) => {
    const admin = authorize(store, req, "membership:adjust");
    const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
    const input = membershipAdjustmentSchema.parse(req.body);
    return store.db.transaction(() => {
      const snapshot = adjustMembership(store, id, input);
      store.db
        .prepare("INSERT INTO console_membership_history VALUES(?,?,?,?,?,?,?)")
        .run(
          randomUUID(),
          id,
          admin.id,
          input.productId,
          input.durationDays,
          input.reason,
          store.now(),
        );
      auditAction(store, admin, "membership:adjust", id);
      return snapshot;
    })();
  });
  const providerSchema = z.object({
    provider: z.enum(
      Object.keys(integrationFields) as ["wechat", "alipay", "asr"],
    ),
  });
  app.get("/integrations/:provider", async (req) => {
    const { provider } = providerSchema.parse(req.params);
    authorize(
      store,
      req,
      provider === "asr" ? "ai:model:view" : "payment:view",
    );
    return integrationStatus(store, provider);
  });
  app.put("/integrations/:provider", async (req) => {
    const { provider } = providerSchema.parse(req.params);
    const admin = authorize(
      store,
      req,
      provider === "asr" ? "ai:model:edit" : "payment:configure",
    );
    const { values } = z
      .strictObject({
        values: z.record(z.string(), z.string().trim().max(32000)),
      })
      .parse(req.body);
    store.db.transaction(() => {
      saveIntegration(store, provider, values);
      auditAction(store, admin, "integration:configure", provider);
    })();
    return integrationStatus(store, provider);
  });
}
