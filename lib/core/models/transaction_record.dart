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
  adjustment,
}

enum TransactionSource { manual, voice, ocr, auto, import }

enum SyncStatus { localOnly, pending, synced, conflict }

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
    TransactionType.repayment ||
    TransactionType.assetPurchase => true,
    _ => false,
  };

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
      metadataJson: metadataJson,
      duplicateConfidence: duplicateConfidence ?? this.duplicateConfidence,
      visibility: visibility ?? this.visibility,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
    );
  }
}
