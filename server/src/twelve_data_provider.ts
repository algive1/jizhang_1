import { z } from 'zod';
import { MarketDataUnavailable } from './market_data_types.js';
import type { MarketAssetType, MarketQuote, MarketHistoryPoint, MarketSearchResult, ServerMarketDataProvider } from './market_data_types.js';

const numberString = z.union([z.string().trim().min(1), z.number()]).transform(Number).pipe(z.number().finite());
const quotePayload = z.object({
  symbol: z.string().min(1), name: z.string().min(1), currency: z.string().min(1),
  type: z.string().min(1), close: numberString.pipe(z.number().positive()),
  change: numberString, percent_change: numberString,
  timestamp: z.number().int().positive(), exchange: z.string().optional(),
});
const searchPayload = z.object({ data: z.array(z.object({
  symbol: z.string().min(1), instrument_name: z.string().min(1),
  instrument_type: z.string(), exchange: z.string().min(1),
})) });
const historyPayload = z.object({ values: z.array(z.object({
  datetime: z.string().regex(/^\d{4}-\d{2}-\d{2}$/), close: numberString.pipe(z.number().positive()),
})).max(4000) });

function assetType(value: string): MarketAssetType | undefined {
  switch (value.toLowerCase().replace(/[^a-z]/g, '')) {
    case 'commonstock': case 'preferredstock': case 'depositaryreceipt': return 'stock';
    case 'etf': return 'fund';
    case 'digitalcurrency': return 'crypto';
    default: return undefined;
  }
}

/** Server-only adapter. Uses official quote/search/daily history endpoints.
 * No demo symbols, fabricated quotes or credential-bearing errors are returned.
 * The default request budget is for one Basic account on one server process.
 */
export class TwelveDataMarketDataProvider implements ServerMarketDataProvider {
  readonly name = 'Twelve Data';
  private readonly cache = new Map<string, { expiresAt: number; value: unknown }>();
  private readonly flights = new Map<string, Promise<unknown>>();
  private minuteStarted = 0;
  private minuteUsed = 0;
  private day = '';
  private dayUsed = 0;

  constructor(
    private readonly apiKey = process.env.TWELVE_DATA_API_KEY,
    private readonly transport: typeof fetch = fetch,
    private readonly clock = Date.now,
  ) {}

  private async request(path: string, params: Record<string, string>, ttl: number): Promise<unknown> {
    if (!this.apiKey?.trim()) throw new MarketDataUnavailable('行情服务尚未配置');
    const query = new URLSearchParams(params);
    const cacheKey = `${path}?${query}`;
    const now = this.clock();
    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiresAt > now) return cached.value;
    const existing = this.flights.get(cacheKey);
    if (existing) return existing;
    const pending = this.fetchPayload(path, query, ttl, cacheKey);
    this.flights.set(cacheKey, pending);
    try { return await pending; } finally { this.flights.delete(cacheKey); }
  }

  private async fetchPayload(path: string, query: URLSearchParams, ttl: number, cacheKey: string): Promise<unknown> {
    const now = this.clock();
    if (now - this.minuteStarted >= 60_000) { this.minuteStarted = now; this.minuteUsed = 0; }
    const today = new Date(now).toISOString().slice(0, 10);
    if (today !== this.day) { this.day = today; this.dayUsed = 0; }
    if (this.minuteUsed >= 8 || this.dayUsed >= 800) throw new MarketDataUnavailable('行情请求额度已用完，请稍后重试');
    this.minuteUsed++; this.dayUsed++;
    query.set('apikey', this.apiKey!.trim());
    try {
      const response = await this.transport(`https://api.twelvedata.com${path}?${query}`, { signal: AbortSignal.timeout(12_000), headers: { Accept: 'application/json' } });
      if (!response.ok) throw new MarketDataUnavailable('行情数据源暂时不可用');
      const payload: unknown = await response.json();
      if (payload && typeof payload === 'object' && 'status' in payload && payload.status === 'error') throw new MarketDataUnavailable('该标的暂不可查询，请检查数据源权限或稍后重试');
      // Validate before caching: a malformed vendor response must be retryable.
      const schema = path === '/quote' ? quotePayload : path === '/symbol_search' ? searchPayload : historyPayload;
      if (!schema.safeParse(payload).success) throw new MarketDataUnavailable('行情数据格式异常');
      this.cache.delete(cacheKey);
      this.cache.set(cacheKey, { expiresAt: now + ttl, value: payload });
      if (this.cache.size > 256) this.cache.delete(this.cache.keys().next().value!);
      return payload;
    } catch (error) {
      if (error instanceof MarketDataUnavailable) throw error;
      throw new MarketDataUnavailable('行情数据源连接失败');
    }
  }

  private symbolParams(symbol: string, type: MarketAssetType): Record<string, string> {
    if (type === 'bond') throw new MarketDataUnavailable('当前数据源不支持债券行情，可使用手动估值');
    const [ticker, exchange, extra] = symbol.toUpperCase().split(':');
    if (!ticker || extra !== undefined || !/^[A-Z0-9./_-]+$/.test(ticker) || (exchange !== undefined && !/^[A-Z0-9 _.-]+$/.test(exchange))) throw new MarketDataUnavailable('行情标的代码无效');
    return { symbol: ticker, ...(exchange ? { exchange } : {}) };
  }

  private async quote(symbol: string, type: MarketAssetType): Promise<MarketQuote> {
    const params = this.symbolParams(symbol, type);
    const raw = quotePayload.parse(await this.request('/quote', params, 300_000));
    if (assetType(raw.type) !== type || raw.symbol.toUpperCase() !== params.symbol || (params.exchange && raw.exchange?.toUpperCase() !== params.exchange) || raw.timestamp * 1000 > this.clock() + 5 * 60_000) {
      this.cache.delete(`/quote?${new URLSearchParams(params)}`);
      throw new MarketDataUnavailable('行情标的或时间与请求不匹配');
    }
    return { symbol: symbol.toUpperCase(), name: raw.name, type, currency: raw.currency.toUpperCase(), price: raw.close, change: raw.change, changePercent: raw.percent_change, timestamp: new Date(raw.timestamp * 1000).toISOString() };
  }

  async search(query: string, type: MarketAssetType | undefined, limit: number): Promise<MarketSearchResult[]> {
    if (type === 'bond') return [];
    const raw = searchPayload.parse(await this.request('/symbol_search', { symbol: query }, 86_400_000));
    const results: MarketSearchResult[] = [];
    // Search results require actual prices in the app contract. Hydrate at most
    // three instruments to leave headroom within the free minute budget.
    const seen = new Set<string>();
    const candidates = raw.data.filter(item => {
      const mapped = assetType(item.instrument_type);
      const key = `${item.symbol}:${item.exchange}`.toUpperCase();
      if (!mapped || (type && mapped !== type) || seen.has(key)) return false;
      seen.add(key); return true;
    }).slice(0, Math.min(limit, 3));
    for (const item of candidates) {
      try {
        const mapped = assetType(item.instrument_type)!;
        const symbol = `${item.symbol}:${item.exchange}`.toUpperCase();
        if (symbol.length > 40) continue;
        const quote = await this.quote(symbol, mapped);
        results.push({ ...quote, market: item.exchange.toUpperCase() });
      } catch (error) { if (!(error instanceof MarketDataUnavailable)) throw error; }
    }
    if (candidates.length > 0 && results.length === 0) throw new MarketDataUnavailable('搜索到了标的，但当前数据源暂不能提供其行情');
    return results;
  }

  async quotes(requests: Array<{ symbol: string; type: MarketAssetType }>): Promise<MarketQuote[]> {
    const result: MarketQuote[] = [];
    const seen = new Set<string>();
    for (const item of requests) {
      const key = `${item.type}:${item.symbol.toUpperCase()}`;
      if (seen.has(key)) continue;
      seen.add(key);
      try { result.push(await this.quote(item.symbol, item.type)); }
      catch (error) { if (!(error instanceof MarketDataUnavailable)) throw error; }
    }
    if (result.length === 0 && requests.length > 0) throw new MarketDataUnavailable('行情暂不可用，请检查标的覆盖或稍后重试');
    return result;
  }

  async history(symbol: string, type: MarketAssetType, days: number): Promise<MarketHistoryPoint[]> {
    const params = this.symbolParams(symbol, type);
    const raw = historyPayload.parse(await this.request('/time_series', { ...params, interval: '1day', outputsize: String(Math.min(days, 3650)), order: 'asc', adjust: 'none' }, 21_600_000));
    // Daily vendor bars use exchange calendar dates; represent the date at UTC
    // midnight, rather than pretending it is an intraday timestamp.
    const start = this.clock() - days * 86_400_000;
    return raw.values.map(point => ({ date: `${point.datetime}T00:00:00.000Z`, value: point.close }))
      .filter(point => Date.parse(point.date) >= start && Date.parse(point.date) <= this.clock());
  }
}
