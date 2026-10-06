import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import { requireCondition as check } from "../contract.js";
import { authorize, auditAction } from "./auth.js";
import { pageQuery, paginate } from "./query.js";

const userSelect = `SELECT u.id,u.username,u.display_name AS displayName,u.created_at AS createdAt,
  COALESCE(st.disabled,0) AS accountDisabled,(SELECT MAX(s.last_seen_at) FROM sessions s WHERE s.user_id=u.id) AS lastSeenAt,
  d.app_version AS appVersion,d.android_version AS androidVersion,d.brand,d.model,d.auto_enabled AS autoEnabled,d.backup_enabled AS backupEnabled,
  CASE WHEN COALESCE((SELECT expires_at FROM membership_adjustments WHERE user_id=u.id),0)>:now
    OR COALESCE((SELECT expires_at FROM membership_subscriptions WHERE user_id=u.id),0)>:now
    OR EXISTS(SELECT 1 FROM apple_transactions WHERE user_id=u.id AND revoked_at IS NULL AND expires_at>:now) THEN 1 ELSE 0 END AS member`;
const userFrom = `FROM users u LEFT JOIN console_user_state st ON st.user_id=u.id LEFT JOIN console_devices d ON d.rowid=(SELECT rowid FROM console_devices WHERE user_id=u.id ORDER BY last_seen_at DESC LIMIT 1)`;
export function registerUsers(app: FastifyInstance, store: Store) {
  const setStatus = (
    request: Parameters<typeof authorize>[1],
    ids: string[],
    disabled: boolean,
  ) => {
    const admin = authorize(store, request, "user:disable");
    return store.db.transaction(() => {
      const exists = store.db.prepare(
        "SELECT 1 FROM users WHERE id=? AND username NOT LIKE 'deleted_%'",
      );
      for (const id of ids)
        check(exists.get(id), "用户不存在，未修改任何账号", 404);
      const upsert = store.db.prepare(
        "INSERT INTO console_user_state VALUES(?,?) ON CONFLICT(user_id) DO UPDATE SET disabled=excluded.disabled",
      );
      const revoke = store.db.prepare("DELETE FROM sessions WHERE user_id=?");
      for (const id of ids) {
        upsert.run(id, Number(disabled));
        if (disabled) revoke.run(id);
        auditAction(
          store,
          admin,
          disabled ? "user:disable" : "user:enable",
          id,
        );
      }
      return { changed: ids.length };
    })();
  };
  app.get("/users", async (request) => {
    authorize(store, request, "user:list");
    const input = pageQuery
      .extend({
        status: z.enum(["enabled", "disabled"]).optional(),
        member: z.enum(["yes", "no"]).optional(),
        appVersion: z.string().max(40).optional(),
      })
      .parse(request.query);
    const filters = ["u.username NOT LIKE 'deleted_%'"];
    const args: unknown[] = [];
    if (input.q) {
      filters.push("(u.id=? OR u.username LIKE ? OR u.display_name LIKE ?)");
      args.push(input.q, `%${input.q}%`, `%${input.q}%`);
    }
    if (input.status) {
      filters.push("COALESCE(st.disabled,0)=?");
      args.push(Number(input.status === "disabled"));
    }
    if (input.appVersion) {
      filters.push("d.app_version=?");
      args.push(input.appVersion);
    }
    // Bind the same clock to count/filter and select; no per-row membership calls.
    const selected = userSelect.replaceAll(":now", String(store.now()));
    let from = `${userFrom} WHERE ${filters.join(" AND ")}`;
    let select = selected;
    if (input.member) {
      from = `FROM (${selected} ${from}) visible WHERE member=?`;
      select = "SELECT *";
      args.push(Number(input.member === "yes"));
    }
    const order = `${input.member ? input.sort : input.sort === "lastSeenAt" ? "lastSeenAt" : "u.created_at"} ${input.order.toUpperCase()},id ASC`;
    return paginate(store, input, select, from, args, order);
  });
  app.get("/users/:id", async (request) => {
    authorize(store, request, "user:view");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    const user = store.db
      .prepare(`${userSelect} ${userFrom} WHERE u.id=?`)
      .get({ now: store.now() }, id);
    check(user, "用户不存在", 404);
    return {
      user,
      counts: store.db
        .prepare("SELECT COUNT(*) AS books FROM members WHERE user_id=?")
        .get(id),
    };
  });
  app.patch("/users/:id/status", async (request) => {
    authorize(store, request, "user:disable");
    const { id } = z.object({ id: z.string().max(100) }).parse(request.params);
    const { disabled } = z
      .strictObject({ disabled: z.boolean() })
      .parse(request.body);
    return setStatus(request, [id], disabled);
  });
  app.post("/users/batch-status", async (request) => {
    authorize(store, request, "user:disable");
    const { ids, disabled } = z
      .strictObject({
        ids: z.array(z.string().min(1).max(100)).min(1).max(100),
        disabled: z.boolean(),
      })
      .parse(request.body);
    return setStatus(request, [...new Set(ids)], disabled);
  });
  app.get("/devices", async (request) => {
    authorize(store, request, "device:list");
    const input = pageQuery
      .extend({ userId: z.string().max(100).optional() })
      .parse(request.query);
    const args: unknown[] = [];
    const filters: string[] = [];
    if (input.userId) {
      filters.push("user_id=?");
      args.push(input.userId);
    }
    if (input.q) {
      filters.push("(app_version LIKE ? OR brand LIKE ? OR model LIKE ?)");
      args.push(...Array(3).fill(`%${input.q}%`));
    }
    return paginate(
      store,
      input,
      "SELECT user_id||':'||installation_id AS id,user_id AS userId,installation_id AS installationId,platform,app_version AS appVersion,android_version AS androidVersion,brand,model,auto_enabled AS autoEnabled,backup_enabled AS backupEnabled,last_seen_at AS lastSeenAt",
      `FROM console_devices ${filters.length ? "WHERE " + filters.join(" AND ") : ""}`,
      args,
      "last_seen_at DESC",
    );
  });
}
