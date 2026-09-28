import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/models/transaction_record.dart';
import '../transactions/data/transactions_repository.dart';
import 'auto_bookkeeping_pending.dart';

class AutoBookkeepingRefundMatcher {
  const AutoBookkeepingRefundMatcher(
    this._transactions, {
    AppDatabase? database,
  }) : _database = database;

  final TransactionRepository _transactions;
  final AppDatabase? _database;

  Future<TransactionRecord?> findOriginal({
    required PendingAutoBookkeepingCandidate candidate,
    required String bookId,
  }) async {
    if (candidate.transactionType != 'REFUND') return null;
    final orderId = candidate.orderId?.trim();
    if (orderId == null || orderId.isEmpty) return null;

    final refundCents = candidate.amountInCents;
    final database = _database;
    final candidates = database == null
        ? await _transactions.getAll()
        : await _loadOrderCandidates(
            database: database,
            bookId: bookId,
            orderId: orderId,
          );
    final matches = candidates.where((transaction) {
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

  Future<List<TransactionRecord>> _loadOrderCandidates({
    required AppDatabase database,
    required String bookId,
    required String orderId,
  }) async {
    final ids = await database.transactionDao.findExpenseIdsByOrderId(
      bookId: bookId,
      orderId: orderId,
    );
    final rows = await Future.wait(ids.map(_transactions.getById));
    return rows.whereType<TransactionRecord>().toList(growable: false);
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
      final database = ref.watch(databaseProvider);
      return AutoBookkeepingRefundMatcher(
        DriftTransactionRepository(database),
        database: database,
      );
    });
