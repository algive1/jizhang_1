import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import { requireCondition as check } from "../contract.js";
import { authorize, auditAction } from "./auth.js";
import type { Permission } from "./permissions.js";
import { pageQuery, paginate } from "./query.js";
import { semver, inRollout, compareVersions } from "./releases.js";

export const documentKind = z.enum(["config", "rule", "prompt"]);
const key = z.string().regex(/^[a-zA-Z0-9._-]{1,100}$/);
const configSchema = z.strictObject({
  aiEnabled: z.boolean().optional(),
  ocrEnabled: z.boolean().optional(),
  voiceEnabled: z.boolean().optional(),
  autoAccountingEnabled: z.boolean().optional(),
  cloudBackupEnabled: z.boolean().optional(),
  ruleVersion: z.number().int().nonnegative().optional(),
  logUploadPercent: z.number().int().min(0).max(100).optional(),
  experiments: z.record(key, z.boolean()).optional(),
});
const ruleSchema = z
  .strictObject({
    packageName: z.string().regex(/^[a-zA-Z]\w*(?:\.\w+)+$/),
    pageIdentifier: z.string().min(1).max(160),
    activity: z.string().max(200),
    nodeFeatures: z.array(z.string().max(160)).max(20),
    textFeatures: z.array(z.string().max(80)).max(20),
    notificationTitlePattern: z.string().max(300),
    notificationBodyPattern: z.string().max(300),
    amountPattern: z.string().min(1).max(300),
    merchantPattern: z.string().max(300),
    priority: z.number().int().min(0).max(1000),
    minAppVersion: semver,
    maxAppVersion: semver.nullable(),
    enabled: z.boolean(),
  })
  .refine(
    (v) =>
      v.maxAppVersion == null ||
      compareVersions(v.minAppVersion, v.maxAppVersion) <= 0,
    "版本范围无效",
  );
const promptSchema = z.strictObject({
  name: z.string().min(1).max(80),
  scene: z.enum([
    "classification",
    "merchant",
    "voice",
    "ocr",
    "natural-language",
    "assistant",
    "insight",
  ]),
  systemPrompt: z.string().min(1).max(12000),
  userTemplate: z.string().min(1).max(12000),
  experiment: z.string().max(100).nullable(),
});
const schemas = {
  config: configSchema,
  rule: ruleSchema,
  prompt: promptSchema,
};
const permission = (
  kind: z.infer<typeof documentKind>,
  action: "view" | "edit" | "publish",
): Permission =>
  `${kind === "config" ? "app:config" : kind === "rule" ? "auto-accounting:rule" : "ai:prompt"}:${action}` as Permission;
type Publication = {
  version: number;
  rollout: number;
  fallback_version: number | null;
};
export function getPublishedDocuments(
  store: Store,
  kind: string,
  installationId?: string,
) {
  const rows = store.db
    .prepare(
      "SELECT key,version,rollout,fallback_version FROM console_publications WHERE kind=? ORDER BY key LIMIT 200",
    )
    .all(kind) as Array<Publication & { key: string }>;
  return rows.flatMap((row) => {
    const version = inRollout(`${kind}:${row.key}`, installationId, row.rollout)
      ? row.version
      : row.fallback_version;
    if (version == null) return [];
    const doc = store.db
      .prepare(
        "SELECT payload_json FROM console_documents WHERE kind=? AND key=? AND version=?",
      )
      .get(kind, row.key, version) as { payload_json: string } | undefined;
    return doc
      ? [
          {
            key: row.key,
            version,
            payload: JSON.parse(doc.payload_json) as unknown,
          },
        ]
      : [];
  });
}
export function registerDocuments(app: FastifyInstance, store: Store) {
  app.get("/documents/:kind", async (request) => {
    const { kind } = z.object({ kind: documentKind }).parse(request.params);
    authorize(store, request, permission(kind, "view"));
    const input = pageQuery.parse(request.query);
    return paginate(
      store,
      input,
      "SELECT d.key,d.version,d.payload_json AS payloadJson,d.note,d.created_at AS createdAt,d.created_by AS createdBy,p.version AS publishedVersion,p.rollout",
      `FROM console_documents d LEFT JOIN console_publications p ON p.kind=d.kind AND p.key=d.key WHERE d.kind=? AND d.version=(SELECT MAX(version) FROM console_documents WHERE kind=d.kind AND key=d.key) AND d.key LIKE ?`,
      [kind, `%${input.q}%`],
      "d.created_at DESC",
    );
  });
  app.get("/documents/:kind/:key/history", async (request) => {
    const input = z.object({ kind: documentKind, key }).parse(request.params);
    authorize(store, request, permission(input.kind, "view"));
    return paginate(
      store,
      pageQuery.parse(request.query),
      "SELECT version,payload_json AS payloadJson,note,created_by AS createdBy,created_at AS createdAt",
      "FROM console_documents WHERE kind=? AND key=?",
      [input.kind, input.key],
      "version DESC",
    );
  });
  app.post("/documents/:kind", async (request) => {
    const { kind } = z.object({ kind: documentKind }).parse(request.params);
    const admin = authorize(store, request, permission(kind, "edit"));
    const input = z
      .strictObject({
        key,
        payload: z.unknown(),
        note: z.string().trim().min(1).max(300),
        baseVersion: z.number().int().nonnegative(),
      })
      .parse(request.body);
    const payload = schemas[kind].parse(input.payload);
    return store.db.transaction(() => {
      const latest =
        (
          store.db
            .prepare(
              "SELECT MAX(version) AS version FROM console_documents WHERE kind=? AND key=?",
            )
            .get(kind, input.key) as { version: number | null }
        ).version ?? 0;
      check(
        latest === input.baseVersion,
        "版本已被其他管理员修改，请刷新后重试",
        409,
      );
      const version = latest + 1;
      store.db
        .prepare("INSERT INTO console_documents VALUES(?,?,?,?,?,?,?)")
        .run(
          kind,
          input.key,
          version,
          JSON.stringify(payload),
          input.note,
          admin.id,
          store.now(),
        );
      auditAction(store, admin, `${kind}:revision:${version}`, input.key);
      return { key: input.key, version };
    })();
  });
  app.post("/documents/:kind/:key/publish", async (request) => {
    const input = z.object({ kind: documentKind, key }).parse(request.params);
    const admin = authorize(store, request, permission(input.kind, "publish"));
    const body = z
      .strictObject({
        version: z.number().int().positive(),
        rollout: z.number().int().min(0).max(100),
      })
      .parse(request.body);
    check(
      store.db
        .prepare(
          "SELECT 1 FROM console_documents WHERE kind=? AND key=? AND version=?",
        )
        .get(input.kind, input.key, body.version),
      "修订版本不存在",
      404,
    );
    store.db.transaction(() => {
      const old = store.db
        .prepare(
          "SELECT version,rollout,fallback_version FROM console_publications WHERE kind=? AND key=?",
        )
        .get(input.kind, input.key) as Publication | undefined;
      const fallback =
        body.rollout === 100
          ? null
          : old?.rollout === 100
            ? old.version
            : (old?.fallback_version ?? null);
      store.db
        .prepare(
          "INSERT INTO console_publications(kind,key,version,rollout,updated_by,updated_at,fallback_version) VALUES(?,?,?,?,?,?,?) ON CONFLICT(kind,key) DO UPDATE SET version=excluded.version,rollout=excluded.rollout,updated_by=excluded.updated_by,updated_at=excluded.updated_at,fallback_version=excluded.fallback_version",
        )
        .run(
          input.kind,
          input.key,
          body.version,
          body.rollout,
          admin.id,
          store.now(),
          fallback,
        );
      auditAction(
        store,
        admin,
        `${input.kind}:publish:${body.version}:${body.rollout}`,
        input.key,
      );
    })();
    return { ok: true };
  });
  app.delete("/documents/:kind/:key/publication", async (request) => {
    const input = z.object({ kind: documentKind, key }).parse(request.params);
    const admin = authorize(store, request, permission(input.kind, "publish"));
    store.db.transaction(() => {
      store.db
        .prepare("DELETE FROM console_publications WHERE kind=? AND key=?")
        .run(input.kind, input.key);
      auditAction(store, admin, `${input.kind}:offline`, input.key);
    })();
    return { ok: true };
  });
}
