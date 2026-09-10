enum MerchantRuleMatchType { exact, keyword }

enum MerchantRuleSource { userCorrection, exactMerchant, keyword }

class MerchantRule {
  const MerchantRule({
    required this.id,
    required this.merchantPattern,
    required this.normalizedPattern,
    required this.matchType,
    required this.categoryId,
    required this.confidence,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.subcategoryId,
    this.userId,
  });

  final String id;
  final String merchantPattern;
  final String normalizedPattern;
  final MerchantRuleMatchType matchType;
  final String categoryId;
  final String? subcategoryId;
  final String? userId;
  final double confidence;
  final MerchantRuleSource source;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum ClassificationSource {
  personalRule,
  exactMerchant,
  keyword,
  defaultCategory,
  pending,
}

class ClassificationResult {
  const ClassificationResult({
    required this.source,
    required this.confidence,
    this.categoryId,
    this.subcategoryId,
    this.matchedRuleId,
  });

  final String? categoryId;
  final String? subcategoryId;
  final ClassificationSource source;
  final double confidence;
  final String? matchedRuleId;

  bool get needsConfirmation => source == ClassificationSource.pending;
}

class TransactionFingerprint {
  const TransactionFingerprint({
    required this.amountInCents,
    required this.occurredAt,
    required this.normalizedMerchant,
    required this.accountId,
    required this.source,
    required this.paymentChannel,
    required this.cardLastFour,
    required this.orderId,
  });

  final int amountInCents;
  final DateTime occurredAt;
  final String normalizedMerchant;
  final String accountId;
  final String source;
  final String? paymentChannel;
  final String? cardLastFour;
  final String? orderId;

  String get canonical => [
    amountInCents,
    occurredAt.toUtc().toIso8601String(),
    normalizedMerchant,
    accountId,
    source,
    paymentChannel ?? '',
    cardLastFour ?? '',
    orderId ?? '',
  ].join('|');
}

enum DuplicateDecisionType {
  unrelated,
  suspicious,
  highConfidenceDuplicate,
  sameEconomicEvent,
}

class DuplicateDecision {
  const DuplicateDecision({
    required this.type,
    required this.confidence,
    required this.reasonCode,
  });

  final DuplicateDecisionType type;
  final double confidence;
  final String reasonCode;

  bool get needsReview => type != DuplicateDecisionType.unrelated;
}

enum InboxReason { uncertainCategory, suspectedDuplicate, missingAccount }

enum InboxStatus { pending, accepted, dismissed }

class BillInboxItem {
  const BillInboxItem({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.transactionId,
    this.candidateTransactionId,
    this.duplicateConfidence,
    this.payloadJson,
    this.resolvedAt,
  });

  final String id;
  final String? transactionId;
  final String? candidateTransactionId;
  final InboxReason reason;
  final InboxStatus status;
  final double? duplicateConfidence;
  final String? payloadJson;
  final DateTime createdAt;
  final DateTime? resolvedAt;
}

enum EconomicEventStatus { candidate, confirmed, dismissed }

class EconomicEvent {
  const EconomicEvent({
    required this.id,
    required this.bookId,
    required this.amount,
    required this.occurredAt,
    required this.status,
    required this.transactionIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final double amount;
  final DateTime occurredAt;
  final EconomicEventStatus status;
  final List<String> transactionIds;
  final DateTime createdAt;
  final DateTime updatedAt;
}
