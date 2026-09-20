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
  }) =>
      item.deletedAt == null &&
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
  }) =>
      records
          .where(
            (item) => isEligible(item, currency: currency, now: now),
          )
          .toList(growable: false);

  List<TransactionRecord> personalConsumptionRows(
    Iterable<TransactionRecord> records, {
    required String currency,
    required DateTime now,
  }) =>
      eligibleRows(records, currency: currency, now: now)
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
  }) {
    final normalized = <TransactionRecord>[];
    for (final item in eligibleRows(records, currency: currency, now: now)) {
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
