import '../../../core/models/account.dart';

enum AccountFundCategory { available, storedValue, restricted, custom }

extension AccountFundCategoryLabel on AccountFundCategory {
  String get label => switch (this) {
    AccountFundCategory.available => '可用资金',
    AccountFundCategory.storedValue => '储值资金',
    AccountFundCategory.restricted => '受限资金',
    AccountFundCategory.custom => '自定义账户',
  };
}

enum RestrictedFundStatus { locked, refundable, returning, returned }

extension RestrictedFundStatusLabel on RestrictedFundStatus {
  String get label => switch (this) {
    RestrictedFundStatus.locked => '锁定中',
    RestrictedFundStatus.refundable => '可退回',
    RestrictedFundStatus.returning => '退回处理中',
    RestrictedFundStatus.returned => '已退回',
  };
}

class ManagedAccount {
  const ManagedAccount({
    required this.account,
    required this.category,
    this.platform,
    this.restrictedStatus,
    this.expectedReturnAt,
    this.includeInTotal = true,
    this.note,
  });

  final Account account;
  final AccountFundCategory category;
  final String? platform;
  final RestrictedFundStatus? restrictedStatus;
  final DateTime? expectedReturnAt;
  final bool includeInTotal;
  final String? note;

  AccountFundCategory get overviewCategory =>
      category == AccountFundCategory.custom
      ? AccountFundCategory.available
      : category;
}

enum ReceivableType { reimbursement, refund, lend, customer, other }

extension ReceivableTypeLabel on ReceivableType {
  String get label => switch (this) {
    ReceivableType.reimbursement => '报销',
    ReceivableType.refund => '退款',
    ReceivableType.lend => '借出',
    ReceivableType.customer => '客户应收',
    ReceivableType.other => '其他',
  };
}

enum ReceivableStatus { pending, partial, completed, writtenOff, overdue }

extension ReceivableStatusLabel on ReceivableStatus {
  String get label => switch (this) {
    ReceivableStatus.pending => '待回收',
    ReceivableStatus.partial => '部分回收',
    ReceivableStatus.completed => '已完成',
    ReceivableStatus.writtenOff => '已核销',
    ReceivableStatus.overdue => '逾期',
  };
}

class Receivable {
  const Receivable({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.counterparty,
    required this.totalAmount,
    required this.receivedAmount,
    required this.occurredAt,
    required this.status,
    required this.businessStatus,
    required this.createdAt,
    required this.updatedAt,
    this.expectedAt,
    this.reminderAt,
    this.remark,
    this.sourceTransactionId,
  });

  final String id;
  final String bookId;
  final String name;
  final ReceivableType type;
  final String counterparty;
  final double totalAmount;
  final double receivedAmount;
  final DateTime occurredAt;
  final DateTime? expectedAt;
  final DateTime? reminderAt;
  final ReceivableStatus status;
  final String businessStatus;
  final String? remark;
  final String? sourceTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get remainingAmount => status == ReceivableStatus.writtenOff
      ? 0
      : (totalAmount - receivedAmount).clamp(0, totalAmount).toDouble();

  ReceivableStatus get effectiveStatus {
    if (status == ReceivableStatus.completed ||
        status == ReceivableStatus.writtenOff) {
      return status;
    }
    final due = expectedAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = due == null ? null : DateTime(due.year, due.month, due.day);
    if (dueDay != null &&
        dueDay.isBefore(today) &&
        remainingAmount > 0) {
      return ReceivableStatus.overdue;
    }
    return status;
  }

  bool get isTransactionProjection => sourceTransactionId != null;

  String get visibleStatus =>
      effectiveStatus == ReceivableStatus.overdue
      ? ReceivableStatus.overdue.label
      : (businessStatus.trim().isEmpty ? status.label : businessStatus.trim());
}

class ReceivableEvent {
  const ReceivableEvent({
    required this.id,
    required this.receivableId,
    required this.eventType,
    required this.title,
    required this.createdAt,
    this.description,
    this.amount,
  });

  final String id;
  final String receivableId;
  final String eventType;
  final String title;
  final String? description;
  final DateTime createdAt;
  final double? amount;
}
