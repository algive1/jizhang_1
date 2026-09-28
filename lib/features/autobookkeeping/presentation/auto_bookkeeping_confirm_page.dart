import '../../../core/widgets/app_form.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/account.dart';
import '../../../core/models/book.dart';
import '../../../core/models/category.dart';
import '../../../core/models/recurring_bill.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../bookkeeping/presentation/components/category_grid.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../../../core/platform/bookkeeping_feedback.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../auto_bookkeeping_pending.dart';
import '../auto_bookkeeping_learning.dart';
import '../auto_bookkeeping_refund_matcher.dart';
import '../auto_bookkeeping_transfer_resolver.dart';
import '../../transactions/data/refund_service.dart';
import '../../transactions/data/transaction_attachment_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../recurring/data/recurring_bill_repository.dart';
import '../../recurring/application/recurring_bill_notification_service.dart';
import '../../notifications/application/payment_notification_service.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../auto_bookkeeping_logs.dart';

class AutoBookkeepingConfirmPage extends ConsumerStatefulWidget {
  const AutoBookkeepingConfirmPage({
    super.key,
    this.overlayMode = false,
    this.onReady,
  });

  final bool overlayMode;
  final VoidCallback? onReady;

  @override
  ConsumerState<AutoBookkeepingConfirmPage> createState() =>
      _AutoBookkeepingConfirmPageState();
}

class _AutoBookkeepingConfirmPageState
    extends ConsumerState<AutoBookkeepingConfirmPage> {
  PendingAutoBookkeepingCandidate? _candidate;
  List<LedgerBook>? _overlayBooks;
  List<Account>? _overlayAccounts;
  List<Category>? _overlayCategories;
  String? _bookId;
  String? _accountId;
  String? _categoryId;
  String? _subcategoryId;
  String? _destinationAccountId;
  TransactionType? _overlayTransactionType;
  int? _editedAmountInCents;
  String? _editedNote;
  DateTime? _editedOccurredAt;
  String? _message;
  AutoBookkeepingRecommendation? _recommendation;
  TransactionRecord? _matchedRefundOriginal;
  AutoBookkeepingTransferRecommendation? _transferRecommendation;
  bool _internalTransfer = false;
  bool _rememberForMerchant = true;
  bool _keepScreenshot = true;
  bool _loading = true;
  bool _saving = false;
  bool _closing = false;

  static const _nativeReviewChannel = MethodChannel(
    'jizhang/autobookkeeping_native_review',
  );

  Future<void> _record(String stage, Map<String, Object?> detail) =>
      const AutoBookkeepingLogsBridge().recordDetailed(
        stage,
        jsonEncode(detail),
      );

  Map<String, Object?> _candidateLog(
    PendingAutoBookkeepingCandidate candidate,
  ) => {
    'fingerprint': candidate.fingerprint,
    'amountInCents': candidate.amountInCents,
    'merchant': candidate.merchant,
    'paymentMethod': candidate.paymentMethod,
    'timestamp': candidate.timestamp.toIso8601String(),
    'sourceApp': candidate.sourceApp,
    'scene': candidate.scene,
    'transactionType': candidate.transactionType,
    'orderId': candidate.orderId,
    'note': candidate.note,
    'identifierSuffix': candidate.identifierSuffix,
    'targetIdentifierSuffix': candidate.targetIdentifierSuffix,
    'targetAccountHint': candidate.targetAccountHint,
  };

  @override
  void initState() {
    super.initState();
    if (widget.overlayMode) {
      _nativeReviewChannel.setMethodCallHandler(_handleNativeReviewCall);
    }
    unawaited(_loadCandidateWithTimeout());
  }

  @override
  void dispose() {
    if (widget.overlayMode) {
      _nativeReviewChannel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  String? _nonBlank(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<Object?> _handleNativeReviewCall(MethodCall call) async {
    if (call.method != 'submit') return null;
    final raw = call.arguments;
    if (raw is! Map) {
      return const <String, Object?>{
        'success': false,
        'message': '原生确认参数无效',
      };
    }
    final success = await _saveNativeReview(Map<Object?, Object?>.from(raw));
    return <String, Object?>{
      'success': success,
      'message': _message,
    };
  }

  Future<bool> _saveNativeReview(Map<Object?, Object?> raw) async {
    final candidate = _candidate;
    final books = _overlayBooks;
    if (candidate == null || books == null || books.isEmpty || _saving) {
      return false;
    }

    final requestedBookId = raw['bookId']?.toString();
    final bookId = requestedBookId != null &&
            books.any((book) => book.id == requestedBookId)
        ? requestedBookId
        : (_bookId ?? books.first.id);
    final selectedBook = books.where((book) => book.id == bookId).firstOrNull;
    if (selectedBook == null) return false;

    final accounts =
        bookId == _bookId && _overlayAccounts != null
            ? _overlayAccounts!
            : await DriftAccountRepository(
                ref.read(databaseProvider),
                bookId: selectedBook.assetBookId,
              ).getActive();
    final categories =
        bookId == _bookId && _overlayCategories != null
            ? _overlayCategories!
            : await DriftCategoryRepository(
                ref.read(databaseProvider),
                bookId: bookId,
              ).getActive();

    final typeName = raw['type']?.toString();
    final type = switch (typeName) {
      'income' => TransactionType.income,
      'refund' => TransactionType.refund,
      'reimbursement' => TransactionType.reimbursement,
      'transfer' => TransactionType.transfer,
      _ => TransactionType.expense,
    };
    final amount = raw['amountInCents'];
    final amountInCents = amount is num ? amount.toInt() : 0;
    if (amountInCents <= 0) {
      setState(() => _message = '请输入有效金额');
      return false;
    }

    final reimbursementName =
        raw['reimbursementStatus']?.toString() ?? 'none';
    final reimbursementStatus = ReimbursementStatus.values.firstWhere(
      (value) => value.name == reimbursementName,
      orElse: () => ReimbursementStatus.none,
    );
    final occurredAtRaw = raw['occurredAt'];
    final occurredAt = occurredAtRaw is num
        ? DateTime.fromMillisecondsSinceEpoch(occurredAtRaw.toInt())
        : candidate.timestamp;
    _keepScreenshot = raw['screenshotEnabled'] != false;

    final draft = QuickAddReviewDraft(
      bookId: bookId,
      type: type,
      amountInCents: amountInCents,
      note: raw['note']?.toString() ?? candidate.merchant,
      occurredAt: occurredAt,
      accounts: accounts,
      categories: categories,
      categoryId: _nonBlank(raw['categoryId']),
      accountId: _nonBlank(raw['accountId']),
      destinationAccountId:
          _nonBlank(raw['destinationAccountId']),
      subcategoryId: _nonBlank(raw['subcategoryId']),
      reimbursementStatus: reimbursementStatus,
      reimbursementNote: '',
      attachmentPaths: const <String>[],
      tags: const <String>[],
      payerUserId: null,
      recurringDraft: null,
      isPlanned: false,
      isOneTime: true,
      isRecurring: false,
    );
    return _saveOverlayDraft(draft);
  }

  Future<void> _syncNativeReview() async {
    if (!widget.overlayMode || !mounted) return;
    final candidate = _candidate;
    final books = _overlayBooks;
    final accounts = _overlayAccounts;
    final categories = _overlayCategories;
    if (candidate == null ||
        books == null ||
        accounts == null ||
        categories == null ||
        books.isEmpty) {
      return;
    }

    final selectedBookId = _bookId != null &&
            books.any((book) => book.id == _bookId)
        ? _bookId!
        : books.first.id;
    final resolvedType =
        _overlayTransactionType ?? _transactionTypeFor(candidate.transactionType);
    // A parser-level TRANSFER only becomes an internal account transfer after
    // the existing resolver finds strong evidence. Until then the established
    // behavior is to review/save it as an expense.
    final type =
        candidate.transactionType == 'TRANSFER' &&
            resolvedType == TransactionType.transfer &&
            !_internalTransfer
        ? TransactionType.expense
        : resolvedType;
    final categoryType = _categoryTypeFor(type);
    final roots = categories
        .where((item) => item.parentId == null && item.type == categoryType)
        .toList()
      ..sort((a, b) {
        bool isOther(Category item) =>
            item.id == 'expense-other' || item.name.trim().startsWith('其他');
        final aOther = isOther(a);
        final bOther = isOther(b);
        if (aOther != bOther) return aOther ? -1 : 1;
        return b.sortOrder.compareTo(a.sortOrder);
      });
    final children = categories
        .where((item) => item.parentId != null)
        .toList()
      ..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
    final selectedCategoryId = _validCategoryId(roots);
    final selectedAccountId = _validAccountId(accounts);
    final selectedDestinationAccountId = _validDestinationAccountId(
      accounts,
      sourceAccountId: selectedAccountId,
    );

    try {
      await _nativeReviewChannel.invokeMethod<void>('sync', {
        'selectedBookId': selectedBookId,
        'selectedAccountId': selectedAccountId,
        'selectedDestinationAccountId': selectedDestinationAccountId,
        'selectedCategoryId': selectedCategoryId,
        'selectedSubcategoryId': _subcategoryId,
        'transactionType': switch (type) {
          TransactionType.income => 'income',
          TransactionType.refund => 'refund',
          TransactionType.reimbursement => 'reimbursement',
          TransactionType.transfer => 'transfer',
          _ => 'expense',
        },
        'occurredAt': (_editedOccurredAt ?? candidate.timestamp)
            .millisecondsSinceEpoch,
        'screenshotEnabled':
            candidate.screenshotPath != null && _keepScreenshot,
        'books': [
          for (final book in books) {'id': book.id, 'label': book.name},
        ],
        'accounts': [
          for (final account in accounts)
            {
              'id': account.id,
              'label': account.displayName,
              'type': account.type.name,
            },
        ],
        'categories': [
          for (final category in <Category>[...roots, ...children])
            {
              'id': category.id,
              'label': category.name,
              'type': category.type.name,
              'parentId': category.parentId,
              'sortOrder': category.sortOrder,
            },
        ],
      });
    } on MissingPluginException {
      // Widget tests and non-Android hosts intentionally have no native overlay.
    }
  }

  Future<void> _loadCandidateWithTimeout() async {
    try {
      await _loadCandidate().timeout(const Duration(seconds: 7));
    } on TimeoutException {
      unawaited(
        _record('confirmation_candidate_load_timeout', {
          'overlayMode': widget.overlayMode,
        }),
      );
      if (!mounted || !_loading) return;
      setState(() {
        _loading = false;
        _message = '账本加载超时，请稍后从通知重新打开';
      });
    }
  }

  Future<void> _loadCandidate() async {
    try {
      final candidate = await ref
          .read(autoBookkeepingPendingBridgeProvider)
          .getPending();
      unawaited(
        _record('confirmation_candidate_loaded', {
          'overlayMode': widget.overlayMode,
          'candidate': candidate == null ? null : _candidateLog(candidate),
        }),
      );
      AutoBookkeepingRecommendation? recommendation;
      TransactionRecord? matchedRefundOriginal;
      AutoBookkeepingTransferRecommendation? transferRecommendation;
      List<LedgerBook>? overlayBooks;
      List<Account>? overlayAccounts;
      List<Category>? overlayCategories;
      String? sourceAccountId;
      String? resolvedBookId;
      if (candidate != null) {
        final fallbackBookId = ref.read(activeBookIdProvider);
        recommendation = await ref
            .read(autoBookkeepingLearningServiceProvider)
            .recommend(
              candidate: candidate,
              fallbackBookId: fallbackBookId,
              transactionType: _transactionTypeFor(candidate.transactionType),
            );
        final books = await ref.read(booksProvider.future);
        if (widget.overlayMode) overlayBooks = books;
        final requestedBookId = recommendation.bookId ?? fallbackBookId;
        final targetBookId = books.any((book) => book.id == requestedBookId)
            ? requestedBookId
            : books.any((book) => book.id == fallbackBookId)
            ? fallbackBookId
            : books.firstOrNull?.id;
        resolvedBookId = targetBookId;
        if (targetBookId != null) {
          matchedRefundOriginal = await ref
              .read(autoBookkeepingRefundMatcherProvider)
              .findOriginal(candidate: candidate, bookId: targetBookId);
          final selectedBook = books
              .where((book) => book.id == targetBookId)
              .firstOrNull;
          final accounts = widget.overlayMode
              ? await DriftAccountRepository(
                  ref.read(databaseProvider),
                  bookId: selectedBook?.assetBookId ?? targetBookId,
                ).getActive()
              : await ref.read(accountsByBookProvider(targetBookId).future);
          if (widget.overlayMode) {
            overlayAccounts = accounts;
            overlayCategories = await DriftCategoryRepository(
              ref.read(databaseProvider),
              bookId: targetBookId,
            ).getActive();
          }
          sourceAccountId =
              matchedRefundOriginal?.accountId ??
              _bestAccountId(
                accounts,
                candidate: candidate,
                preferredId: recommendation.accountId,
              );
          if (candidate.transactionType == 'TRANSFER') {
            transferRecommendation = await ref
                .read(autoBookkeepingTransferResolverProvider)
                .recommend(
                  candidate: candidate,
                  bookId: targetBookId,
                  accounts: accounts,
                  sourceAccountId: sourceAccountId,
                );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _candidate = candidate;
        _overlayBooks = overlayBooks;
        _overlayAccounts = overlayAccounts;
        _overlayCategories = overlayCategories;
        _recommendation = recommendation;
        _matchedRefundOriginal = matchedRefundOriginal;
        _transferRecommendation = transferRecommendation;
        _bookId = resolvedBookId;
        _accountId = sourceAccountId;
        _categoryId = recommendation?.categoryId;
        _subcategoryId = recommendation?.subcategoryId;
        _overlayTransactionType = candidate == null
            ? null
            : candidate.transactionType == 'TRANSFER'
            ? TransactionType.transfer
            : _transactionTypeFor(candidate.transactionType);
        _editedAmountInCents = null;
        _editedNote = null;
        _internalTransfer =
            transferRecommendation?.suggestsInternalTransfer == true;
        _destinationAccountId = transferRecommendation?.destinationAccountId;
        _loading = false;
      });
      if (widget.overlayMode && candidate != null) {
        unawaited(_syncNativeReview());
      }
      if (candidate != null && candidate.screenshotPath == null) {
        unawaited(_refreshScreenshot(candidate.fingerprint));
      }
      widget.onReady?.call();
    } on Object catch (error) {
      unawaited(
        _record('confirmation_candidate_load_failed', {
          'error': error.toString(),
        }),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = '无法读取待确认账单：$error';
      });
    }
  }

  Future<void> _refreshScreenshot(String fingerprint) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted || _saving || _closing) return;
      final refreshed = await ref
          .read(autoBookkeepingPendingBridgeProvider)
          .getPending();
      if (!mounted ||
          refreshed == null ||
          refreshed.fingerprint != fingerprint) {
        return;
      }
      if (refreshed.screenshotPath != null) {
        setState(() => _candidate = refreshed);
        if (widget.overlayMode) unawaited(_syncNativeReview());
        return;
      }
    }
  }

  Future<void> _completePending({
    bool keepScreenshot = false,
    String reason = 'user_dismissed',
    String? transactionId,
  }) async {
    if (_closing) return;
    _closing = true;
    try {
      await ref
          .read(autoBookkeepingPendingBridgeProvider)
          .complete(keepScreenshot: keepScreenshot);
      await _record('confirmation_completed', {
        'reason': reason,
        'transactionId': transactionId,
        'keepScreenshot': keepScreenshot,
        'candidate': _candidate == null ? null : _candidateLog(_candidate!),
      });
    } on Object catch (error) {
      await _record('confirmation_complete_failed', {
        'reason': reason,
        'transactionId': transactionId,
        'error': error.toString(),
      });
      rethrow;
    }
    // A second notification may have remained in the raw recovery queue while
    // this confirmation slot was occupied. Drain it immediately instead of
    // waiting for the next app resume.
    try {
      await ref
          .read(paymentNotificationAutoBookkeepingProvider)
          .processPending();
    } on Object {
      // Recovery remains best-effort; app startup/resume will retry again.
    }
  }

  Future<void> _close() async {
    await _completePending(reason: 'user_dismissed');
    if (!mounted) return;
    if (widget.overlayMode) {
      await _closeOverlayHost();
    } else {
      context.pop();
    }
  }

  Future<void> _syncRecurringNotification(RecurringBill bill) async {
    try {
      final scheduler = ref.read(recurringBillNotificationSchedulerProvider);
      if (bill.reminder) await scheduler.requestPermission();
      await scheduler.syncBill(bill);
    } on Object catch (error) {
      debugPrint('周期账单通知同步失败：$error');
    }
  }

  Future<bool> _save({
    required String bookId,
    required Account account,
    required Category? category,
    Account? destinationAccount,
    QuickAddReviewDraft? reviewDraft,
  }) async {
    final candidate = _candidate;
    if (candidate == null || _saving) return false;
    await _record('confirmation_save_started', {
      'candidate': _candidateLog(candidate),
      'bookId': bookId,
      'accountId': account.id,
      'categoryId': category?.id,
      'destinationAccountId': destinationAccount?.id,
      'amountInCents':
          reviewDraft?.amountInCents ??
          _editedAmountInCents ??
          candidate.amountInCents,
      'note': reviewDraft?.note ?? _editedNote ?? candidate.note,
      'overlayMode': widget.overlayMode,
    });
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final isTransferScene = reviewDraft != null
          ? candidate.transactionType == 'TRANSFER' ||
                reviewDraft.type == TransactionType.transfer
          : widget.overlayMode
          ? _overlayTransactionType == TransactionType.transfer
          : candidate.transactionType == 'TRANSFER';
      final finalTransactionType = reviewDraft != null
          ? reviewDraft.type
          : isTransferScene
          ? (_overlayTransactionType == TransactionType.transfer &&
                    _internalTransfer
                ? TransactionType.transfer
                : TransactionType.expense)
          : widget.overlayMode
          ? (_overlayTransactionType ??
                _transactionTypeFor(candidate.transactionType))
          : _transactionTypeFor(candidate.transactionType);
      final amountInCents =
          reviewDraft?.amountInCents ??
          _editedAmountInCents ??
          candidate.amountInCents;
      final note = reviewDraft?.note ?? _editedNote ?? candidate.note;
      final occurredAt =
          reviewDraft?.occurredAt ?? _editedOccurredAt ?? candidate.timestamp;
      final subcategoryId = reviewDraft?.subcategoryId ?? _subcategoryId;
      final recurringDraft = reviewDraft?.recurringDraft;
      if (finalTransactionType == TransactionType.transfer) {
        if (destinationAccount == null || destinationAccount.id == account.id) {
          throw ArgumentError('内部转账需要选择不同的转入账户');
        }
      } else if (category == null) {
        throw ArgumentError('请选择分类');
      }

      final metadata = <String, Object?>{
        'paymentChannel': _paymentChannel(candidate),
        if (recurringDraft != null) 'recurring_bill_id': recurringDraft.id,
        if (candidate.orderId != null) 'orderId': candidate.orderId,
        if (candidate.identifierSuffix != null)
          'cardLastFour': candidate.identifierSuffix,
        'autobookkeeping': {
          'fingerprint': candidate.fingerprint,
          'sourceApp': candidate.sourceApp,
          'scene': candidate.scene,
          'paymentMethod': candidate.paymentMethod,
          'transactionType': candidate.transactionType,
          'confirmedTransactionType': finalTransactionType.name,
          if (candidate.targetIdentifierSuffix != null)
            'targetIdentifierSuffix': candidate.targetIdentifierSuffix,
          if (candidate.targetAccountHint != null)
            'targetAccountHint': candidate.targetAccountHint,
          if (candidate.orderId != null) 'orderId': candidate.orderId,
          if (candidate.identifierSuffix != null)
            'identifierSuffix': candidate.identifierSuffix,
          if (candidate.originalAmountInCents != null)
            'originalAmountInCents': candidate.originalAmountInCents,
          if (candidate.discountAmountInCents != null)
            'discountAmountInCents': candidate.discountAmountInCents,
          'confirmedIn': 'autobookkeeping_confirm_page',
        },
      };
      final screenshotPath = _keepScreenshot && candidate.screenshotPath != null
          ? candidate.screenshotPath
          : null;
      final transactionType = finalTransactionType;
      final confirmedCandidate = _candidateWithType(candidate, transactionType);
      final matchedRefund =
          transactionType == TransactionType.refund &&
              _matchedRefundOriginal?.bookId == bookId
          ? _matchedRefundOriginal
          : null;
      TransactionRecord saved;
      String? committedWarning;
      if (matchedRefund != null) {
        saved = await RefundService(ref.read(databaseProvider), bookId: bookId)
            .register(
              original: matchedRefund,
              amount: amountInCents / 100,
              category: category!,
              occurredAt: occurredAt,
              transactionId: 'auto-${candidate.fingerprint}',
              note: note ?? '自动识别退款：${candidate.merchant}',
              metadataJson: jsonEncode(metadata),
              source: TransactionSource.auto,
            );
      } else {
        try {
          final request = QuickBookkeepingRequest(
            transactionId: 'auto-${candidate.fingerprint}',
            bookId: bookId,
            type: transactionType,
            amount: amountInCents / 100,
            currency: account.currency,
            accountId: account.id,
            destinationAccountId: transactionType == TransactionType.transfer
                ? destinationAccount!.id
                : null,
            categoryId: category?.id,
            subcategoryId: subcategoryId,
            categoryName: category?.name,
            merchant: candidate.merchant,
            note: note,
            occurredAt: occurredAt,
            payerUserId: reviewDraft?.payerUserId,
            isPlanned: reviewDraft?.isPlanned ?? false,
            isOneTime: reviewDraft?.isOneTime ?? true,
            isRecurring: reviewDraft?.isRecurring ?? false,
            tags: reviewDraft?.tags ?? const <String>[],
            attachmentPaths: reviewDraft?.attachmentPaths ?? const <String>[],
            reimbursementStatus:
                reviewDraft?.reimbursementStatus ?? ReimbursementStatus.none,
            reimbursementAmount:
                reviewDraft == null ||
                    reviewDraft.reimbursementStatus == ReimbursementStatus.none
                ? null
                : amountInCents / 100,
            reimbursementNote: reviewDraft?.reimbursementNote,
            source: TransactionSource.auto,
            userCorrected: true,
            metadata: metadata,
          );
          if (recurringDraft == null) {
            saved = await ref
                .read(quickBookkeepingServiceProvider)
                .save(request);
          } else {
            if (transactionType != TransactionType.expense &&
                transactionType != TransactionType.income) {
              throw ArgumentError('周期账单仅支持收入和支出');
            }
            var next = recurringDraft.firstOccurrence();
            final currentDay = DateTime(
              occurredAt.year,
              occurredAt.month,
              occurredAt.day,
            );
            while (!next.isAfter(currentDay)) {
              next = recurringDraft.nextOccurrence(next);
            }
            final ended =
                (recurringDraft.repeatCount != null &&
                    recurringDraft.repeatCount! <= 1) ||
                (recurringDraft.endDate != null &&
                    next.isAfter(recurringDraft.endDate!));
            final recurringBill = RecurringBill(
              id: recurringDraft.id,
              bookId: bookId,
              name: candidate.merchant.trim().isNotEmpty
                  ? candidate.merchant.trim()
                  : category?.name ?? '周期账单',
              type: transactionType == TransactionType.income
                  ? RecurringBillType.income
                  : RecurringBillType.other,
              amount: request.amount,
              cycle: recurringDraft.cycle,
              startDate: recurringDraft.startDate,
              endDate: recurringDraft.endDate,
              nextDate: next,
              accountId: account.id,
              categoryId: category?.id,
              subcategoryId: subcategoryId,
              interval: recurringDraft.interval,
              weekday: recurringDraft.weekday,
              dayOfMonth: recurringDraft.dayOfMonth,
              month: recurringDraft.month,
              repeatCount: recurringDraft.repeatCount,
              completedCount: 1,
              reminderDays: recurringDraft.reminderDays,
              reminder: recurringDraft.reminder,
              autoRecord: recurringDraft.autoRecord,
              customIntervalDays: recurringDraft.customIntervalDays,
              status: ended
                  ? RecurringBillStatus.ended
                  : RecurringBillStatus.active,
              createdAt: recurringDraft.createdAt,
              updatedAt: DateTime.now(),
            );
            final database = ref.read(databaseProvider);
            saved = await RecurringBillExecutionService(
              database,
              ref.read(quickBookkeepingServiceProvider),
              ref.read(transactionRepositoryProvider),
              DriftRecurringBillRepository(database, bookId: bookId),
            ).createWithInitial(recurringBill, request);
            unawaited(_syncRecurringNotification(recurringBill));
            ref.invalidate(recurringBillsAllProvider);
          }
        } on BookkeepingCommittedException catch (error) {
          if (error.records.length != 1) rethrow;
          saved = error.records.single;
          committedWarning = error.stage;
        }
      }

      var screenshotWarning = false;
      var attachmentWarning = false;
      String? promotedPath;
      if (screenshotPath != null) {
        try {
          promotedPath = await ref
              .read(autoBookkeepingPendingBridgeProvider)
              .promoteScreenshot(screenshotPath);
          screenshotWarning = promotedPath == null;
        } on Object {
          screenshotWarning = true;
        }
      }
      final savedAttachmentPaths = <String>[
        ...?reviewDraft?.attachmentPaths,
        ?promotedPath,
      ];
      if (savedAttachmentPaths.isNotEmpty) {
        try {
          await ref
              .read(transactionAttachmentRepositoryProvider)
              .replaceForTransaction(
                transactionId: saved.id,
                bookId: saved.bookId,
                paths: savedAttachmentPaths,
              );
        } on Object {
          screenshotWarning = screenshotWarning || screenshotPath != null;
          attachmentWarning = reviewDraft?.attachmentPaths.isNotEmpty ?? false;
          if (promotedPath != null) {
            try {
              final promotedFile = File(promotedPath);
              if (await promotedFile.exists()) await promotedFile.delete();
            } on Object {
              // Best-effort cleanup only; bookkeeping already succeeded.
            }
          }
        }
      }

      try {
        if (isTransferScene) {
          await ref
              .read(autoBookkeepingTransferResolverProvider)
              .rememberDecision(
                candidate: confirmedCandidate,
                bookId: bookId,
                internalTransfer: transactionType == TransactionType.transfer,
                destinationAccountId: saved.destinationAccountId,
                remember: _rememberForMerchant,
              );
        }
        if (transactionType != TransactionType.transfer && category != null) {
          await ref
              .read(autoBookkeepingLearningServiceProvider)
              .remember(
                transactionId: saved.id,
                candidate: confirmedCandidate,
                bookId: bookId,
                accountId: saved.accountId,
                categoryId: category.id,
                subcategoryId: _subcategoryId,
                rememberForMerchant: _rememberForMerchant,
              );
        }
      } on Object {
        // Learning is a secondary local enhancement. A successful transaction
        // must never be rolled back or shown as failed because memory could
        // not be updated.
      }
      await _record('confirmation_save_succeeded', {
        'transactionId': saved.id,
        'bookId': saved.bookId,
        'accountId': saved.accountId,
        'amount': saved.amount,
        'merchant': saved.merchant,
        'type': saved.type.name,
        'committedWarning': committedWarning,
        'screenshotWarning': screenshotWarning,
        'attachmentWarning': attachmentWarning,
      });
      await _completePending(reason: 'saved', transactionId: saved.id);
      await BookkeepingFeedback.notifySuccess(count: 1);
      if (!mounted) return true;
      if (widget.overlayMode) {
        await _closeOverlayHost();
        return true;
      }
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      final warningParts = <String>[
        if (committedWarning != null) '部分本地增强处理未完成',
        if (screenshotWarning) '支付截图未能附加',
        if (attachmentWarning) '附件未能附加',
      ];
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            warningParts.isEmpty
                ? '已保存到本地账本'
                : '流水已保存，但${warningParts.join('、')}',
          ),
        ),
      );
      return true;
    } on Object catch (error) {
      await _record('confirmation_save_failed', {
        'candidate': _candidate == null ? null : _candidateLog(_candidate!),
        'error': error.toString(),
      });
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _message = '保存失败：$error';
      });
      return false;
    }
  }

  Future<void> _closeOverlayHost({bool preservePending = false}) async {
    try {
      await const MethodChannel('jizhang/autobookkeeping_overlay')
          .invokeMethod<void>('close', {'preservePending': preservePending});
    } on MissingPluginException {
      await SystemNavigator.pop();
    }
  }

  Future<void> _dismissLoadingOverlay() async {
    unawaited(
      _record('confirmation_loading_dismissed', {
        'overlayMode': widget.overlayMode,
      }),
    );
    await _closeOverlayHost(preservePending: true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.overlayMode) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_close());
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            top: false,
            left: false,
            right: false,
            minimum: const EdgeInsets.only(bottom: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final panelHeight = constraints.maxHeight * .60;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                    child: SizedBox(
                      key: const ValueKey('autobookkeeping-overlay-panel'),
                      width: double.infinity,
                      height: panelHeight,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 12,
                        shadowColor: Colors.black.withValues(alpha: .22),
                        clipBehavior: Clip.antiAlias,
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 14,
                              child: Center(
                                child: Container(
                                  width: 34,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: .18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _loading
                                  ? Stack(
                                      children: [
                                        const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 8,
                                          child: IconButton(
                                            key: const ValueKey(
                                              'autobookkeeping-loading-close',
                                            ),
                                            tooltip: '关闭',
                                            onPressed: () => unawaited(
                                              _dismissLoadingOverlay(),
                                            ),
                                            icon: const Icon(Icons.close),
                                          ),
                                        ),
                                      ],
                                    )
                                  : _buildOverlayContent(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(context),
      ),
    );
  }

  Widget _buildOverlayContent(BuildContext context) {
    final candidate = _candidate;
    if (candidate == null) {
      return _EmptyState(message: _message ?? '没有待确认的交易记录', onClose: _close);
    }
    final books = _overlayBooks;
    if (books == null) return const Center(child: CircularProgressIndicator());
    if (books.isEmpty) {
      return _EmptyState(message: '当前没有可用账本', onClose: _close);
    }
    final accounts = _overlayAccounts;
    final categories = _overlayCategories;
    if (accounts == null || categories == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeBookId = ref.watch(activeBookIdProvider);
    final requestedBookId = _bookId ?? activeBookId;
    final selectedBookId = books.any((book) => book.id == requestedBookId)
        ? requestedBookId
        : books.first.id;
    final selectedType =
        _overlayTransactionType ??
        _transactionTypeFor(candidate.transactionType);
    final initialType =
        selectedType == TransactionType.transfer && !_internalTransfer
        ? TransactionType.expense
        : selectedType;
    final categoryType = _categoryTypeFor(initialType);
    final selectableCategories = categories
        .where((item) => item.type == categoryType && item.parentId == null)
        .toList(growable: false);

    return QuickAddSheet(
      key: const ValueKey('autobookkeeping-quick-add-review'),
      reviewMode: true,
      initialType: initialType,
      initialOccurredAt: candidate.timestamp,
      initialBookId: selectedBookId,
      initialAmountInCents: _editedAmountInCents ?? candidate.amountInCents,
      initialNote: candidate.merchant,
      initialCategoryId: _validCategoryId(selectableCategories),
      initialSubcategoryId: _subcategoryId,
      initialAccountId: _validAccountId(accounts),
      initialDestinationAccountId: _validDestinationAccountId(
        accounts,
        sourceAccountId: _validAccountId(accounts),
      ),
      reviewBooks: books,
      reviewAccounts: accounts,
      reviewCategories: categories,
      reviewMessage: _message,
      reviewScreenshotAvailable: candidate.screenshotPath != null,
      reviewScreenshotEnabled:
          candidate.screenshotPath != null && _keepScreenshot,
      reviewBottomSafeArea: false,
      onReviewCancel: _close,
      onReviewComplete: _saveOverlayDraft,
      onReviewScreenshotChanged: (enabled) {
        setState(() => _keepScreenshot = enabled);
      },
    );
  }

  Future<bool> _saveOverlayDraft(QuickAddReviewDraft draft) async {
    final candidate = _candidate;
    if (candidate == null || _saving) return false;
    setState(() {
      _bookId = draft.bookId;
      _accountId = draft.accountId;
      _destinationAccountId = draft.destinationAccountId;
      _categoryId = draft.categoryId;
      _subcategoryId = draft.subcategoryId;
      _overlayTransactionType = draft.type;
      _editedAmountInCents = draft.amountInCents;
      _editedNote = draft.note;
      _editedOccurredAt = draft.occurredAt;
      _message = null;
    });
    return _saveSelection(
      bookId: draft.bookId,
      accounts: draft.accounts,
      categories: draft.categories,
      accountId: draft.accountId,
      categoryId: draft.categoryId,
      destinationAccountId: draft.destinationAccountId,
      transferScene: draft.type == TransactionType.transfer,
      reviewDraft: draft,
    );
  }

  PendingAutoBookkeepingCandidate _candidateWithType(
    PendingAutoBookkeepingCandidate candidate,
    TransactionType type,
  ) => PendingAutoBookkeepingCandidate(
    fingerprint: candidate.fingerprint,
    amountInCents: candidate.amountInCents,
    merchant: candidate.merchant,
    paymentMethod: candidate.paymentMethod,
    timestamp: candidate.timestamp,
    sourceApp: candidate.sourceApp,
    scene: candidate.scene,
    transactionType: switch (type) {
      TransactionType.income => 'INCOME',
      TransactionType.refund => 'REFUND',
      TransactionType.reimbursement => 'REIMBURSEMENT',
      TransactionType.transfer => 'TRANSFER',
      _ => 'EXPENSE',
    },
    orderId: candidate.orderId,
    note: candidate.note,
    originalAmountInCents: candidate.originalAmountInCents,
    discountAmountInCents: candidate.discountAmountInCents,
    identifierSuffix: candidate.identifierSuffix,
    targetIdentifierSuffix: candidate.targetIdentifierSuffix,
    targetAccountHint: candidate.targetAccountHint,
    screenshotPath: candidate.screenshotPath,
  );

  Future<bool> _saveSelection({
    required String bookId,
    required List<Account> accounts,
    required List<Category> categories,
    required String? accountId,
    required String? categoryId,
    required String? destinationAccountId,
    required bool transferScene,
    QuickAddReviewDraft? reviewDraft,
  }) {
    final account = accounts.where((item) => item.id == accountId).firstOrNull;
    final category = categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    final destination = accounts
        .where((item) => item.id == destinationAccountId)
        .firstOrNull;
    final isInternalTransfer = reviewDraft != null
        ? reviewDraft.type == TransactionType.transfer
        : _internalTransfer;
    if (account == null) {
      setState(() => _message = transferScene ? '请选择转出账户' : '请选择支付账户');
      return Future.value(false);
    }
    if (transferScene && isInternalTransfer) {
      if (destination == null || destination.id == account.id) {
        setState(() => _message = '请选择不同的转入账户');
        return Future.value(false);
      }
    } else if (category == null) {
      final categoryType = _categoryTypeFor(
        _overlayTransactionType ?? TransactionType.expense,
      );
      setState(
        () => _message =
            '请选择${categoryType == CategoryType.income ? '收入' : '支出'}分类',
      );
      return Future.value(false);
    }
    return _save(
      bookId: bookId,
      account: account,
      category: transferScene && isInternalTransfer ? null : category,
      destinationAccount: transferScene && isInternalTransfer
          ? destination
          : null,
      reviewDraft: reviewDraft,
    );
  }

  Widget _buildContent(BuildContext context) {
    final candidate = _candidate;
    if (candidate == null) {
      return _EmptyState(message: _message ?? '没有待确认的交易记录', onClose: _close);
    }

    final books = ref.watch(booksProvider).value;
    if (books == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (books.isEmpty) {
      return _EmptyState(message: '当前没有可用账本', onClose: _close);
    }
    final activeBookId = ref.watch(activeBookIdProvider);
    final requestedBookId = _bookId ?? activeBookId;
    final selectedBookId = books.any((book) => book.id == requestedBookId)
        ? requestedBookId
        : books.first.id;
    final selectedBook = books
        .where((book) => book.id == selectedBookId)
        .firstOrNull;
    final accounts = ref.watch(accountsByBookProvider(selectedBookId)).value;
    final categories = ref
        .watch(categoriesByBookProvider(selectedBookId))
        .value;
    if (accounts == null || categories == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final isTransferScene = candidate.transactionType == 'TRANSFER';
    final transactionType = isTransferScene && _internalTransfer
        ? TransactionType.transfer
        : _transactionTypeFor(candidate.transactionType);
    final displayTransactionType = isTransferScene
        ? TransactionType.transfer
        : transactionType;
    final categoryType = _categoryTypeFor(transactionType);
    final selectableCategories = categories
        .where((item) => item.type == categoryType)
        .where((item) => item.parentId == null)
        .toList(growable: false);
    final selectedAccountId = _validAccountId(accounts);
    final selectedDestinationAccountId = _validDestinationAccountId(
      accounts,
      sourceAccountId: selectedAccountId,
    );
    final selectedCategoryId = _validCategoryId(selectableCategories);

    final children = <Widget>[
      Row(
        children: [
          IconButton(
            onPressed: _close,
            tooltip: '忽略这笔账单',
            icon: Icon(Icons.close),
          ),
          const SizedBox(width: 4),
          Text('确认记一笔', style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
      const SizedBox(height: 12),
      AppCard(
        color: context.appPrimarySoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已识别${_transactionLabel(displayTransactionType)}',
              style: TextStyle(color: context.appSecondaryText),
            ),
            const SizedBox(height: 8),
            Text(
              '¥${(candidate.amountInCents / 100).toStringAsFixed(2)}',
              style: TextStyle(
                color: _amountColor(displayTransactionType),
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              candidate.merchant,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '${_sourceLabel(candidate.sourceApp)} · ${DateFormat('yyyy-MM-dd HH:mm').format(candidate.timestamp)}',
              style: TextStyle(color: context.appSecondaryText),
            ),
            if (candidate.originalAmountInCents != null &&
                candidate.originalAmountInCents! > candidate.amountInCents) ...[
              const SizedBox(height: 6),
              Text(
                '原价 ¥${(candidate.originalAmountInCents! / 100).toStringAsFixed(2)}'
                '${candidate.discountAmountInCents == null ? '' : ' · 优惠 ¥${(candidate.discountAmountInCents! / 100).toStringAsFixed(2)}'}',
                style: TextStyle(color: context.appSecondaryText),
              ),
            ],
            if (_recommendation?.learnedFromMerchant == true) ...[
              const SizedBox(height: 6),
              Text('已按该商户历史选择预填', style: TextStyle(color: context.appPrimary)),
            ],
            if (_matchedRefundOriginal != null) ...[
              const SizedBox(height: 6),
              Text(
                '已按订单号匹配原消费，将同步冲减原消费净支出',
                style: TextStyle(color: context.appPrimary),
              ),
            ],
            if (!widget.overlayMode && candidate.screenshotPath != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(candidate.screenshotPath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 72,
                    alignment: Alignment.center,
                    color: context.appSurfaceSoft,
                    child: Text(
                      '支付截图暂时无法预览',
                      style: TextStyle(color: context.appSecondaryText),
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('保存这张支付截图'),
                subtitle: const Text('关闭后，完成记账时会删除临时截图'),
                value: _keepScreenshot,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _keepScreenshot = value),
              ),
            ],
          ],
        ),
      ),
      if (isTransferScene) ...[
        const SizedBox(height: 14),
        AppCard(
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '这笔转账怎么记？',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.call_made_outlined),
                      label: Text('转给别人 · 支出'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.swap_horiz),
                      label: Text('自己账户间转账'),
                    ),
                  ],
                  selected: <bool>{_internalTransfer},
                  onSelectionChanged: _saving
                      ? null
                      : (selection) {
                          final internal = selection.single;
                          setState(() {
                            _internalTransfer = internal;
                            _message = null;
                            if (internal) {
                              _destinationAccountId =
                                  _validDestinationAccountId(
                                    accounts,
                                    sourceAccountId: selectedAccountId,
                                  );
                            } else {
                              _destinationAccountId = null;
                            }
                          });
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  _transferGuidance(candidate),
                  style: TextStyle(
                    color:
                        _transferRecommendation?.suggestsInternalTransfer ==
                            true
                        ? context.appPrimary
                        : context.appSecondaryText,
                    fontSize: 12,
                  ),
                ),
                if (candidate.targetAccountHint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '识别到的目标账户：${candidate.targetAccountHint}',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 14),
      AppCard(
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              AppSelect<String>(
                initialValue: selectedBookId,
                decoration: appFieldDecoration('账本'),
                items: [
                  for (final book in books)
                    DropdownMenuItem(value: book.id, child: Text(book.name)),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _bookId = value;
                        _accountId = null;
                        _categoryId = null;
                        _subcategoryId = null;
                        _destinationAccountId = null;
                        if (isTransferScene) {
                          _internalTransfer = false;
                        }
                        if (_matchedRefundOriginal?.bookId != value) {
                          _matchedRefundOriginal = null;
                        }
                      }),
              ),
              const SizedBox(height: 12),
              AppSelect<String>(
                initialValue: selectedAccountId,
                decoration: appFieldDecoration(
                  isTransferScene ? '转出账户' : '支付账户',
                ),
                items: [
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.displayName),
                    ),
                ],
                onChanged:
                    _saving ||
                        selectedBook == null ||
                        _matchedRefundOriginal?.bookId == selectedBookId
                    ? null
                    : (value) => setState(() {
                        _accountId = value;
                        if (_destinationAccountId == value) {
                          _destinationAccountId = null;
                        }
                      }),
              ),
              if (_matchedRefundOriginal?.bookId == selectedBookId)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '退款将原路返回原消费账户',
                      style: TextStyle(
                        color: context.appSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (isTransferScene && _internalTransfer) ...[
                const SizedBox(height: 12),
                AppSelect<String>(
                  initialValue: selectedDestinationAccountId,
                  decoration: appFieldDecoration('转入账户'),
                  items: [
                    for (final destination in accounts.where(
                      (item) => item.id != selectedAccountId,
                    ))
                      DropdownMenuItem(
                        value: destination.id,
                        child: Text(destination.displayName),
                      ),
                  ],
                  onChanged: _saving || selectedBook == null
                      ? null
                      : (value) =>
                            setState(() => _destinationAccountId = value),
                ),
              ],
              if (!(isTransferScene && _internalTransfer)) ...[
                const SizedBox(height: 12),
                if (widget.overlayMode)
                  SizedBox(
                    height: 190,
                    child: CategoryGrid(
                      key: const ValueKey('autobookkeeping-category-grid'),
                      categories: selectableCategories,
                      selected: selectableCategories
                          .where((item) => item.id == selectedCategoryId)
                          .firstOrNull,
                      subcategories: const [],
                      selectedSubcategoryId: null,
                      onSelected: (category, _) => setState(() {
                        _categoryId = category.id;
                        _message = null;
                      }),
                    ),
                  )
                else
                  AppSelect<String>(
                    initialValue: selectedCategoryId,
                    decoration: appFieldDecoration(
                      categoryType == CategoryType.income ? '收入分类' : '支出分类',
                    ),
                    items: [
                      for (final category in selectableCategories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: _saving || selectedBook == null
                        ? null
                        : (value) => setState(() => _categoryId = value),
                  ),
              ],
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isTransferScene && _internalTransfer
                      ? '记住这是自己的账户'
                      : isTransferScene
                      ? '记住这个收款方的选择'
                      : '记住这个商户的选择',
                ),
                subtitle: Text(
                  isTransferScene && _internalTransfer
                      ? '下次遇到同一收款对象时可建议账户间转账'
                      : '下次自动带出账本、账户和分类',
                ),
                value: _rememberForMerchant,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _rememberForMerchant = value),
              ),
            ],
          ),
        ),
      ),
      if (_message != null)
        Padding(
          key: const ValueKey('autobookkeeping-inline-message'),
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            _message!,
            style: const TextStyle(color: AppColors.warning),
          ),
        ),
      const SizedBox(height: 14),
      FilledButton.icon(
        key: const ValueKey('autobookkeeping-save-action'),
        onPressed: _saving || selectedBook == null
            ? null
            : () => _saveSelection(
                bookId: selectedBookId,
                accounts: accounts,
                categories: selectableCategories,
                accountId: selectedAccountId,
                categoryId: selectedCategoryId,
                destinationAccountId: selectedDestinationAccountId,
                transferScene: isTransferScene,
              ),
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
        label: Text(_saving ? '保存中…' : '确认并完成'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _saving ? null : _close,
        child: const Text('忽略这笔识别结果'),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: children,
    );
  }

  String? _validAccountId(List<Account> accounts) =>
      _bestAccountId(accounts, candidate: _candidate, preferredId: _accountId);

  String? _bestAccountId(
    List<Account> accounts, {
    required PendingAutoBookkeepingCandidate? candidate,
    String? preferredId,
  }) {
    final suffix = candidate?.identifierSuffix;
    if (suffix != null && suffix.isNotEmpty) {
      final suffixMatches = accounts
          .where((item) => item.identifierSuffix == suffix)
          .toList(growable: false);
      if (suffixMatches.length == 1) return suffixMatches.single.id;
    }

    if (preferredId != null && accounts.any((item) => item.id == preferredId)) {
      return preferredId;
    }

    final method = candidate?.paymentMethod ?? '';
    final preferredByMethod = accounts.where((item) {
      if (method.contains('支付宝')) return item.type == AccountType.alipay;
      if (method.contains('微信')) return item.type == AccountType.wechat;
      if (method.contains('银行卡') ||
          method.contains('信用卡') ||
          method.contains('储蓄卡') ||
          method.contains('云闪付')) {
        return item.type == AccountType.debitCard ||
            item.type == AccountType.creditCard;
      }
      return false;
    }).firstOrNull;
    if (preferredByMethod != null) return preferredByMethod.id;

    final preferred = accounts.where((item) {
      final source = candidate?.sourceApp;
      return switch (source) {
        'WECHAT' => item.type == AccountType.wechat,
        'ALIPAY' => item.type == AccountType.alipay,
        'UNIONPAY' =>
          item.type == AccountType.debitCard ||
              item.type == AccountType.creditCard,
        _ => false,
      };
    }).firstOrNull;
    return (preferred ?? accounts.firstOrNull)?.id;
  }

  String? _validDestinationAccountId(
    List<Account> accounts, {
    required String? sourceAccountId,
  }) {
    if (_destinationAccountId != null &&
        _destinationAccountId != sourceAccountId &&
        accounts.any((item) => item.id == _destinationAccountId)) {
      return _destinationAccountId;
    }

    final recommended = _transferRecommendation?.destinationAccountId;
    if (recommended != null &&
        recommended != sourceAccountId &&
        accounts.any((item) => item.id == recommended)) {
      return recommended;
    }

    final suffix = _candidate?.targetIdentifierSuffix;
    if (suffix != null && suffix.isNotEmpty) {
      final matches = accounts
          .where(
            (item) =>
                item.id != sourceAccountId && item.identifierSuffix == suffix,
          )
          .toList(growable: false);
      if (matches.length == 1) return matches.single.id;
    }
    return null;
  }

  String _transferGuidance(PendingAutoBookkeepingCandidate candidate) {
    final recommendation = _transferRecommendation;
    if (recommendation?.evidence ==
        AutoBookkeepingTransferEvidence.targetIdentifierSuffix) {
      return '检测到目标账户尾号 ${candidate.targetIdentifierSuffix} 与你的账户唯一匹配，建议按自己账户间转账。';
    }
    if (recommendation?.evidence ==
        AutoBookkeepingTransferEvidence.learnedDestination) {
      return '根据你之前的确认，建议按自己账户间转账。';
    }
    if (_internalTransfer) {
      return '系统没有足够证据确认这是自己的账户，请核对转入账户后再保存。';
    }
    return '无法确认收款方是不是你自己的账户，默认按支出；只有确认转给自己时再切换为账户间转账。';
  }

  String? _validCategoryId(List<Category> categories) {
    if (categories.any((item) => item.id == _categoryId)) return _categoryId;
    return categories.firstOrNull?.id;
  }

  TransactionType _transactionTypeFor(String type) => switch (type) {
    'INCOME' => TransactionType.income,
    'REFUND' => TransactionType.refund,
    'REIMBURSEMENT' => TransactionType.reimbursement,
    _ => TransactionType.expense,
  };

  CategoryType _categoryTypeFor(TransactionType type) => switch (type) {
    TransactionType.income ||
    TransactionType.refund ||
    TransactionType.reimbursement ||
    TransactionType.borrow => CategoryType.income,
    _ => CategoryType.expense,
  };

  String _transactionLabel(TransactionType type) => switch (type) {
    TransactionType.income => '收入',
    TransactionType.refund => '退款',
    TransactionType.reimbursement => '报销回款',
    TransactionType.transfer => '转账',
    _ => '支出',
  };

  Color _amountColor(TransactionType type) => switch (type) {
    TransactionType.income ||
    TransactionType.refund ||
    TransactionType.reimbursement ||
    TransactionType.borrow => AppColors.income,
    TransactionType.transfer => AppColors.primary,
    _ => AppColors.expense,
  };

  String _paymentChannel(PendingAutoBookkeepingCandidate candidate) {
    final method = candidate.paymentMethod;
    if (method.contains('支付宝')) return 'alipay';
    if (method.contains('微信')) return 'wechat';
    if (method.contains('银行卡') ||
        method.contains('信用卡') ||
        method.contains('储蓄卡') ||
        method.contains('云闪付')) {
      return 'bank';
    }
    return switch (candidate.sourceApp) {
      'WECHAT' => 'wechat',
      'ALIPAY' => 'alipay',
      'UNIONPAY' => 'bank',
      'MEITUAN' => 'meituan',
      'JD' => 'jd',
      'PINDUODUO' => 'pinduoduo',
      'DOUYIN' => 'douyin',
      _ => 'payment_app',
    };
  }

  String _sourceLabel(String source) => switch (source) {
    'WECHAT' => '微信支付',
    'ALIPAY' => '支付宝',
    'UNIONPAY' => '云闪付',
    'MEITUAN' => '美团',
    'JD' => '京东',
    'PINDUODUO' => '拼多多',
    'DOUYIN' => '抖音',
    _ => '支付应用',
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onClose, child: const Text('返回')),
        ],
      ),
    ),
  );
}
