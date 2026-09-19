import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';
import type {
  MarketAssetType,
  MarketHistoryPoint,
  MarketQuote,
  MarketSearchResult,
  ServerMarketDataProvider,
} from '../src/market_data.js';

class FakeMarketProvider implements ServerMarketDataProvider {
  readonly name = 'test-market';
  quoteCalls = 0;

  async search(query: string, type: MarketAssetType | undefined): Promise<MarketSearchResult[]> {
    return [{
      symbol: query.toUpperCase(),
      name: '测试标的',
      type: type ?? 'stock',
      price: 10,
      change: 0.2,
      changePercent: 2,
      currency: 'CNY',
      timestamp: '2026-09-19T08:00:00+08:00',
      market: type === 'crypto' ? 'GLOBAL' : 'CN',
    }];
  }

  async quotes(requests: Array<{ symbol: string; type: MarketAssetType }>): Promise<MarketQuote[]> {
    this.quoteCalls += 1;
    return requests.map(item => ({
      symbol: item.symbol.toUpperCase(),
      name: item.symbol,
      type: item.type,
      price: item.symbol.toUpperCase() === 'BTC' ? 68000 : 1680,
      change: 12,
      changePercent: 0.72,
      currency: item.type === 'crypto' ? 'USD' : 'CNY',
      timestamp: '2026-09-19T08:00:00+08:00',
    }));
  }

  async history(_symbol: string, _type: MarketAssetType, days: number): Promise<MarketHistoryPoint[]> {
    return Array.from({ length: Math.min(days, 3) }, (_, index) => ({
      date: new Date(Date.UTC(2026, 8, 17 + index)).toISOString(),
      value: 100 + index,
    }));
  }
}

test('market routes normalize vendor data and share quote cache', async t => {
  const provider = new FakeMarketProvider();
  const { app } = await createApp(':memory:', undefined, provider);
  const base = await app.listen({ host: '127.0.0.1', port: 0 });
  t.after(() => app.close());

  const search = await fetch(`${base}/api/v1/market/search?q=600519&type=stock`);
  assert.equal(search.status, 200);
  const searchBody = await search.json() as { source: string; results: MarketSearchResult[] };
  assert.equal(searchBody.source, 'test-market');
  assert.equal(searchBody.results[0]?.symbol, '600519');

  const body = JSON.stringify({
    requests: [
      { symbol: '600519', type: 'stock' },
      { symbol: 'BTC', type: 'crypto' },
    ],
  });
  const first = await fetch(`${base}/api/v1/market/quotes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body,
  });
  assert.equal(first.status, 200);
  const firstBody = await first.json() as { quotes: MarketQuote[] };
  assert.equal(firstBody.quotes.length, 2);
  assert.equal(provider.quoteCalls, 1);

  const second = await fetch(`${base}/api/v1/market/quotes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body,
  });
  assert.equal(second.status, 200);
  assert.equal(provider.quoteCalls, 1, 'second request should be served from shared cache');

  const history = await fetch(`${base}/api/v1/market/history?symbol=600519&type=stock&days=30`);
  assert.equal(history.status, 200);
  const historyBody = await history.json() as { points: MarketHistoryPoint[] };
  assert.equal(historyBody.points.length, 3);
});
