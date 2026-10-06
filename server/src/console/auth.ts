import {
  createHash,
  randomBytes,
  randomUUID,
  scrypt as scryptCallback,
  timingSafeEqual,
} from "node:crypto";
import { promisify } from "node:util";
import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import { requireCondition as check } from "../contract.js";
import type { Store } from "../store.js";
import {
  initialRoles,
  menus,
  permissionCatalog,
  type Permission,
} from "./permissions.js";
import { pageQuery, paginate } from "./query.js";

const scrypt = promisify(scryptCallback);
const hashToken = (value: string) =>
  createHash("sha256").update(value).digest("hex");
const credentials = z.strictObject({
  username: z
    .string()
    .trim()
    .regex(/^[a-zA-Z0-9_]{3,40}$/),
  password: z.string().min(12).max(128),
});
export type Admin = {
  id: string;
  username: string;
  roleId: string;
  permissions: Permission[];
};
type AdminRow = {
  id: string;
  username: string;
  roleId: string;
  permissionsJson: string;
  passwordHash: string;
};
export async function encodePassword(value: string) {
  const salt = randomBytes(16).toString("hex");
  return `${salt}:${((await scrypt(value, salt, 64)) as Buffer).toString("hex")}`;
}
async function matches(value: string, encoded: string) {
  const [salt, digest] = encoded.split(":");
  const actual = (await scrypt(value, salt ?? "missing", 64)) as Buffer;
  const expected = Buffer.from(digest ?? "", "hex");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}
export function assertUserEnabled(store: Store, userId: string) {
  const row = store.db
    .prepare("SELECT disabled FROM console_user_state WHERE user_id=?")
    .get(userId) as { disabled: number } | undefined;
  check(!row?.disabled, "账号已禁用，请联系支持", 403);
}
export function authorize(
  store: Store,
  request: FastifyRequest,
  permission?: Permission,
): Admin {
  const header = request.headers.authorization;
  check(header?.startsWith("Bearer "), "请先登录管理后台", 401);
  const row = store.db
    .prepare(
      `SELECT a.id,a.username,a.role_id AS roleId,r.permissions_json AS permissionsJson
    FROM console_sessions s JOIN console_admins a ON a.id=s.admin_id JOIN console_roles r ON r.id=a.role_id
    WHERE s.token_hash=? AND s.expires_at>? AND a.enabled=1`,
    )
    .get(hashToken(header!.slice(7)), store.now()) as
    | Omit<AdminRow, "passwordHash">
    | undefined;
  check(row, "管理会话已过期", 401);
  const admin = {
    id: row.id,
    username: row.username,
    roleId: row.roleId,
    permissions: JSON.parse(row.permissionsJson) as Permission[],
  };
  check(
    !permission || admin.permissions.includes(permission),
    "没有执行此操作的权限",
    403,
  );
  return admin;
}
export function auditAction(
  store: Store,
  admin: Admin,
  action: string,
  target: string,
) {
  store.db
    .prepare(
      "INSERT INTO console_audit(admin_id,action,target,created_at) VALUES(?,?,?,?)",
    )
    .run(admin.id, action, target, store.now());
}
export async function bootstrapAdmin(store: Store) {
  for (const role of initialRoles)
    store.db
      .prepare("INSERT OR IGNORE INTO console_roles VALUES(?,?,?)")
      .run(role.id, role.name, JSON.stringify(role.permissions));
  // The protected super role follows the catalog; customized business roles remain untouched.
  store.db
    .prepare("UPDATE console_roles SET permissions_json=? WHERE id='super'")
    .run(JSON.stringify(initialRoles[0]!.permissions));
  if (store.db.prepare("SELECT 1 FROM console_admins LIMIT 1").get()) return;
  if (!process.env.ADMIN_BOOTSTRAP_PASSWORD) return;
  const input = credentials.parse({
    username: process.env.ADMIN_BOOTSTRAP_USERNAME ?? "admin",
    password: process.env.ADMIN_BOOTSTRAP_PASSWORD,
  });
  store.db
    .prepare(
      "INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)",
    )
    .run(
      randomUUID(),
      input.username,
      await encodePassword(input.password),
      "super",
      store.now(),
    );
}
export function registerAuth(app: FastifyInstance, store: Store) {
  app.post(
    "/auth/login",
    { config: { rateLimit: { max: 8, timeWindow: "1 minute" } } },
    async (request) => {
      const input = credentials.parse(request.body);
      const row = store.db
        .prepare(
          "SELECT id,username,password_hash AS passwordHash,role_id AS roleId FROM console_admins WHERE username=? AND enabled=1",
        )
        .get(input.username) as AdminRow | undefined;
      const valid = await matches(
        input.password,
        row?.passwordHash ?? "invalid:",
      );
      store.db
        .prepare(
          "INSERT INTO console_logins(username,success,created_at) VALUES(?,?,?)",
        )
        .run(input.username, Number(valid), store.now());
      check(row && valid, "用户名或密码错误", 401);
      const token = randomBytes(32).toString("base64url");
      const expiresAt = store.now() + 8 * 3600;
      store.db
        .prepare("DELETE FROM console_sessions WHERE expires_at<=?")
        .run(store.now());
      store.db
        .prepare("INSERT INTO console_sessions VALUES(?,?,?)")
        .run(hashToken(token), row.id, expiresAt);
      return { token, expiresAt };
    },
  );
  app.get("/auth/me", async (request) => {
    const admin = authorize(store, request);
    return {
      ...admin,
      menus: menus.filter((m) => admin.permissions.includes(m.permission)),
    };
  });
  app.post("/auth/logout", async (request) => {
    authorize(store, request);
    store.db
      .prepare("DELETE FROM console_sessions WHERE token_hash=?")
      .run(hashToken(request.headers.authorization!.slice(7)));
    return { ok: true };
  });
  app.get("/permissions", async (request) => {
    authorize(store, request, "system:role");
    return permissionCatalog;
  });
  app.get("/roles", async (request) => {
    authorize(store, request, "system:role");
    return store.db
      .prepare(
        "SELECT id,name,permissions_json AS permissionsJson FROM console_roles ORDER BY id",
      )
      .all()
      .map((row) => {
        const r = row as { id: string; name: string; permissionsJson: string };
        return {
          id: r.id,
          name: r.name,
          permissions: JSON.parse(r.permissionsJson) as Permission[],
        };
      });
  });
  app.put("/roles/:id", async (request) => {
    const admin = authorize(store, request, "system:role");
    const { id } = z.object({ id: z.string().max(50) }).parse(request.params);
    const input = z
      .strictObject({
        name: z.string().trim().min(1).max(50),
        permissions: z
          .array(
            z.enum(
              Object.keys(permissionCatalog) as [Permission, ...Permission[]],
            ),
          )
          .max(50),
      })
      .parse(request.body);
    check(id !== "super", "超级管理员基础权限不可修改", 400);
    check(
      store.db.prepare("SELECT 1 FROM console_roles WHERE id=?").get(id),
      "角色不存在",
      404,
    );
    store.db.transaction(() => {
      store.db
        .prepare(
          "UPDATE console_roles SET name=?,permissions_json=? WHERE id=?",
        )
        .run(input.name, JSON.stringify([...new Set(input.permissions)]), id);
      auditAction(store, admin, "role:update", id);
    })();
    return { ok: true };
  });
  app.get("/administrators", async (request) => {
    authorize(store, request, "system:admin");
    const input = pageQuery.parse(request.query);
    return paginate(
      store,
      input,
      "SELECT id,username,role_id AS roleId,enabled,created_at AS createdAt",
      "FROM console_admins WHERE username LIKE ?",
      [`%${input.q}%`],
    );
  });
  app.post("/administrators", async (request) => {
    const admin = authorize(store, request, "system:admin");
    const input = credentials
      .extend({ roleId: z.string().max(50) })
      .parse(request.body);
    check(
      store.db
        .prepare("SELECT 1 FROM console_roles WHERE id=?")
        .get(input.roleId),
      "角色不存在",
      400,
    );
    check(
      !store.db
        .prepare("SELECT 1 FROM console_admins WHERE username=?")
        .get(input.username),
      "管理员已存在",
      409,
    );
    const passwordHash = await encodePassword(input.password);
    const id = randomUUID();
    store.db.transaction(() => {
      store.db
        .prepare(
          "INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)",
        )
        .run(id, input.username, passwordHash, input.roleId, store.now());
      auditAction(store, admin, "admin:create", id);
    })();
    return { id };
  });
  app.patch("/administrators/:id", async (request) => {
    const admin = authorize(store, request, "system:admin");
    const { id } = z.object({ id: z.string().max(50) }).parse(request.params);
    const input = z
      .strictObject({ enabled: z.boolean(), roleId: z.string().max(50) })
      .parse(request.body);
    check(id !== admin.id, "不能修改当前管理员的角色或状态", 400);
    check(
      store.db
        .prepare("SELECT 1 FROM console_roles WHERE id=?")
        .get(input.roleId),
      "角色不存在",
      400,
    );
    const target = store.db
      .prepare("SELECT role_id FROM console_admins WHERE id=?")
      .get(id) as { role_id: string } | undefined;
    check(target, "管理员不存在", 404);
    check(
      target.role_id !== "super" ||
        (input.enabled && input.roleId === "super") ||
        (
          store.db
            .prepare(
              "SELECT COUNT(*) AS n FROM console_admins WHERE role_id='super' AND enabled=1 AND id<>?",
            )
            .get(id) as { n: number }
        ).n > 0,
      "必须保留至少一个超级管理员",
      400,
    );
    store.db.transaction(() => {
      store.db
        .prepare("UPDATE console_admins SET enabled=?,role_id=? WHERE id=?")
        .run(Number(input.enabled), input.roleId, id);
      store.db.prepare("DELETE FROM console_sessions WHERE admin_id=?").run(id);
      auditAction(store, admin, "admin:update", id);
    })();
    return { ok: true };
  });
}
