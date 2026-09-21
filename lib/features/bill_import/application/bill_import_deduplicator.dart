import 'dart:convert';

import '../../../core/models/transaction_record.dart';
import 'bill_import_service.dart';

/// Deduplicates repeated and incremental bill imports without letting a weak
/// fallback override a provider-issued transaction identifier.
///
/// Priority:
/// 1. provider + external transaction id;
/// 2. exact import fingerprint when no external id is available;
/// 3. provider-independent natural fingerprint as a legacy fallback.
///
/// Historical generic rows that were later reclassified as WeChat/Alipay are
/// matched only when both their external id and natural fingerprint agree.
class BillImportDeduplicator {
  BillImportDeduplicator._();

  factory BillImportDeduplicator.fromTransactions(
    Iterable<TransactionRecord> transactions,
  ) {
    final result = BillImportDeduplicator._();
    for (final transaction in transactions) {
      if (transaction.source == TransactionSource.import) {
        result._rememberPersistedImport(transaction);
      } else if (transaction.source == TransactionSource.auto) {
        result._rememberAutomatic(transaction);
      }
    }
    return result;
  }

  final Set<String> _externalKeys = <String>{};
  final Map<String, Set<String>> _legacyGenericIds =
      <String, Set<String>>{};
  final Set<String> _importFingerprints = <String>{};
  final Set<String> _naturalFingerprints = <String>{};
  final Map<BillImportProvider, Set<String>> _automaticNaturals =
      <BillImportProvider, Set<String>>{};

  bool isDuplicate(ImportedBillRow row) {
    final externalId = _clean(row.externalId);
    if (externalId != null) {
      final key = _externalKey(
        row.provider,
        externalId,
        sourceBook: row.sourceBook,
        sourceAccount: row.sourceAccount,
      );
      if (_externalKeys.contains(key)) return true;

      // Older versions could classify an official export as generic. Keep
      // that migration path, but require the business fields to agree as well
      // so an unrelated generic file with the same numeric id is not hidden.
      if (row.provider != BillImportProvider.generic) {
        final legacyNaturals = _legacyGenericIds[externalId];
        if (legacyNaturals?.contains(row.naturalFingerprint) == true) {
          return true;
        }
      }

      // A provider-issued id is the strongest identity. Do not let a weaker
      // timestamp/amount/merchant fallback collapse two distinct transactions
      // that happen to look identical.
      return false;
    }

    if (_importFingerprints.contains(row.importFingerprint)) return true;
    if (_naturalFingerprints.contains(row.naturalFingerprint)) return true;
    return _automaticNaturals[row.provider]?.contains(row.naturalFingerprint) ==
        true;
  }

  void remember(ImportedBillRow row) {
    final externalId = _clean(row.externalId);
    if (externalId != null) {
      _externalKeys.add(
        _externalKey(
          row.provider,
          externalId,
          sourceBook: row.sourceBook,
          sourceAccount: row.sourceAccount,
        ),
      );
      if (row.provider == BillImportProvider.generic) {
        _legacyGenericIds
            .putIfAbsent(externalId, () => <String>{})
            .add(row.naturalFingerprint);
      }
    }
    _importFingerprints.add(row.importFingerprint);
    _naturalFingerprints.add(row.naturalFingerprint);
  }

  void _rememberPersistedImport(TransactionRecord transaction) {
    final natural = _naturalFingerprint(transaction);
    _naturalFingerprints.add(natural);

    final raw = transaction.metadataJson;
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final metadata = decoded.cast<Object?, Object?>();

      final importFingerprint = _clean(
        metadata['importFingerprint']?.toString(),
      );
      if (importFingerprint != null) {
        _importFingerprints.add(importFingerprint);
      }

      final persistedNatural = _clean(
        metadata['importNaturalFingerprint']?.toString(),
      );
      final effectiveNatural = persistedNatural ?? natural;
      _naturalFingerprints.add(effectiveNatural);

      final externalId = _clean(metadata['externalId']?.toString());
      if (externalId == null) return;

      final providerName = _clean(metadata['importProvider']?.toString());
      final provider = _provider(providerName);
      final sourceBook = _clean(metadata['sourceBook']?.toString());
      final sourceAccount = _clean(metadata['sourceAccount']?.toString());

      if (provider == null || provider == BillImportProvider.generic) {
        _externalKeys.add(
          _externalKey(
            BillImportProvider.generic,
            externalId,
            sourceBook: sourceBook,
            sourceAccount: sourceAccount,
          ),
        );
        _legacyGenericIds
            .putIfAbsent(externalId, () => <String>{})
            .add(effectiveNatural);
        return;
      }

      _externalKeys.add(
        _externalKey(
          provider,
          externalId,
          sourceBook: sourceBook,
          sourceAccount: sourceAccount,
        ),
      );
    } on Object {
      // Malformed historical metadata must never block new imports.
    }
  }


  void _rememberAutomatic(TransactionRecord transaction) {
    final raw = transaction.metadataJson;
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final metadata = decoded.cast<Object?, Object?>();

      BillImportProvider? provider;
      final packageName = _clean(metadata['paymentPackageName']?.toString());
      provider ??= _providerForPackage(packageName);

      final nested = metadata['autobookkeeping'];
      if (nested is Map) {
        final sourceApp = _clean(nested['sourceApp']?.toString());
        provider ??= _providerForSourceApp(sourceApp);
      }
      provider ??= _providerForSourceApp(
        _clean(metadata['sourceApp']?.toString()),
      );
      if (provider == null) return;

      final externalId =
          _clean(metadata['notificationOrderId']?.toString()) ??
          _clean(metadata['orderId']?.toString()) ??
          (nested is Map ? _clean(nested['orderId']?.toString()) : null);
      if (externalId != null) {
        _externalKeys.add(_externalKey(provider, externalId));
      }
      _automaticNaturals
          .putIfAbsent(provider, () => <String>{})
          .add(_naturalFingerprint(transaction));
    } on Object {
      // Automatic-bookkeeping metadata is best-effort compatibility context.
    }
  }

  static BillImportProvider? _providerForPackage(String? packageName) =>
      switch (packageName) {
        'com.tencent.mm' => BillImportProvider.wechat,
        'com.eg.android.AlipayGphone' => BillImportProvider.alipay,
        _ => null,
      };

  static BillImportProvider? _providerForSourceApp(String? sourceApp) =>
      switch (sourceApp?.toUpperCase()) {
        'WECHAT' => BillImportProvider.wechat,
        'ALIPAY' => BillImportProvider.alipay,
        _ => null,
      };

  static BillImportProvider? _provider(String? name) {
    if (name == null) return null;
    for (final provider in BillImportProvider.values) {
      if (provider.name == name) return provider;
    }
    return null;
  }

  static String _externalKey(
    BillImportProvider provider,
    String externalId, {
    String? sourceBook,
    String? sourceAccount,
  }) {
    if (provider != BillImportProvider.generic) {
      return '${provider.name}|${externalId.trim().toLowerCase()}';
    }
    return [
      provider.name,
      _clean(sourceBook)?.toLowerCase() ?? '',
      _clean(sourceAccount)?.toLowerCase() ?? '',
      externalId.trim().toLowerCase(),
    ].join('|');
  }

  static String _naturalFingerprint(TransactionRecord transaction) => [
    transaction.occurredAt.toIso8601String(),
    transaction.type.name,
    transaction.amount.toStringAsFixed(2),
    ((transaction.merchant?.trim().isNotEmpty == true
                ? transaction.merchant
                : transaction.note) ??
            '')
        .trim()
        .toLowerCase(),
  ].join('|');

  static String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
