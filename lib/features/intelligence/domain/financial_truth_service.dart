import '../../../core/models/transaction_record.dart';

/// A single deterministic interpretation of ledger rows for all consumer
/// surfaces (home, budgets, analysis and insights).
///
/// The ledger keeps every economic event for auditability. This service
/// answers a different question: which amounts are income, personal
/// consumption, or external cash movement for user-facing calculations.
class FinancialTruthService {
  const FinancialTruthService();

  bool isEligible(
    TransactionRecord item, {
    required String currency,
    required DateTime now,
    Set<String> excludedTransactionIds = const {},
  }) =>
      item.deletedAt == null &&
      !excludedTransactionIds.contains(item.id) &&
      !item.occurredAt.isAfter(now) &&
      item.currency.toUpperCase() == currency.toUpperCase();

  bool isEarnedIncome(TransactionRecord item) =>
      item.type == TransactionType.income;

  bool isPersonalConsumption(TransactionRecord item) =>
      item.isConsumptionExpense && item.personalExpenseAmount > .005;

  double earnedIncomeAmount(TransactionRecord item) =>
      isEarnedIncome(item) ? item.amount : 0;

  double personalConsumptionAmount(TransactionRecord item) =>
      isPersonalConsumption(item) ? item.personalExpenseAmount : 0;

  /// External cash entering the user's accounts.
  ///
  /// Internal transfers and adjustments are deliberately excluded.
  double externalCashInAmount(TransactionRecord item) => switch (item.type) {
    TransactionType.income ||
    TransactionType.refund ||
    TransactionType.reimbursement ||
    TransactionType.borrow ||
    TransactionType.assetSale => item.amount,
    _ => 0,
  };

  /// External cash leaving the user's accounts.
  ///
  /// Expense rows use the original cash movement. Refunds/reimbursements are
  /// represented by their own inflow rows, so cashflow must not net them twice.
  double externalCashOutAmount(TransactionRecord item) => switch (item.type) {
    TransactionType.expense ||
    TransactionType.lend ||
    TransactionType.repayment ||
    TransactionType.assetPurchase => item.amount,
    _ => 0,
  };

  List<TransactionRecord> eligibleRows(
    Iterable<TransactionRecord> records, {
    required String currency,
    required DateTime now,
    Set<String> excludedTransactionIds = const {},
  }) =>
      records
          .where(
            (item) => isEligible(
              item,
              currency: currency,
              now: now,
              excludedTransactionIds: excludedTransactionIds,
            ),
          )
          .toList(growable: false);

  List<TransactionRecord> personalConsumptionRows(
    Iterable<TransactionRecord> records, {
    required String currency,
    required DateTime now,
    Set<String> excludedTransactionIds = const {},
  }) =>
      eligibleRows(
        records,
        currency: currency,
        now: now,
        excludedTransactionIds: excludedTransactionIds,
      )
          .where(isPersonalConsumption)
          .toList(growable: false);

  /// Produces rows safe for behavioral/statistical analysis.
  ///
  /// Fully reimbursable/refunded consumption disappears; partial rows are
  /// rewritten to the amount actually borne by the user. Non-consumption rows
  /// remain untouched so income analysis still has the original ledger facts.
  List<TransactionRecord> normalizeForAnalysis(
    Iterable<TransactionRecord> records, {
    required String currency,
    required DateTime now,
    Set<String> excludedTransactionIds = const {},
  }) {
    final normalized = <TransactionRecord>[];
    for (final item in eligibleRows(
      records,
      currency: currency,
      now: now,
      excludedTransactionIds: excludedTransactionIds,
    )) {
      if (!item.isConsumptionExpense) {
        normalized.add(item);
        continue;
      }
      final personal = item.personalExpenseAmount;
      if (personal <= .005) continue;
      if ((personal - item.netExpenseAmount).abs() < .005) {
        normalized.add(item);
        continue;
      }
      normalized.add(
        item.copyWith(
          amount: personal,
          reimbursementStatus: ReimbursementStatus.none,
          reimbursementAmount: null,
          refundStatus: RefundStatus.none,
          clearRefundAmount: true,
        ),
      );
    }
    return List.unmodifiable(normalized);
  }

  FinancialTruthSummary summarize(
    Iterable<TransactionRecord> records, {
    required DateTime start,
    required DateTime endExclusive,
    required String currency,
    required DateTime now,
    Set<String> excludedTransactionIds = const {},
  }) {
    var earnedIncomeCents = 0;
    var personalConsumptionCents = 0;
    var cashInCents = 0;
    var cashOutCents = 0;
    var incomeCount = 0;
    var consumptionCount = 0;

    for (final item in eligibleRows(
      records,
      currency: currency,
      now: now,
      excludedTransactionIds: excludedTransactionIds,
    )) {
      if (item.occurredAt.isBefore(start) ||
          !item.occurredAt.isBefore(endExclusive)) {
        continue;
      }
      final earned = earnedIncomeAmount(item);
      final personal = personalConsumptionAmount(item);
      final cashIn = externalCashInAmount(item);
      final cashOut = externalCashOutAmount(item);
      earnedIncomeCents += (earned * 100).round();
      personalConsumptionCents += (personal * 100).round();
      cashInCents += (cashIn * 100).round();
      cashOutCents += (cashOut * 100).round();
      if (earned > 0) incomeCount++;
      if (personal > 0) consumptionCount++;
    }

    return FinancialTruthSummary(
      earnedIncome: earnedIncomeCents / 100,
      personalConsumption: personalConsumptionCents / 100,
      externalCashIn: cashInCents / 100,
      externalCashOut: cashOutCents / 100,
      incomeCount: incomeCount,
      consumptionCount: consumptionCount,
    );
  }

  Set<String> confirmedDuplicateSuppressionIds({
    required Iterable<TransactionRecord> records,
    required Map<String, List<String>> confirmedEventTransactionIds,
  }) {
    final byId = {for (final item in records) item.id: item};
    final suppressed = <String>{};
    for (final ids in confirmedEventTransactionIds.values) {
      final candidates = ids
          .map((id) => byId[id])
          .whereType<TransactionRecord>()
          .toList(growable: false);
      if (candidates.length < 2) continue;
      final canonical = [...candidates]
        ..sort((left, right) {
          final score = _canonicalScore(right) - _canonicalScore(left);
          if (score != 0) return score;
          final time = left.createdAt.compareTo(right.createdAt);
          if (time != 0) return time;
          return left.id.compareTo(right.id);
        });
      final keep = canonical.first.id;
      suppressed.addAll(
        candidates.where((item) => item.id != keep).map((item) => item.id),
      );
    }
    return Set.unmodifiable(suppressed);
  }

  int _canonicalScore(TransactionRecord item) {
    var score = 0;
    if (item.userCorrected) score += 100;
    if (item.categoryId?.trim().isNotEmpty == true) score += 24;
    if (item.subcategoryId?.trim().isNotEmpty == true) score += 8;
    if (item.merchant?.trim().isNotEmpty == true) score += 16;
    if (item.note?.trim().isNotEmpty == true) score += 8;
    if (item.metadataJson?.trim().isNotEmpty == true) score += 6;
    score += switch (item.source) {
      TransactionSource.manual => 20,
      TransactionSource.voice => 18,
      TransactionSource.auto => 16,
      TransactionSource.ocr => 14,
      TransactionSource.import => 12,
    };
    return score;
  }
}

class FinancialTruthSummary {
  const FinancialTruthSummary({
    required this.earnedIncome,
    required this.personalConsumption,
    required this.externalCashIn,
    required this.externalCashOut,
    required this.incomeCount,
    required this.consumptionCount,
  });

  final double earnedIncome;
  final double personalConsumption;
  final double externalCashIn;
  final double externalCashOut;
  final int incomeCount;
  final int consumptionCount;

  double get disposableDelta => earnedIncome - personalConsumption;
  double get externalCashflow => externalCashIn - externalCashOut;
}
