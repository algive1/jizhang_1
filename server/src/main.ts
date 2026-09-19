import { mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';

import { createApp } from './app.js';
import { runRetention } from './maintenance.js';

const file = resolve(process.env.LEDGER_DB_PATH ?? 'data/shared-ledger.sqlite');
mkdirSync(dirname(file), { recursive: true });

const { app, store } = await createApp(file);
const production = process.env.NODE_ENV === 'production';
const host = (process.env.HOST ?? (production ? '0.0.0.0' : '127.0.0.1')).trim();
const port = Number(process.env.PORT ?? 8787);

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('PORT must be an integer between 1 and 65535');
}

const address = await app.listen({ host, port });
console.log(`HaoHao Jizhang server listening at ${address}`);

const maintenance = () => {
  try {
    const result = runRetention(store);
    console.log('retention maintenance completed', result.deleted);
  } catch (error) {
    console.error('retention maintenance failed', error);
  }
};
maintenance();
const maintenanceTimer = setInterval(maintenance, 24 * 60 * 60 * 1000);
maintenanceTimer.unref();

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    clearInterval(maintenanceTimer);
    void app.close();
  });
}
