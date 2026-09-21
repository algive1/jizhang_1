import 'family.dart';

enum TransactionType {
  expense,
  income,
  transfer,
  refund,
  reimbursement,
  borrow,
  lend,
  repayment,
  assetPurchase,
  assetSale,
  adjustment,
}

enum TransactionSource { manual, voice, ocr, auto, import }

enum SyncStatus { localOnly, pending, synced, conflict }

/// Lifecycle of a reimbursement attached to an original expense.
enum ReimbursementStatus { none, pending, reimbursed, partial }

/// Refund lifecycle for an original expense.
enum RefundStatus { none, partial, refunded }

class TransactionRecord {
  static const Object _copyWithUnset = Object();

  const TransactionRecord({
    required this.id,
    required this.bookId,
    required this.type,
    required this.amount,
    this.currency = 'CNY',
    required this.accountId,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.subcategoryId,
    this.subcategoryName,
    this.subcategoryIcon,
    this.destinationAccountId,
    this.merchant,
    this.note,
    this.deletedAt,
    this.isRecurring = false,
    this.isOneTime = true,
    this.isLargeTransaction = false,
    this.isPlanned = false,
    this.source = TransactionSource.manual,
    this.aiConfidence,
    this.userCorrected = false,
    this.syncStatus = SyncStatus.localOnly,
    this.deviceId,
    this.originalTransactionId,
    this.relatedTransactionId,
    this.reimbursementStatus = ReimbursementStatus.none,
    this.reimbursementAmount,
    this.reimbursementDate,
    this.reimbursementNote,
    this.refundStatus = RefundStatus.none,
    this.refundAmount,
    this.metadataJson,
    this.duplicateConfidence,
    this.visibility = TransactionVisibility.private,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
  });

  final String id;
  final String bookId;
  final String? userId;
  final TransactionType type;
  final double amount;
  final String currency;
  final String? categoryId;
  final String? categoryName;

  /// Persisted category icon key resolved from the category belonging to the
  /// transaction's book. This is intentionally kept out of the transaction
  /// table so category renames still follow the category ID.
  final String? categoryIcon;
  final String? subcategoryId;
  final String? subcategoryName;
  final String? subcategoryIcon;
  final String accountId;
  final String? destinationAccountId;
  final String? merchant;
  final String? note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isRecurring;
  final bool isOneTime;
  final bool isLargeTransaction;
  final bool isPlanned;
  final TransactionSource source;
  final double? aiConfidence;
  final bool userCorrected;
  final SyncStatus syncStatus;
  final String? deviceId;
  final String? originalTransactionId;
  final String? relatedTransactionId;
  final ReimbursementStatus reimbursementStatus;
  final double? reimbursementAmount;
  final DateTime? reimbursementDate;
  final String? reimbursementNote;
  final RefundStatus refundStatus;
  final double? refundAmount;
  final String? metadataJson;
  final double? duplicateConfidence;
  final TransactionVisibility visibility;
  final String? createdBy;
  final String? updatedBy;
  final int version;

  bool get isIncome => switch (type) {
    TransactionType.income ||
    TransactionType.refund ||
    TransactionType.reimbursement ||
    TransactionType.borrow => true,
    _ => false,
  };

  bool get isExpense => switch (type) {
    TransactionType.expense ||
    TransactionType.lend ||
    TransactionType.assetPurchase => true,
    _ => false,
  };

  /// A row that converts between cash and an investment position.
  ///
  /// These rows are real account movements: they appear in the ledger and
  /// change account balances, but they are never consumption. Buying a fund
  /// does not spend money, it moves money.
  bool get isAssetTransfer =>
      type == TransactionType.assetPurchase ||
      type == TransactionType.assetSale;

  /// Consumption expense used by reports, budgets and the home totals.
  ///
  /// Asset conversions are excluded so an investment purchase never inflates
  /// the monthly spending figure.
  bool get isConsumptionExpense => isExpense && !isAssetTransfer;

  /// Debt repayments reduce cash or a liability but do not represent a new
  /// consumption. They remain transaction rows for auditability.
  bool get isDebtRepayment => type == TransactionType.repayment;

  /// Amount used by consumption reports after a partial or full refund.
  double get netExpenseAmount => isExpense
      ? (amount - (refundAmount ?? 0)).clamp(0, amount).toDouble()
      : 0;

  /// Amount that should count toward the user's own consumption after known
  /// refunds and reimbursements. Pending or completed full reimbursements do
  /// not consume a personal budget; partial reimbursements keep only the
  /// unreimbursed remainder.
  double get personalExpenseAmount {
    if (!isConsumptionExpense) return 0;
    final afterRefund = netExpenseAmount;
    final reimbursable = switch (reimbursementStatus) {
      ReimbursementStatus.none => 0.0,
      ReimbursementStatus.pending || ReimbursementStatus.reimbursed =>
        reimbursementAmount ?? afterRefund,
      ReimbursementStatus.partial => reimbursementAmount ?? 0.0,
    };
    return (afterRefund - reimbursable).clamp(0, afterRefund).toDouble();
  }

  /// The category label shown in transaction lists and details.
  ///
  /// Category names are resolved from the persisted category ID when a
  /// record is read from the database. Keep the special transaction types
  /// readable even though they do not have a category.
  String get displayCategoryLabel => switch (type) {
    TransactionType.assetSale => '资产卖出',
    TransactionType.adjustment => '余额校准',
    TransactionType.transfer => '转账',
    _ => categoryName?.trim().isNotEmpty == true ? categoryName!.trim() : '未分类',
  };

  String get displayCategoryPath {
    final child = _displayValue(subcategoryName);
    return child == null ? displayCategoryLabel : '$displayCategoryLabel · $child';
  }

  String get displayLeafCategoryLabel =>
      _displayValue(subcategoryName) ?? displayCategoryLabel;

  String? get displayCategoryIconKey =>
      _displayValue(subcategoryIcon) ?? _displayValue(categoryIcon);

  /// The primary text for a transaction row.
  ///
  /// Manual bookkeeping keeps a user-entered note as the most specific label.
  /// Imported bills intentionally keep the merchant first so the persisted
  /// ledger matches the import preview even when provider exports also contain
  /// a generic product/remark field.
  String get displayTitle {
    final noteValue = _displayValue(note);
    final merchantValue = _displayValue(merchant);
    if (source == TransactionSource.import) {
      if (merchantValue != null) return merchantValue;
      if (noteValue != null) return noteValue;
    } else {
      if (noteValue != null) return noteValue;
      if (merchantValue != null) return merchantValue;
    }
    return displayLeafCategoryLabel;
  }

  String? _displayValue(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty || cleaned == '/' || cleaned == '／') {
      return null;
    }
    return cleaned;
  }

  TransactionRecord copyWith({
    TransactionType? type,
    double? amount,
    String? currency,
    String? categoryId,
    Object? categoryName = _copyWithUnset,
    String? subcategoryId,
    String? accountId,
    String? destinationAccountId,
    String? merchant,
    String? note,
    DateTime? occurredAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    bool? isRecurring,
    bool? isOneTime,
    bool? isLargeTransaction,
    bool? isPlanned,
    bool? userCorrected,
    double? duplicateConfidence,
    TransactionVisibility? visibility,
    String? updatedBy,
    int? version,
    String? relatedTransactionId,
    ReimbursementStatus? reimbursementStatus,
    Object? reimbursementAmount = _copyWithUnset,
    Object? reimbursementDate = _copyWithUnset,
    Object? reimbursementNote = _copyWithUnset,
    RefundStatus? refundStatus,
    Object? refundAmount = _copyWithUnset,
    bool clearRefundAmount = false,
    Object? metadataJson = _copyWithUnset,
  }) {
    return TransactionRecord(
      id: id,
      bookId: bookId,
      userId: userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      categoryName: identical(categoryName, _copyWithUnset)
          ? ((categoryId != null && categoryId != this.categoryId)
                ? null
                : this.categoryName)
          : categoryName as String?,
      categoryIcon: (categoryId != null && categoryId != this.categoryId)
          ? null
          : categoryIcon,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      subcategoryName:
          (subcategoryId != null && subcategoryId != this.subcategoryId)
          ? null
          : this.subcategoryName,
      subcategoryIcon:
          (subcategoryId != null && subcategoryId != this.subcategoryId)
          ? null
          : this.subcategoryIcon,
      accountId: accountId ?? this.accountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      isRecurring: isRecurring ?? this.isRecurring,
      isOneTime: isOneTime ?? this.isOneTime,
      isLargeTransaction: isLargeTransaction ?? this.isLargeTransaction,
      isPlanned: isPlanned ?? this.isPlanned,
      source: source,
      aiConfidence: aiConfidence,
      userCorrected: userCorrected ?? this.userCorrected,
      syncStatus: syncStatus,
      deviceId: deviceId,
      originalTransactionId: originalTransactionId,
      relatedTransactionId: relatedTransactionId ?? this.relatedTransactionId,
      reimbursementStatus: reimbursementStatus ?? this.reimbursementStatus,
      reimbursementAmount: identical(reimbursementAmount, _copyWithUnset)
          ? this.reimbursementAmount
          : (reimbursementAmount as num?)?.toDouble(),
      reimbursementDate: identical(reimbursementDate, _copyWithUnset)
          ? this.reimbursementDate
          : reimbursementDate as DateTime?,
      reimbursementNote: identical(reimbursementNote, _copyWithUnset)
          ? this.reimbursementNote
          : reimbursementNote as String?,
      refundStatus: refundStatus ?? this.refundStatus,
      refundAmount: clearRefundAmount
          ? null
          : (identical(refundAmount, _copyWithUnset)
                ? this.refundAmount
                : (refundAmount as num?)?.toDouble()),
      metadataJson: identical(metadataJson, _copyWithUnset)
          ? this.metadataJson
          : metadataJson as String?,
      duplicateConfidence: duplicateConfidence ?? this.duplicateConfidence,
      visibility: visibility ?? this.visibility,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
    );
  }
}
