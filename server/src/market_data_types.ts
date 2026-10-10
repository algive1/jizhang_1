export type MarketAssetType = 'stock' | 'fund' | 'bond' | 'crypto';
export interface MarketQuote {
  symbol: string;
  name: string;
  type: MarketAssetType;
  price: number;
  change: number;
  changePercent: number;
  currency: string;
  timestamp: string;
}
export interface MarketSearchResult extends MarketQuote { market?: string }
export interface MarketHistoryPoint { date: string; value: number }
export interface ServerMarketDataProvider {
  readonly name: string;
  search(query: string, type: MarketAssetType | undefined, limit: number): Promise<MarketSearchResult[]>;
  quotes(requests: Array<{ symbol: string; type: MarketAssetType }>): Promise<MarketQuote[]>;
  history(symbol: string, type: MarketAssetType, days: number): Promise<MarketHistoryPoint[]>;
}
export class MarketDataUnavailable extends Error {}
