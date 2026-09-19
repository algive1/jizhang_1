import Database from 'better-sqlite3';
import { mkdirSync, readdirSync, statSync, unlinkSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';

const source = resolve(process.env.LEDGER_DB_PATH ?? 'data/shared-ledger.sqlite');
const directory = resolve(process.env.BACKUP_DIR ?? 'backups');
const keep = Math.max(1, Number(process.env.BACKUP_KEEP ?? 14));
mkdirSync(directory, { recursive: true });

const stamp = new Date().toISOString().replaceAll(':', '-').replaceAll('.', '-');
const target = join(directory, `${basename(source)}.${stamp}.sqlite`);
const escapedTarget = target.replaceAll("'", "''");

const database = new Database(source);
try {
  database.pragma('wal_checkpoint(PASSIVE)');
  database.exec(`VACUUM INTO '${escapedTarget}'`);
  const check = new Database(target, { readonly: true });
  try {
    const integrity = check.pragma('integrity_check', { simple: true });
    if (integrity !== 'ok') throw new Error(`backup integrity_check: ${integrity}`);
  } finally {
    check.close();
  }
} finally {
  database.close();
}

const backups = readdirSync(directory)
  .filter((name) => name.startsWith(basename(source) + '.') && name.endsWith('.sqlite'))
  .map((name) => ({ name, time: statSync(join(directory, name)).mtimeMs }))
  .sort((a, b) => b.time - a.time);

for (const stale of backups.slice(keep)) unlinkSync(join(directory, stale.name));
console.log(JSON.stringify({ backup: target, kept: Math.min(backups.length, keep) }));
