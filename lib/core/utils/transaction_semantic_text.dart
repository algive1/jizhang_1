import 'dart:convert';

import '../models/transaction_record.dart';

/// Builds a local-only semantic text surface for deterministic insight rules.
///
/// Imported bookkeeping apps often preserve important labels (for example
/// "父母", "外卖", "美妆") in metadata instead of merchant/note fields. This
/// helper deliberately reads only a small allowlist of semantic source fields
/// and tags. Callers can classify locally or convert them to booleans before
/// any server request.
String transactionSemanticText(TransactionRecord item) {
  final values = <String>[
    if (item.categoryName?.trim().isNotEmpty == true) item.categoryName!.trim(),
    if (item.merchant?.trim().isNotEmpty == true) item.merchant!.trim(),
    if (item.note?.trim().isNotEmpty == true) item.note!.trim(),
  ];

  final raw = item.metadataJson;
  if (raw != null && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final key in const [
          'sourceCategory',
          'sourceSubcategory',
          'sourceMember',
        ]) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            values.add(value.trim());
          }
        }
        final tags = decoded['tags'];
        if (tags is List) {
          for (final value in tags) {
            if (value is String && value.trim().isNotEmpty) {
              values.add(value.trim());
            }
          }
        }
      }
    } on Object {
      // Legacy or malformed metadata must never block local insight analysis.
    }
  }

  return values.toSet().join(' ');
}
