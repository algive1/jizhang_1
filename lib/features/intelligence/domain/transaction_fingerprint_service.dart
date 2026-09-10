import 'dart:convert';

import '../../../core/models/transaction_intelligence.dart';
import '../../../core/models/transaction_record.dart';
import 'merchant_classification_service.dart';

class TransactionFingerprintService {
  const TransactionFingerprintService({
    this.normalizer = const MerchantNormalizer(),
  });

  final MerchantNormalizer normalizer;

  TransactionFingerprint create(TransactionRecord transaction) {
    final metadata = _metadata(transaction.metadataJson);
    return TransactionFingerprint(
      amountInCents: (transaction.amount * 100).round(),
      occurredAt: transaction.occurredAt,
      normalizedMerchant: normalizer.normalize(transaction.merchant),
      accountId: transaction.accountId,
      source: transaction.source.name,
      paymentChannel: _text(metadata['paymentChannel']),
      cardLastFour: _text(metadata['cardLastFour']),
      orderId: _text(metadata['orderId']),
    );
  }

  DuplicateDecision compare(TransactionRecord left, TransactionRecord right) {
    if (left.id == right.id ||
        left.type != right.type ||
        left.bookId != right.bookId ||
        left.currency.toUpperCase() != right.currency.toUpperCase()) {
      return const DuplicateDecision(
        type: DuplicateDecisionType.unrelated,
        confidence: 0,
        reasonCode: 'different_record_type_book_or_currency',
      );
    }
    final a = create(left);
    final b = create(right);
    if (a.amountInCents != b.amountInCents) {
      return const DuplicateDecision(
        type: DuplicateDecisionType.unrelated,
        confidence: 0,
        reasonCode: 'different_amount',
      );
    }
    final seconds = a.occurredAt.difference(b.occurredAt).inSeconds.abs();
    if (seconds > 24 * 60 * 60) {
      return const DuplicateDecision(
        type: DuplicateDecisionType.unrelated,
        confidence: .05,
        reasonCode: 'outside_time_window',
      );
    }

    if (a.orderId != null && a.orderId == b.orderId) {
      return const DuplicateDecision(
        type: DuplicateDecisionType.highConfidenceDuplicate,
        confidence: .995,
        reasonCode: 'same_order_id',
      );
    }

    final sameMerchant =
        a.normalizedMerchant.isNotEmpty &&
        a.normalizedMerchant == b.normalizedMerchant;
    final sameAccount = a.accountId == b.accountId;
    final bothManual =
        left.source == TransactionSource.manual &&
        right.source == TransactionSource.manual;
    if (sameMerchant && sameAccount && seconds <= 120) {
      if (bothManual) {
        return const DuplicateDecision(
          type: DuplicateDecisionType.suspicious,
          confidence: .72,
          reasonCode: 'manual_same_merchant_amount_time',
        );
      }
      return const DuplicateDecision(
        type: DuplicateDecisionType.highConfidenceDuplicate,
        confidence: .985,
        reasonCode: 'same_merchant_account_amount_time',
      );
    }

    if (_isCrossChannelPayment(a, b) && seconds <= 300) {
      return const DuplicateDecision(
        type: DuplicateDecisionType.sameEconomicEvent,
        confidence: .9,
        reasonCode: 'wallet_and_bank_same_payment',
      );
    }

    if (sameMerchant && seconds <= 600) {
      return const DuplicateDecision(
        type: DuplicateDecisionType.suspicious,
        confidence: .68,
        reasonCode: 'same_merchant_amount_near_time',
      );
    }
    return DuplicateDecision(
      type: DuplicateDecisionType.unrelated,
      confidence: seconds <= 300 ? .2 : .1,
      reasonCode: 'same_amount_insufficient_evidence',
    );
  }

  bool _isCrossChannelPayment(
    TransactionFingerprint left,
    TransactionFingerprint right,
  ) {
    final channels = {
      left.paymentChannel?.toLowerCase(),
      right.paymentChannel?.toLowerCase(),
    }..remove(null);
    final hasWallet = channels.any(
      (value) => value == 'alipay' || value == 'wechat',
    );
    final hasBank = channels.any((value) => value == 'bank' || value == 'card');
    return hasWallet && hasBank && left.accountId != right.accountId;
  }

  Map<String, Object?> _metadata(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) return value;
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
