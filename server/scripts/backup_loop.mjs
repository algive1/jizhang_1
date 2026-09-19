import { spawn } from 'node:child_process';

const intervalSeconds = Math.max(
  300,
  Number(process.env.BACKUP_INTERVAL_SECONDS ?? 86400),
);

async function alert(message) {
  const url = (process.env.ALERT_WEBHOOK_URL ?? '').trim();
  if (!url) return;
  try {
    await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        source: 'haohao-backup',
        level: 'error',
        message,
        occurredAt: new Date().toISOString(),
      }),
      signal: AbortSignal.timeout(10_000),
    });
  } catch (error) {
    console.error('backup alert delivery failed', error);
  }
}

async function runBackup() {
  const child = spawn(process.execPath, ['scripts/backup.mjs'], {
    stdio: 'inherit',
    env: process.env,
  });
  const code = await new Promise((resolve) => child.once('exit', resolve));
  if (code !== 0) {
    const message = `database backup failed with exit code ${code}`;
    console.error(message);
    await alert(message);
  }
}

while (true) {
  await runBackup();
  await new Promise((resolve) =>
    setTimeout(resolve, intervalSeconds * 1000),
  );
}
