import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

const assetType = z.enum(['stock', 'fund', 'bond', 'crypto']);
const quoteRequest = z.strictObject({
  symbol: z.string().trim().min(1).max(40),
  type: assetType,
});
const quoteSchema = z.strictObject({
  symbol: z.string().trim().min(1).max(40),
  name: z.string().trim().min(1).max(120),
  type: assetType,
  price: z.number().finite().positive(),
  change: z.number().finite(),
  changePercent: z.number().finite(),
  currency: z.string().trim().min(1).max(12).default('CNY'),
  timestamp: z.string().datetime({ offset: true }),
});
const searchResultSchema = quoteSchema.extend({
  market: z.string().trim().min(1).max(32).optional(),
});
const historyPointSchema = z.strictObject({
  date: z.string().datetime({ offset: true }),
  value: z.number().finite().positive(),
});
const quotesBody = z.strictObject({
  requests: z.array(quoteRequest).min(1).max(100),
});
const searchQuery = z.strictObject({
  q: z.string().trim().min(1).max(80),
  type: assetType.optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
const historyQuery = z.strictObject({
  symbol: z.string().trim().min(1).max(40),
  type: assetType,
  days: z.coerce.number().int().min(1).max(3650),
});

export type MarketAssetType = z.infer<typeof assetType>;
export type MarketQuote = z.infer<typeof quoteSchema>;
export type MarketSearchResult = z.infer<typeof searchResultSchema>;
export type MarketHistoryPoint = z.infer<typeof historyPointSchema>;

export interface ServerMarketDataProvider {
  readonly name: string;
  search(query: string, type: MarketAssetType | undefined, limit: number): Promise<MarketSearchResult[]>;
  quotes(requests: Array<{ symbol: string; type: MarketAssetType }>): Promise<MarketQuote[]>;
  history(symbol: string, type: MarketAssetType, days: number): Promise<MarketHistoryPoint[]>;
}

export class MarketDataUnavailable extends Error {}

function cleanBaseUrl(value: string | undefined): string {
  const raw = value?.trim() ?? '';
  if (!raw) throw new MarketDataUnavailable('MARKET_DATA_BASE_URL is not configured');
  const url = new URL(raw);
  if (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['127.0.0.1', 'localhost'].includes(url.hostname))) {
    throw new MarketDataUnavailable('MARKET_DATA_BASE_URL must use HTTPS');
  }
  return url.toString().replace(/\/$/, '');
}

/**
 * Production market adapter.
 *
 * The upstream is deliberately normalized at this boundary. Vendor credentials
 * stay on the server and the Flutter client never depends on a vendor payload.
 * Expected upstream endpoints:
 *   GET  /search?q=...&type=...&limit=...
 *   POST /quotes { requests: [{symbol,type}] }
 *   GET  /history?symbol=...&type=...&days=...
 */
export class NormalizedHttpMarketDataProvider implements ServerMarketDataProvider {
  readonly name = 'real-market';
  constructor(
    private readonly configuredBaseUrl = process.env.MARKET_DATA_BASE_URL,
    private readonly apiKey = process.env.MARKET_DATA_API_KEY,
  ) {}

  private async request(path: string, init: RequestInit = {}): Promise<unknown> {
    const baseUrl = cleanBaseUrl(this.configuredBaseUrl);
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12_000);
    try {
      const response = await fetch(`${baseUrl}${path}`, {
        ...init,
        signal: controller.signal,
        headers: {
          Accept: 'application/json',
          ...(init.body ? { 'Content-Type': 'application/json' } : {}),
          ...(this.apiKey ? { Authorization: `Bearer ${this.apiKey}` } : {}),
          ...(init.headers ?? {}),
        },
      });
      if (!response.ok) throw new MarketDataUnavailable(`market provider returned HTTP ${response.status}`);
      return await response.json();
    } catch (error) {
      if (error instanceof MarketDataUnavailable) throw error;
      throw new MarketDataUnavailable('market provider request failed');
    } finally {
      clearTimeout(timeout);
    }
  }

  async search(query: string, type: MarketAssetType | undefined, limit: number): Promise<MarketSearchResult[]> {
    const params = new URLSearchParams({ q: query, limit: String(limit) });
    if (type) params.set('type', type);
    const payload = await this.request(`/search?${params.toString()}`);
    const parsed = z.strictObject({ results: z.array(searchResultSchema).max(50) }).safeParse(payload);
    if (!parsed.success) throw new MarketDataUnavailable('market search response schema mismatch');
    return parsed.data.results;
  }

  async quotes(requests: Array<{ symbol: string; type: MarketAssetType }>): Promise<MarketQuote[]> {
    const payload = await this.request('/quotes', {
      method: 'POST',
      body: JSON.stringify({ requests }),
    });
    const parsed = z.strictObject({ quotes: z.array(quoteSchema).max(100) }).safeParse(payload);
    if (!parsed.success) throw new MarketDataUnavailable('market quote response schema mismatch');
    return parsed.data.quotes;
  }

  async history(symbol: string, type: MarketAssetType, days: number): Promise<MarketHistoryPoint[]> {
    const params = new URLSearchParams({ symbol, type, days: String(days) });
    const payload = await this.request(`/history?${params.toString()}`);
    const parsed = z.strictObject({ points: z.array(historyPointSchema).max(4000) }).safeParse(payload);
    if (!parsed.success) throw new MarketDataUnavailable('market history response schema mismatch');
    return parsed.data.points;
  }
}

interface ServerQuoteCache {
  getMany(keys: string[]): Promise<Map<string, MarketQuote>>;
  set(key: string, quote: MarketQuote, ttlSeconds: number): Promise<void>;
}

type MemoryEntry = { quote: MarketQuote; expiresAt: number };

class MemoryServerQuoteCache implements ServerQuoteCache {
  private readonly values = new Map<string, MemoryEntry>();

  async getMany(keys: string[]): Promise<Map<string, MarketQuote>> {
    const now = Date.now();
    const result = new Map<string, MarketQuote>();
    for (const key of keys) {
      const entry = this.values.get(key);
      if (!entry) continue;
      if (entry.expiresAt <= now) {
        this.values.delete(key);
        continue;
      }
      result.set(key, entry.quote);
    }
    return result;
  }

  async set(key: string, quote: MarketQuote, ttlSeconds: number): Promise<void> {
    this.values.set(key, { quote, expiresAt: Date.now() + ttlSeconds * 1000 });
  }
}

/**
 * Real Redis implementation via Upstash REST. Credentials exist only on the
 * server. No mobile client ever talks to Redis directly.
 */
export class UpstashRedisQuoteCache implements ServerQuoteCache {
  constructor(
    private readonly baseUrl: string,
    private readonly token: string,
  ) {
    const url = new URL(baseUrl);
    if (url.protocol !== 'https:') throw new Error('UPSTASH_REDIS_REST_URL must use HTTPS');
    if (!token.trim()) throw new Error('UPSTASH_REDIS_REST_TOKEN is empty');
  }

  private async post(path: string, body: unknown): Promise<unknown> {
    const response = await fetch(`${this.baseUrl.replace(/\/$/, '')}${path}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    if (!response.ok) throw new MarketDataUnavailable(`Redis returned HTTP ${response.status}`);
    return response.json();
  }

  async getMany(keys: string[]): Promise<Map<string, MarketQuote>> {
    if (keys.length === 0) return new Map();
    const payload = await this.post('/pipeline', keys.map(key => ['GET', key]));
    if (!Array.isArray(payload) || payload.length !== keys.length) {
      throw new MarketDataUnavailable('Redis pipeline response mismatch');
    }
    const found = new Map<string, MarketQuote>();
    for (let index = 0; index < payload.length; index++) {
      const item = payload[index] as { result?: unknown; error?: unknown };
      if (item?.error) throw new MarketDataUnavailable('Redis pipeline command failed');
      if (typeof item?.result !== 'string') continue;
      let decoded: unknown;
      try {
        decoded = JSON.parse(item.result);
      } catch {
        continue;
      }
      const parsed = quoteSchema.safeParse(decoded);
      if (parsed.success) found.set(keys[index]!, parsed.data);
    }
    return found;
  }

  async set(key: string, quote: MarketQuote, ttlSeconds: number): Promise<void> {
    await this.post('', ['SET', key, JSON.stringify(quote), 'EX', Math.max(1, ttlSeconds)]);
  }
}

function quoteKey(type: MarketAssetType, symbol: string): string {
  const market = type === 'crypto' ? 'GLOBAL' : 'CN';
  return `quote:${type}:${market}:${symbol.toUpperCase()}`;
}

function quoteTtl(type: MarketAssetType, at = new Date()): number {
  if (type === 'crypto') return 120;
  const day = at.getUTCDay();
  // China Standard Time = UTC+8. The server may run anywhere.
  const chinaMinutes = ((at.getUTCHours() + 8) % 24) * 60 + at.getUTCMinutes();
  const weekday = day !== 0 && day !== 6;
  const open = weekday && (
    (chinaMinutes >= 570 && chinaMinutes <= 690) ||
    (chinaMinutes >= 780 && chinaMinutes <= 900)
  );
  if (open) return type === 'stock' ? 240 : type === 'fund' ? 3600 : 1200;
  return type === 'stock' ? 7200 : type === 'fund' ? 43_200 : 21_600;
}

function createCache(): ServerQuoteCache {
  const url = process.env.UPSTASH_REDIS_REST_URL?.trim();
  const token = process.env.UPSTASH_REDIS_REST_TOKEN?.trim();
  if ((url && !token) || (!url && token)) {
    throw new Error('UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN must be configured together');
  }
  return url && token ? new UpstashRedisQuoteCache(url, token) : new MemoryServerQuoteCache();
}

export function registerMarketDataRoutes(
  app: FastifyInstance,
  provider: ServerMarketDataProvider = new NormalizedHttpMarketDataProvider(),
  cache: ServerQuoteCache = createCache(),
) {
  app.get('/api/v1/market/search', { config: { rateLimit: { max: 120, timeWindow: '1 minute' } } }, async request => {
    const query = searchQuery.parse(request.query);
    try {
      return { source: provider.name, results: await provider.search(query.q, query.type, query.limit) };
    } catch (error) {
      if (error instanceof MarketDataUnavailable) {
        return app.httpErrors?.serviceUnavailable?.(error.message) ?? Promise.reject(Object.assign(error, { statusCode: 503 }));
      }
      throw error;
    }
  });

  app.post('/api/v1/market/quotes', { config: { rateLimit: { max: 180, timeWindow: '1 minute' } } }, async request => {
    const body = quotesBody.parse(request.body);
    const keys = body.requests.map(item => quoteKey(item.type, item.symbol));
    let cached: Map<string, MarketQuote>;
    try {
      cached = await cache.getMany(keys);
    } catch {
      cached = new Map();
    }
    const missing = body.requests.filter((_, index) => !cached.has(keys[index]!));
    if (missing.length > 0) {
      let fresh: MarketQuote[];
      try {
        fresh = await provider.quotes(missing);
      } catch (error) {
        if (cached.size > 0) {
          return { source: 'cache-stale', quotes: [...cached.values()], partial: true };
        }
        if (error instanceof MarketDataUnavailable) {
          throw Object.assign(error, { statusCode: 503 });
        }
        throw error;
      }
      for (const quote of fresh) {
        const parsed = quoteSchema.parse(quote);
        const key = quoteKey(parsed.type, parsed.symbol);
        cached.set(key, parsed);
        try {
          await cache.set(key, parsed, quoteTtl(parsed.type));
        } catch {
          // A cache outage must never turn a successful vendor quote into a
          // user-visible outage. The next request can fetch the provider again.
        }
      }
    }
    return {
      source: provider.name,
      quotes: body.requests.map((item, index) => cached.get(keys[index]!) ?? null),
      partial: body.requests.some((_, index) => !cached.has(keys[index]!)),
    };
  });

  app.get('/api/v1/market/history', { config: { rateLimit: { max: 60, timeWindow: '1 minute' } } }, async request => {
    const query = historyQuery.parse(request.query);
    try {
      return {
        source: provider.name,
        points: await provider.history(query.symbol, query.type, query.days),
      };
    } catch (error) {
      if (error instanceof MarketDataUnavailable) throw Object.assign(error, { statusCode: 503 });
      throw error;
    }
  });
}
