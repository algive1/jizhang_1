const target = (process.env.MONITOR_READY_URL ?? 'http://app:8787/ready').trim();
const intervalSeconds = Math.max(
  30,
  Number(process.env.MONITOR_INTERVAL_SECONDS ?? 60),
);
const threshold = Math.max(
  1,
  Number(process.env.MONITOR_FAILURE_THRESHOLD ?? 3),
);
const cooldownSeconds = Math.max(
  300,
  Number(process.env.MONITOR_ALERT_COOLDOWN_SECONDS ?? 1800),
);

let failures = 0;
let lastAlertAt = 0;

async function notify(level, message) {
  const url = (process.env.ALERT_WEBHOOK_URL ?? '').trim();
  if (!url) return;
  try {
    await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        source: 'haohao-monitor',
        level,
        message,
        target,
        occurredAt: new Date().toISOString(),
      }),
      signal: AbortSignal.timeout(10_000),
    });
  } catch (error) {
    console.error('monitor alert delivery failed', error);
  }
}

async function check() {
  try {
    const response = await fetch(target, {
      signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    if (failures >= threshold) {
      console.log('service recovered');
      await notify('info', '好好记账服务已恢复');
    }
    failures = 0;
  } catch (error) {
    failures += 1;
    console.error(`readiness failure ${failures}`, error);
    const now = Math.floor(Date.now() / 1000);
    if (
      failures >= threshold &&
      now - lastAlertAt >= cooldownSeconds
    ) {
      lastAlertAt = now;
      await notify(
        'error',
        `好好记账服务连续 ${failures} 次健康检查失败：${String(error)}`,
      );
    }
  }
}

while (true) {
  await check();
  await new Promise((resolve) =>
    setTimeout(resolve, intervalSeconds * 1000),
  );
}
