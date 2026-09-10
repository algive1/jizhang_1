import '../../../core/utils/entity_id.dart';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_seeder.dart';
import '../../../core/models/family.dart';
import '../../../core/models/transaction_record.dart';
import '../../books/data/book_repository.dart';
import '../../intelligence/application/transaction_intelligence_service.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../transactions/data/transactions_repository.dart';

class QuickBookkeepingRequest {
  const QuickBookkeepingRequest({
    required this.type,
    required this.amount,
    this.currency = 'CNY',
    required this.accountId,
    this.transactionId,
    this.bookId,
    required this.occurredAt,
    this.destinationAccountId,
    this.categoryId,
    this.subcategoryId,
    this.categoryName,
    this.merchant,
    this.note,
    this.isPlanned = false,
    this.isOneTime = true,
    this.isRecurring = false,
    this.isLargeTransaction = false,
    this.tags = const [],
    this.attachmentPaths = const [],
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
  final String? destinationAccountId;
  final String? categoryId;
  final String? subcategoryId;
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
  });

  static const lastAccountKey = 'last_used_account_id';

  final TransactionRepository _transactions;
  final AppSettingsRepository _settings;
  final TransactionIntelligenceService? intelligence;
  final String Function()? activeBookId;

  Future<TransactionRecord> save(QuickBookkeepingRequest request) async {
    return (await saveAll([request])).single;
  }

  Future<TransactionRecord> update(
    TransactionRecord existing,
    QuickBookkeepingRequest request,
  ) async {
    _validate(request);
    final updated = _toRecord(request, DateTime.now(), existing: existing);
    return _transactions.update(updated);
  }

  Future<List<TransactionRecord>> saveAll(
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
    return saved;
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
    if (existing == null) {
      if (request.tags.isNotEmpty) metadata['tags'] = request.tags;
      if (request.attachmentPaths.isNotEmpty) {
        metadata['attachments'] = request.attachmentPaths;
      }
      metadata.addAll(request.metadata);
    } else {
      metadata['tags'] = request.tags;
      metadata['attachments'] = request.attachmentPaths;
      metadata.addAll(request.metadata);
    }
    return TransactionRecord(
      id: existing?.id ?? request.transactionId ?? 'local-${newEntityId()}',
      bookId:
          existing?.bookId ??
          request.bookId ??
          (activeBookId?.call() ?? SeedIds.personalBook),
      userId: existing?.userId ?? SeedIds.localUser,
      type: request.type,
      amount: request.amount,
      currency: request.currency,
      categoryId: request.categoryId,
      subcategoryId: request.subcategoryId ?? existing?.subcategoryId,
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
    ref.watch(transactionRepositoryProvider),
    ref.watch(appSettingsRepositoryProvider),
    intelligence: ref.watch(transactionIntelligenceServiceProvider),
    activeBookId: () => ref.read(activeBookIdProvider),
  );
});
