import { mkdirSync, existsSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { randomBytes } from "node:crypto";
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const folder = resolve(root, ".local");
const file = resolve(folder, "preview.env");
mkdirSync(folder, { recursive: true });
if (!existsSync(file)) {
  const database = resolve(folder, "preview.sqlite").replaceAll("\\", "/");
  writeFileSync(file, [
    "ADMIN_BOOTSTRAP_USERNAME=admin",
    `ADMIN_BOOTSTRAP_PASSWORD=${randomBytes(32).toString("base64url")}`,
    `LEDGER_DB_PATH=${JSON.stringify(database)}`,
    "HOST=127.0.0.1", "PORT=8792", "PUSH_WORKER_ENABLED=false", "",
  ].join("\n"), { flag: "wx", mode: 0o600 });
}
console.log(`Preview configuration: ${file}`);
console.log("Web: http://127.0.0.1:5180 | API: http://127.0.0.1:8792");
