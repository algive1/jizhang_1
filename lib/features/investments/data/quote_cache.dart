import 'dart:async';

import '../domain/investment_quote.dart';

/// Storage contract for shared market quotes.
///
/// Business code depends only on this interface, so moving from the MVP's
/// in-process map to Redis is a one-line provider swap and never a UI change.
///
/// Keys are always *per security*, never per user:
/// `quote:stock:CN:600519` is fetched once and served to every user holding
/// 600519. A `user:123:quote:600519` style key would defeat the cache.
abstract interface class QuoteCache {
  Future<InvestmentQuote?> get(String key);

  Future<void> set(String key, InvestmentQuote quote, {Duration? ttl});

  Future<void> remove(String key);

  /// Reads a batch in one round trip. Order is not significant; callers key
  /// the result by [InvestmentQuote.cacheKey].
  Future<Map<String, InvestmentQuote>> getMany(List<String> keys);

  Future<void> clear();
}

/// MVP implementation: an in-process map with per-entry expiry.
///
/// This is deliberately the only cache the first release ships — it needs no
/// infrastructure and still deduplicates repeated page opens within one app
/// session. It is dropped when the process dies, which is acceptable because
/// quotes are cheap to re-fetch on demand.
class MemoryQuoteCache implements QuoteCache {
  MemoryQuoteCache({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, _CacheEntry> _entries = {};

  @override
  Future<InvestmentQuote?> get(String key) async {
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.isExpired(_clock())) {
      _entries.remove(key);
      return null;
    }
    return entry.quote;
  }

  @override
  Future<Map<String, InvestmentQuote>> getMany(List<String> keys) async {
    final now = _clock();
    final found = <String, InvestmentQuote>{};
    for (final key in keys) {
      final entry = _entries[key];
      if (entry == null) continue;
      if (entry.isExpired(now)) {
        _entries.remove(key);
        continue;
      }
      found[key] = entry.quote;
    }
    return found;
  }

  @override
  Future<void> set(
    String key,
    InvestmentQuote quote, {
    Duration? ttl,
  }) async {
    _entries[key] = _CacheEntry(
      quote: quote,
      expiresAt: _clock().add(ttl ?? const Duration(minutes: 5)),
    );
  }

  @override
  Future<void> remove(String key) async {
    _entries.remove(key);
  }

  @override
  Future<void> clear() async => _entries.clear();

  /// Test/diagnostics hook: how many live entries the cache is holding.
  int get size => _entries.length;
}

class _CacheEntry {
  const _CacheEntry({required this.quote, required this.expiresAt});

  final InvestmentQuote quote;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);
}

/// Placeholder for the production cache. It implements the same contract but
/// fails loudly rather than silently behaving like a memory cache, so a
/// half-configured deployment cannot masquerade as a working one.
///
/// To go live: implement `get`/`set`/`getMany` with your Redis client, add the
/// connection settings to the server config, and switch
/// `quoteCacheProvider` to return it. Nothing else changes.
class RedisQuoteCache implements QuoteCache {
  const RedisQuoteCache({required this.client});

  /// The Redis client, injected so this file needs no Redis dependency yet.
  final Object? client;

  Never _unimplemented() => throw UnimplementedError(
    'RedisQuoteCache 尚未接入。请实现 get/set/getMany 后在 '
    'quoteCacheProvider 中替换 MemoryQuoteCache。',
  );

  @override
  Future<InvestmentQuote?> get(String key) async => _unimplemented();

  @override
  Future<Map<String, InvestmentQuote>> getMany(List<String> keys) async =>
      _unimplemented();

  @override
  Future<void> set(
    String key,
    InvestmentQuote quote, {
    Duration? ttl,
  }) async => _unimplemented();

  @override
  Future<void> remove(String key) async => _unimplemented();

  @override
  Future<void> clear() async => _unimplemented();
}
