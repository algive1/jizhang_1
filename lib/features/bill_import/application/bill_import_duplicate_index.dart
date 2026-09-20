import 'dart:convert';

import '../../../core/models/transaction_record.dart';
import 'bill_import_service.dart';

class BillImportDuplicateIndex {
  BillImportDuplicateIndex(Iterable<TransactionRecord> existing) {
    for (final transaction in existing) {
      if (transaction.source != TransactionSource.import) continue;
      final raw = transaction.metadataJson;
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final provider = decoded['importProvider']?.toString().trim();
        final externalId = decoded['externalId']?.toString().trim();
        final fingerprint = decoded['importFingerprint']?.toString().trim();
        if (provider != null &&
            provider.isNotEmpty &&
            provider != BillImportProvider.generic.name &&
            externalId != null &&
            externalId.isNotEmpty) {
          _externalKeys.add('$provider|$externalId');
        }
        if (fingerprint != null && fingerprint.isNotEmpty) {
          _fingerprints.add(fingerprint);
        }
      } on Object {
        // Malformed historical metadata is ignored; it must never block import.
      }
    }
  }

  final Set<String> _externalKeys = {};
  final Set<String> _fingerprints = {};

  bool contains(ImportedBillRow row) {
    final externalId = row.externalId?.trim();
    if (row.provider != BillImportProvider.generic &&
        externalId != null &&
        externalId.isNotEmpty &&
        _externalKeys.contains('${row.provider.name}|$externalId')) {
      return true;
    }
    return _fingerprints.contains(row.importFingerprint);
  }

  void add(ImportedBillRow row) {
    final externalId = row.externalId?.trim();
    if (row.provider != BillImportProvider.generic &&
        externalId != null &&
        externalId.isNotEmpty) {
      _externalKeys.add('${row.provider.name}|$externalId');
    }
    _fingerprints.add(row.importFingerprint);
  }
}
