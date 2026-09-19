import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/models/transaction_record.dart';
import '../transactions/data/transactions_repository.dart';
import 'auto_bookkeeping_pending.dart';

class AutoBookkeepingRefundMatcher {
  const AutoBookkeepingRefundMatcher(this._transactions);

  final TransactionRepository _transactions;

  Future<TransactionRecord?> findOriginal({
    required PendingAutoBookkeepingCandidate candidate,
    required String bookId,
  }) async {
    if (candidate.transactionType != 'REFUND') return null;
    final orderId = candidate.orderId?.trim();
    if (orderId == null || orderId.isEmpty) return null;

    final refundCents = candidate.amountInCents;
    final matches = (await _transactions.getAll()).where((transaction) {
      if (transaction.bookId != bookId ||
          transaction.type != TransactionType.expense) {
        return false;
      }
      final refundedCents = ((transaction.refundAmount ?? 0) * 100).round();
      final remainingCents =
          (transaction.amount * 100).round() - refundedCents;
      if (refundCents > remainingCents) return false;
      return _orderId(transaction.metadataJson) == orderId;
    }).toList(growable: false);

    if (matches.length == 1) return matches.single;
    if (matches.length < 2) return null;

    final sameSource = matches.where((transaction) {
      final source = _autoBookkeepingSource(transaction.metadataJson);
      return source != null && source == candidate.sourceApp;
    }).toList(growable: false);
    return sameSource.length == 1 ? sameSource.single : null;
  }

  String? _orderId(String? raw) {
    final metadata = _metadata(raw);
    final direct = _text(metadata['orderId']);
    if (direct != null) return direct;
    final auto = metadata['autobookkeeping'];
    return auto is Map ? _text(auto['orderId']) : null;
  }

  String? _autoBookkeepingSource(String? raw) {
    final metadata = _metadata(raw);
    final auto = metadata['autobookkeeping'];
    return auto is Map ? _text(auto['sourceApp']) : null;
  }

  Map<String, Object?> _metadata(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } on FormatException {
      return const {};
    }
    return const {};
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

final autoBookkeepingRefundMatcherProvider =
    Provider<AutoBookkeepingRefundMatcher>((ref) {
      return AutoBookkeepingRefundMatcher(
        DriftTransactionRepository(ref.watch(databaseProvider)),
      );
    });
