import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import type { Store } from "./store.js";
import { requireCondition as check } from "./contract.js";

export const integrationFields = {
  wechat: {
    public: [
      "WECHAT_APP_ID",
      "WECHAT_MCH_ID",
      "WECHAT_SERIAL_NO",
      "WECHAT_PLATFORM_SERIAL_NO",
      "WECHAT_NOTIFY_URL",
      "WECHAT_REFUND_NOTIFY_URL",
      "WECHAT_UNIVERSAL_LINK",
    ],
    secret: [
      "WECHAT_PRIVATE_KEY",
      "WECHAT_PLATFORM_PUBLIC_KEY",
      "WECHAT_API_V3_KEY",
    ],
  },
  alipay: {
    public: ["ALIPAY_APP_ID", "ALIPAY_SELLER_ID", "ALIPAY_NOTIFY_URL"],
    secret: ["ALIPAY_PRIVATE_KEY", "ALIPAY_PUBLIC_KEY"],
  },
  asr: {
    public: [
      "TENCENT_ASR_SECRET_ID",
      "TENCENT_ASR_ENGINE",
      "TENCENT_ASR_HOTWORD_ID",
    ],
    secret: ["TENCENT_ASR_SECRET_KEY"],
  },
} as const;
export type IntegrationName = keyof typeof integrationFields;
export function ensureIntegrations(store: Store) {
  store.db.exec(
    "CREATE TABLE IF NOT EXISTS integration_settings(name TEXT PRIMARY KEY,value TEXT NOT NULL,encrypted INTEGER NOT NULL,updated_at INTEGER NOT NULL)",
  );
}
function encryptionKey() {
  const raw = process.env.INTEGRATION_ENCRYPTION_KEY ?? "";
  check(
    /^[a-fA-F0-9]{64}$/.test(raw),
    "服务端需配置 64 位十六进制 INTEGRATION_ENCRYPTION_KEY 才能保存密钥",
    503,
  );
  return Buffer.from(raw, "hex");
}
export function saveIntegrationSecret(
  store: Store,
  name: string,
  value: string,
) {
  const iv = randomBytes(12),
    cipher = createCipheriv("aes-256-gcm", encryptionKey(), iv);
  const data = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  store.db
    .prepare(
      "INSERT INTO integration_settings VALUES(?,?,1,?) ON CONFLICT(name) DO UPDATE SET value=excluded.value,encrypted=1,updated_at=excluded.updated_at",
    )
    .run(
      name,
      [iv, cipher.getAuthTag(), data]
        .map((v) => v.toString("base64"))
        .join("."),
      store.now(),
    );
}
export function integrationValue(store: Store, name: string): string | null {
  const row = store.db
    .prepare("SELECT value,encrypted FROM integration_settings WHERE name=?")
    .get(name) as { value: string; encrypted: number } | undefined;
  if (!row) {
    const value = process.env[name]?.trim();
    if (value) return value;
    const path = process.env[`${name}_PATH`];
    return path &&
      [
        "WECHAT_PRIVATE_KEY",
        "WECHAT_PLATFORM_PUBLIC_KEY",
        "ALIPAY_PRIVATE_KEY",
        "ALIPAY_PUBLIC_KEY",
      ].includes(name)
      ? readFileSync(path, "utf8").trim()
      : null;
  }
  if (!row.encrypted) return row.value;
  const [iv, tag, data] = row.value.split(".");
  const decipher = createDecipheriv(
    "aes-256-gcm",
    encryptionKey(),
    Buffer.from(iv!, "base64"),
  );
  decipher.setAuthTag(Buffer.from(tag!, "base64"));
  return Buffer.concat([
    decipher.update(Buffer.from(data!, "base64")),
    decipher.final(),
  ]).toString("utf8");
}
export function integrationStatus(store: Store, provider: IntegrationName) {
  const fields = integrationFields[provider];
  const items = [...fields.public, ...fields.secret].map((name) => {
    let value: string | null = null,
      readable = true;
    try {
      value = integrationValue(store, name);
    } catch {
      readable = false;
    }
    const secret = (fields.secret as readonly string[]).includes(name);
    return {
      name,
      secret,
      value: secret ? "" : (value ?? ""),
      configured: Boolean(value),
      readable,
      source: store.db
        .prepare("SELECT 1 FROM integration_settings WHERE name=?")
        .get(name)
        ? "console"
        : "environment",
    };
  });
  return {
    provider,
    items,
    canSaveSecrets: /^[a-fA-F0-9]{64}$/.test(
      process.env.INTEGRATION_ENCRYPTION_KEY ?? "",
    ),
  };
}
export function saveIntegration(
  store: Store,
  provider: IntegrationName,
  values: Record<string, string>,
) {
  const fields = integrationFields[provider],
    allowed = [...fields.public, ...fields.secret] as readonly string[];
  for (const [name, value] of Object.entries(values)) {
    check(allowed.includes(name), "不支持的接入参数", 400);
    if ((name.endsWith("_URL") || name.endsWith("_LINK")) && value) {
      let valid = false;
      try {
        const url = new URL(value);
        valid = url.protocol === "https:" && !url.username && !url.password;
      } catch {
        /* Invalid URL. */
      }
      check(valid, "地址必须使用 HTTPS", 400);
    }
    if (name === "WECHAT_API_V3_KEY")
      check(
        !value || Buffer.byteLength(value) === 32,
        "微信 APIv3 密钥必须为 32 字节",
        400,
      );
    const secret = (fields.secret as readonly string[]).includes(name);
    if (secret && !value) continue;
    let encoded = value;
    if (secret) {
      const iv = randomBytes(12),
        cipher = createCipheriv("aes-256-gcm", encryptionKey(), iv);
      const data = Buffer.concat([
        cipher.update(value.replaceAll("\\n", "\n"), "utf8"),
        cipher.final(),
      ]);
      encoded = [iv, cipher.getAuthTag(), data]
        .map((v) => v.toString("base64"))
        .join(".");
    }
    store.db
      .prepare(
        "INSERT INTO integration_settings VALUES(?,?,?,?) ON CONFLICT(name) DO UPDATE SET value=excluded.value,encrypted=excluded.encrypted,updated_at=excluded.updated_at",
      )
      .run(name, encoded, Number(secret), store.now());
  }
}
