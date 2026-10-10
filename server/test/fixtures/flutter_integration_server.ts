import { randomUUID } from 'node:crypto';
import { createApp } from '../../src/app.js';
import { encodePassword } from '../../src/console/auth.js';
import type { ServerMarketDataProvider } from '../../src/market_data_types.js';

// Isolated contract fixture, never a production market source. Flutter uses the
// actual HTTP routes and SQLite; only the external quote vendor is substituted.
if (process.env.NODE_ENV !== 'test') throw new Error('Integration fixture requires NODE_ENV=test');
const quote = (symbol: string, type: 'stock'|'fund'|'bond'|'crypto') => ({
  symbol, type, name: '联调测试标的', price: type === 'fund' ? 1.25 : 10,
  change: .01, changePercent: .1, currency: 'CNY', timestamp: new Date().toISOString(),
});
const market: ServerMarketDataProvider = {
  name: 'integration-fixture',
  async search(_query, type) { return [{...quote(type === 'fund' ? '000001' : '600000', type ?? 'stock'), market:'CN'}]; },
  async quotes(requests) { return requests.map(r => quote(r.symbol,r.type)); },
  async history() { return [{date:new Date().toISOString(),value:10}]; },
};
const { app, store } = await createApp(process.env.LEDGER_DB_PATH ?? ':memory:', undefined, market);
store.db.prepare('INSERT INTO console_admins(id,username,password_hash,role_id,created_at) VALUES(?,?,?,?,?)')
  .run(randomUUID(),'flutter_test_admin',await encodePassword('isolated-console-password'),'super',store.now());
const address = await app.listen({host:'127.0.0.1',port:0});
console.log(`Shared ledger listening at ${address}`);
for (const signal of ['SIGINT','SIGTERM']) process.on(signal,()=>{void app.close();});
