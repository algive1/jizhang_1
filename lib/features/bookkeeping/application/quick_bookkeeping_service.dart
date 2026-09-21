import 'dart:async';

import '../../../core/utils/entity_id.dart';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/database_seeder.dart';
import '../../../core/diagnostics/operation_log.dart';
import '../../../core/analytics/product_analytics.dart';
import '../../../core/models/family.dart';
import '../../../core/models/book.dart';
import '../../../core/models/transaction_record.dart';
import '../../books/data/book_repository.dart';
import '../../intelligence/application/transaction_intelligence_service.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../transactions/data/transaction_attachment_repository.dart';
import '../../transactions/data/transactions_repository.dart';

class QuickBookkeepingRequest {
  const QuickBookkeepingRequest({
    required this.type,
    required this.amount,
    this.currency = 'CNY',
    required this.accountId,
    this.transactionId,
    this.bookId,
    this.payerUserId,
    required this.occurredAt,
    this.destinationAccountId,
    this.categoryId,
    this.subcategoryId,
    this.clearSubcategory = false,
    this.categoryName,
    this.merchant,
    this.note,
    this.isPlanned = false,
    this.isOneTime = true,
    this.isRecurring = false,
    this.isLargeTransaction = false,
    this.tags = const [],
    this.attachmentPaths = const [],
    this.relatedTransactionId,
    this.reimbursementStatus = ReimbursementStatus.none,
    this.reimbursementAmount,
    this.reimbursementDate,
    this.reimbursementNote,
    this.clearReimbursement = false,
    this.refundStatus = RefundStatus.none,
    this.refundAmount,
    this.clearRefund = false,
    this.source = TransactionSource.manual,
    this.userCorrected = false,
    this.metadata = const {},
  });

  final TransactionType type;
  final double amount;
  final String currency;
  final String accountId;
  final String? transactionId;
  final String? bookId;
  /// Shared-family attribution. Null means the current recorder.
  final String? payerUserId;
  final String? destinationAccountId;
  final String? categoryId;
  final String? subcategoryId;
  final bool clearSubcategory;
  final String? categoryName;
  final String? merchant;
  final String? note;
  final DateTime occurredAt;
  final bool isPlanned;
  final bool isOneTime;
  final bool isRecurring;
  final bool isLargeTransaction;
  final List<String> tags;
  final List<String> attachmentPaths;
  final String? relatedTransactionId;
  final ReimbursementStatus reimbursementStatus;
  final double? reimbursementAmount;
  final DateTime? reimbursementDate;
  final String? reimbursementNote;
  final bool clearReimbursement;
  final RefundStatus refundStatus;
  final double? refundAmount;
  final bool clearRefund;
  final TransactionSource source;
  final bool userCorrected;
  final Map<String, Object?> metadata;
}

/// The ledger transaction and account balance have already committed.
/// Secondary local writes may still need repair, so callers must not retry the
/// bookkeeping request automatically.
class BookkeepingCommittedException extends StateError {
  BookkeepingCommittedException({
    required this.records,
    required this.cause,
    required this.stage,
    required this.stackTrace,
  }) : super('Bookkeeping committed; $stage failed: $cause');

  final List<TransactionRecord> records;
  final Object cause;
  final String stage;
  @override
  final StackTrace stackTrace;
}

class QuickBookkeepingService {
  QuickBookkeepingService(
    this._transactions,
    this._settings, {
    this.intelligence,
    this.activeBookId,
    this.attachments,
    this.diagnostics,
    this.analytics,
  });

  static const lastAccountKey = 'last_used_account_id';

  final TransactionRepository _transactions;
  final AppSettingsRepository _settings;
  final TransactionIntelligenceService? intelligence;
  final String Function()? activeBookId;
  final TransactionAttachmentRepository? attachments;
  final OperationLogService? diagnostics;
  final ProductAnalytics? analytics;

  Future<TransactionRecord> save(QuickBookkeepingRequest request) async {
    return (await saveAll([request])).single;
  }

  Future<TransactionRecord> update(
    TransactionRecord existing,
    QuickBookkeepingRequest request,
  ) async {
    try {
      return await _update(existing, request);
    } on Object catch (error) {
      unawaited(
        diagnostics?.record(
          kind: 'bookkeeping_failed',
          level: 'error',
          message: error.runtimeType.toString(),
          data: {'operation': 'update', 'source': request.source.name},
        ),
      );
      rethrow;
    }
  }

  Future<List<TransactionRecord>> saveAll(
    List<QuickBookkeepingRequest> requests,
  ) async {
    try {
      return await _saveAll(requests);
    } on Object catch (error) {
      unawaited(
        diagnostics?.record(
          kind: 'bookkeeping_failed',
          level: 'error',
          message: error.runtimeType.toString(),
          data: {
            'operation': 'create',
            'count': requests.length,
            if (requests.isNotEmpty) 'source': requests.first.source.name,
          },
        ),
      );
      rethrow;
    }
  }

  Future<TransactionRecord> _update(
    TransactionRecord existing,
    QuickBookkeepingRequest request,
  ) async {
    _validate(request);
    final linkedReimbursements = await _linkedReimbursements(existing.id);
    if (linkedReimbursements.isNotEmpty) {
      if (request.clearReimbursement ||
          (request.reimbursementStatus != ReimbursementStatus.none &&
              request.reimbursementStatus != existing.reimbursementStatus)) {
        throw ArgumentError('已有报销回款，请在报销回款流水中编辑或撤销');
      }
      final paidCents = linkedReimbursements.fold<int>(
        0,
        (sum, item) => sum + (item.amount * 100).round(),
      );
      if ((request.amount * 100).round() < paidCents) {
        throw ArgumentError('原消费金额不能低于已到账的报销金额');
      }
    }
    var updated = _toRecord(request, DateTime.now(), existing: existing);
    if (linkedReimbursements.isNotEmpty) {
      final paidCents = linkedReimbursements.fold<int>(
        0,
        (sum, item) => sum + (item.amount * 100).round(),
      );
      updated = updated.copyWith(
        reimbursementStatus: paidCents >= (updated.amount * 100).round()
            ? ReimbursementStatus.reimbursed
            : ReimbursementStatus.partial,
        reimbursementAmount: paidCents / 100,
        reimbursementDate: existing.reimbursementDate,
        reimbursementNote: existing.reimbursementNote,
      );
    }
    final saved = await _transactions.update(updated);
    try {
      await _persistAttachments([saved], [request]);
    } on Object catch (error, stack) {
      throw BookkeepingCommittedException(
        records: [saved],
        cause: error,
        stage: 'attachment persistence',
        stackTrace: stack,
      );
    }
    unawaited(
      diagnostics?.record(
        kind: 'bookkeeping_updated',
        data: {'source': request.source.name},
      ),
    );
    unawaited(
      analytics?.track(
        'bookkeeping_updated',
        properties: {'source': request.source.name},
      ),
    );
    return saved;
  }

  Future<List<TransactionRecord>> _linkedReimbursements(
    String transactionId,
  ) async {
    return (await _transactions.getAll())
        .where(
          (item) =>
              item.deletedAt == null &&
              item.type == TransactionType.reimbursement &&
              item.relatedTransactionId == transactionId,
        )
        .toList(growable: false);
  }

  Future<List<TransactionRecord>> _saveAll(
    List<QuickBookkeepingRequest> requests,
  ) async {
    if (requests.isEmpty) return const [];
    for (final request in requests) {
      _validate(request);
    }
    final baseTime = DateTime.now();
    final records = [
      for (var index = 0; index < requests.length; index++)
        _toRecord(requests[index], baseTime.add(Duration(microseconds: index))),
    ];
    final saved = await _transactions.createAll(records);
    Object? firstError;
    StackTrace? firstStack;
    try {
      await _settings.set(
        accountSettingKey(saved.last.bookId),
        requests.last.accountId,
      );
    } on Object catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    }
    try {
      await _persistAttachments(saved, requests);
    } on Object catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    }
    try {
      await _postProcess(saved);
    } on Object catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    }
    final secondaryError = firstError;
    if (secondaryError != null) {
      throw BookkeepingCommittedException(
        records: saved,
        cause: secondaryError,
        stage: 'secondary local processing',
        stackTrace: firstStack ?? StackTrace.current,
      );
    }
    unawaited(
      diagnostics?.record(
        kind: 'bookkeeping_saved',
        data: {'count': saved.length, 'source': requests.first.source.name},
      ),
    );
    unawaited(
      analytics?.track(
        'bookkeeping_saved',
        properties: {
          'count': saved.length,
          'source': requests.first.source.name,
        },
      ),
    );
    return saved;
  }

  Future<void> _persistAttachments(
    List<TransactionRecord> records,
    List<QuickBookkeepingRequest> requests,
  ) async {
    final attachments = this.attachments;
    if (attachments == null) return;
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      await attachments.replaceForTransaction(
        transactionId: record.id,
        bookId: record.bookId,
        paths: requests[index].attachmentPaths,
      );
    }
  }

  Future<void> _postProcess(List<TransactionRecord> saved) async {
    final intelligence = this.intelligence;
    if (intelligence == null) return;
    for (final transaction in saved) {
      await intelligence.classifyAndApply(transaction.id);
      await intelligence.inspectExisting(transaction.id);
    }
  }

  void _validate(QuickBookkeepingRequest request) {
    if (!request.amount.isFinite || request.amount <= 0) {
      throw ArgumentError.value(request.amount, 'amount', 'must be > 0');
    }
    if (request.isOneTime && request.isRecurring) {
      throw ArgumentError('A transaction cannot be one-time and recurring');
    }
    if (request.type == TransactionType.transfer) {
      final destination = request.destinationAccountId;
      if (destination == null || destination == request.accountId) {
        throw ArgumentError('内部转账需要两个不同的转出/转入账户');
      }
    }
    if (request.reimbursementAmount != null &&
        (!request.reimbursementAmount!.isFinite ||
            request.reimbursementAmount! <= 0 ||
            request.reimbursementAmount! > request.amount)) {
      throw ArgumentError('报销金额必须大于 0 且不超过原流水金额');
    }
    if (request.refundAmount != null &&
        (!request.refundAmount!.isFinite ||
            request.refundAmount! <= 0 ||
            request.refundAmount! > request.amount)) {
      throw ArgumentError('退款金额必须大于 0 且不超过原流水金额');
    }
  }

  TransactionRecord _toRecord(
    QuickBookkeepingRequest request,
    DateTime now, {
    TransactionRecord? existing,
  }) {
    final merchant = request.merchant?.trim();
    final note = request.note?.trim();
    final metadata = <String, Object?>{
      ..._existingMetadata(existing?.metadataJson),
    };
    if (attachments != null) metadata.remove('attachments');
    if (existing == null) {
      if (request.tags.isNotEmpty) metadata['tags'] = request.tags;
      if (attachments == null && request.attachmentPaths.isNotEmpty) {
        metadata['attachments'] = request.attachmentPaths;
      }
      metadata.addAll(request.metadata);
    } else {
      metadata['tags'] = request.tags;
      if (attachments == null) {
        metadata['attachments'] = request.attachmentPaths;
      }
      metadata.addAll(request.metadata);
    }
    final reimbursementStatus =
        request.reimbursementStatus == ReimbursementStatus.none &&
            existing != null &&
            !request.clearReimbursement
        ? existing.reimbursementStatus
        : request.reimbursementStatus;
    final refundStatus =
        request.refundStatus == RefundStatus.none &&
            existing != null &&
            !request.clearRefund
        ? existing.refundStatus
        : request.refundStatus;
    return TransactionRecord(
      id: existing?.id ?? request.transactionId ?? 'local-${newEntityId()}',
      bookId:
          existing?.bookId ??
          request.bookId ??
          (activeBookId?.call() ?? SeedIds.personalBook),
      userId: request.payerUserId ?? existing?.userId ?? SeedIds.localUser,
      type: request.type,
      amount: request.amount,
      currency: request.currency,
      categoryId: request.categoryId,
      subcategoryId: request.clearSubcategory
          ? null
          : request.subcategoryId ??
                (request.categoryId == existing?.categoryId
                    ? existing?.subcategoryId
                    : null),
      categoryName: request.categoryName,
      accountId: request.accountId,
      destinationAccountId: request.destinationAccountId,
      merchant: merchant?.isEmpty == true ? null : merchant,
      note: note?.isEmpty == true ? null : note,
      occurredAt: request.occurredAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      deletedAt: existing?.deletedAt,
      isRecurring: request.isRecurring,
      isOneTime: request.isOneTime,
      isLargeTransaction:
          request.isLargeTransaction || (existing?.isLargeTransaction ?? false),
      isPlanned: request.isPlanned,
      source: existing?.source ?? request.source,
      aiConfidence: existing?.aiConfidence,
      userCorrected: existing?.userCorrected == true || request.userCorrected,
      syncStatus: existing?.syncStatus ?? SyncStatus.localOnly,
      deviceId: existing?.deviceId,
      originalTransactionId: existing?.originalTransactionId,
      relatedTransactionId:
          request.relatedTransactionId ?? existing?.relatedTransactionId,
      reimbursementStatus: reimbursementStatus,
      reimbursementAmount: reimbursementStatus == ReimbursementStatus.none
          ? null
          : request.reimbursementAmount ?? existing?.reimbursementAmount,
      reimbursementDate: reimbursementStatus == ReimbursementStatus.none
          ? null
          : request.reimbursementDate ?? existing?.reimbursementDate,
      reimbursementNote: reimbursementStatus == ReimbursementStatus.none
          ? null
          : request.reimbursementNote ?? existing?.reimbursementNote,
      refundStatus: refundStatus,
      refundAmount: refundStatus == RefundStatus.none
          ? null
          : request.refundAmount ?? existing?.refundAmount,
      metadataJson: metadata.isEmpty
          ? existing?.metadataJson
          : jsonEncode(metadata),
      duplicateConfidence: existing?.duplicateConfidence,
      visibility: existing?.visibility ?? TransactionVisibility.private,
      createdBy: existing?.createdBy ?? SeedIds.localUser,
      updatedBy: SeedIds.localUser,
      version: (existing?.version ?? 0) + 1,
    );
  }

  Map<String, Object?> _existingMetadata(String? value) {
    if (value == null || value.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map((key, item) => MapEntry(key.toString(), item));
      }
    } on Object {
      // Preserve the original string below when it is not our JSON shape.
    }
    return {'_legacyMetadata': value};
  }

  static String accountSettingKey(String bookId) =>
      bookId == SeedIds.personalBook
      ? lastAccountKey
      : '$lastAccountKey.$bookId';
  Future<String?> getLastAccountId() => _settings.get(
    accountSettingKey(activeBookId?.call() ?? SeedIds.personalBook),
  );
}

final quickBookkeepingServiceProvider = Provider<QuickBookkeepingService>((
  ref,
) {
  return QuickBookkeepingService(
    // The form may explicitly target a different ledger than the global
    // browsing ledger. The request's bookId remains validated by the
    // transaction repository against its referenced accounts/categories.
    DriftTransactionRepository(
      ref.watch(databaseProvider),
      accountBookIdForBook: (bookId) =>
          (ref.watch(booksProvider).value ?? const <LedgerBook>[])
              .where((book) => book.id == bookId)
              .firstOrNull
              ?.assetBookId,
    ),
    ref.watch(appSettingsRepositoryProvider),
    intelligence: ref.watch(transactionIntelligenceServiceProvider),
    activeBookId: () => ref.read(activeBookIdProvider),
    attachments: ref.watch(transactionAttachmentRepositoryProvider),
    diagnostics: ref.watch(operationLogServiceProvider),
    analytics: ref.watch(productAnalyticsProvider),
  );
});
