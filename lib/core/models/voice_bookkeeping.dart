import 'transaction_record.dart';

enum VoiceParsingSource { rule, ai }

class ParsedVoiceTransaction {
  const ParsedVoiceTransaction({
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.confidence,
    required this.source,
    required this.rawFragment,
    this.categoryId,
    this.categoryName,
    this.subcategoryName,
    this.accountId,
    this.accountName,
    this.merchant,
  });

  final TransactionType type;
  final double amount;
  final String? categoryId;
  final String? categoryName;
  final String? subcategoryName;
  final String? accountId;
  final String? accountName;
  final String? merchant;
  final DateTime occurredAt;
  final double confidence;
  final VoiceParsingSource source;
  final String rawFragment;

  bool get needsReview =>
      confidence < .8 || categoryId == null || accountId == null;

  ParsedVoiceTransaction copyWith({
    double? amount,
    String? categoryId,
    String? categoryName,
    String? accountId,
    String? accountName,
    String? merchant,
    DateTime? occurredAt,
  }) {
    return ParsedVoiceTransaction(
      type: type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      subcategoryName: subcategoryName,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      merchant: merchant ?? this.merchant,
      occurredAt: occurredAt ?? this.occurredAt,
      confidence: confidence,
      source: source,
      rawFragment: rawFragment,
    );
  }
}

class TransactionParseResult {
  const TransactionParseResult({
    required this.transactions,
    required this.unresolvedFragments,
    required this.usedAi,
  });

  final List<ParsedVoiceTransaction> transactions;
  final List<String> unresolvedFragments;
  final bool usedAi;

  bool get needsReview =>
      unresolvedFragments.isNotEmpty ||
      transactions.any((item) => item.needsReview);
}
