import test from 'node:test';
import assert from 'node:assert/strict';
import { TwelveDataMarketDataProvider } from '../src/twelve_data_provider.js';
import { MarketDataUnavailable } from '../src/market_data_types.js';

const now = Date.UTC(2026, 9, 9, 16);
const fixture = (symbol = 'AAPL', extra: Record<string, unknown> = {}) => ({
  symbol, name: 'Apple Inc.', exchange: 'NASDAQ', currency: 'USD', type: 'Common Stock',
  close: '250.25', change: '2.25', percent_change: '0.907258', timestamp: now / 1000, ...extra,
});
function transport(handler: (url: URL) => unknown): typeof fetch {
  return async input => new Response(JSON.stringify(handler(new URL(String(input)))), { status: 200 });
}

test('quote identity, currency and vendor time are preserved; concurrent reads share a request', async () => {
  let calls = 0;
  const provider = new TwelveDataMarketDataProvider('test-secret', transport(url => {
    calls++;
    assert.equal(url.origin, 'https://api.twelvedata.com');
    assert.equal(url.searchParams.get('exchange'), 'NASDAQ');
    return fixture();
  }), () => now);
  const [a, b] = await Promise.all([provider.quotes([{ symbol: 'AAPL:NASDAQ', type: 'stock' }]), provider.quotes([{ symbol: 'AAPL:NASDAQ', type: 'stock' }])]);
  assert.deepEqual(a, b);
  assert.equal(calls, 1);
  assert.equal(a[0]?.symbol, 'AAPL:NASDAQ');
  assert.equal(a[0]?.currency, 'USD');
  assert.equal(a[0]?.price, 250.25);
  assert.equal(a[0]?.timestamp, new Date(now).toISOString());
  await provider.quotes([{ symbol: 'AAPL:NASDAQ', type: 'stock' }]);
  assert.equal(calls, 1);
});

test('search hydrates only supported instruments and preserves exchange identity', async () => {
  let calls = 0;
  const provider = new TwelveDataMarketDataProvider('key', transport(url => {
    calls++;
    if (url.pathname === '/symbol_search') return { data: [
      { symbol: 'AAPL', exchange: 'NASDAQ', instrument_name: 'Apple', instrument_type: 'Common Stock' },
      { symbol: 'EUR/USD', exchange: 'FOREX', instrument_name: 'Euro', instrument_type: 'Physical Currency' },
      { symbol: 'AAPL', exchange: 'NASDAQ', instrument_name: 'Apple', instrument_type: 'Common Stock' },
    ] };
    return fixture();
  }), () => now);
  const results = await provider.search('Apple', undefined, 20);
  assert.equal(results.length, 1);
  assert.equal(results[0]?.market, 'NASDAQ');
  assert.equal(results[0]?.currency, 'USD');
  assert.equal(calls, 2);
  assert.deepEqual(await provider.search('bond', 'bond', 20), []);
});

test('bad quotes are never exposed or cached and failures do not leak credentials', async () => {
  for (const extra of [{ close: 'NaN' }, { currency: '' }, { timestamp: now / 1000 + 3600 }, { symbol: 'OTHER' }, { exchange: 'NYSE' }, { type: 'ETF' }]) {
    let calls = 0;
    const provider = new TwelveDataMarketDataProvider('private-key', transport(() => { calls++; return calls === 1 ? fixture('AAPL', extra) : fixture(); }), () => now);
    await assert.rejects(provider.quotes([{ symbol: 'AAPL:NASDAQ', type: 'stock' }]), error => error instanceof MarketDataUnavailable && !error.message.includes('private-key'));
    const values = await provider.quotes([{ symbol: 'AAPL:NASDAQ', type: 'stock' }]);
    assert.equal(values.length, 1);
    assert.equal(calls, 2);
  }
  const unconfigured = new TwelveDataMarketDataProvider('', transport(() => { throw new Error('must not fetch'); }));
  await assert.rejects(unconfigured.quotes([{ symbol: 'AAPL', type: 'stock' }]), MarketDataUnavailable);
});

test('partial portfolios keep valid quotes when another symbol is unavailable', async () => {
  const provider = new TwelveDataMarketDataProvider('key', transport(url => url.searchParams.get('symbol') === 'AAPL' ? fixture() : { status: 'error', message: 'private-key' }), () => now);
  const values = await provider.quotes([{ symbol: 'AAPL', type: 'stock' }, { symbol: '600519', type: 'stock' }, { symbol: 'BOND', type: 'bond' }]);
  assert.equal(values.length, 1);
  assert.equal(values[0]?.symbol, 'AAPL');
});

test('cold requests obey the free minute budget and the window resets', async () => {
  let time = now, calls = 0;
  const provider = new TwelveDataMarketDataProvider('key', transport(url => { calls++; return fixture(url.searchParams.get('symbol')!); }), () => time);
  const requests = Array.from({ length: 10 }, (_, i) => ({ symbol: `S${i}`, type: 'stock' as const }));
  assert.equal((await provider.quotes(requests)).length, 8);
  assert.equal(calls, 8);
  await assert.rejects(provider.quotes([{ symbol: 'NEW', type: 'stock' }]), MarketDataUnavailable);
  assert.equal(calls, 8);
  time += 60_001;
  assert.equal((await provider.quotes([{ symbol: 'NEW', type: 'stock' }])).length, 1);
});

test('daily history removes future and out of range bars without fabricating samples', async () => {
  const provider = new TwelveDataMarketDataProvider('key', transport(url => {
    assert.equal(url.pathname, '/time_series');
    assert.equal(url.searchParams.get('adjust'), 'none');
    assert.equal(url.searchParams.get('exchange'), 'NASDAQ');
    return { values: [{ datetime: '2026-01-01', close: '1' }, { datetime: '2026-10-08', close: '249' }, { datetime: '2026-10-09', close: '250' }, { datetime: '2026-10-10', close: '300' }] };
  }), () => now);
  const points = await provider.history('AAPL:NASDAQ', 'stock', 30);
  assert.deepEqual(points.map(p => p.value), [249, 250]);
});
