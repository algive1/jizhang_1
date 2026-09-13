import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/database_seeder.dart';
import '../../../core/models/transaction_record.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../recurring/data/recurring_bill_repository.dart';
import '../../../core/models/recurring_bill.dart';

class VerifiedMembershipPurchase {
  const VerifiedMembershipPurchase({
    required this.orderId,
    required this.productId,
    required this.amount,
    required this.currency,
    required this.accountId,
    required this.paidAt,
    required this.provider,
    this.autoRenew = false,
    this.isPermanent = false,
  });

  final String orderId;
  final String productId;
  final double amount;
  final String currency;
  final String accountId;
  final DateTime paidAt;
  final String provider;
  final bool autoRenew;
  final bool isPermanent;
}

class MembershipPurchaseBookkeepingResult {
  const MembershipPurchaseBookkeepingResult({
    required this.transaction,
    required this.created,
  });

  final TransactionRecord transaction;
  final bool created;
}

class MembershipPurchaseBookkeepingService {
  const MembershipPurchaseBookkeepingService({
    required this.transactions,
    required this.bookkeeping,
    this.recurringBills,
  });

  final TransactionRepository transactions;
  final QuickBookkeepingService bookkeeping;
  final RecurringBillRepository? recurringBills;

  Future<MembershipPurchaseBookkeepingResult> record(
    VerifiedMembershipPurchase purchase,
  ) async {
    final orderId = purchase.orderId.trim();
    if (orderId.isEmpty) throw ArgumentError('支付订单号不能为空');
    if (!purchase.amount.isFinite || purchase.amount <= 0) {
      throw ArgumentError('会员购买金额必须大于 0');
    }
    final alreadyRecorded = await _findByOrderId(orderId);
    if (alreadyRecorded != null) {
      await _ensureRecurring(purchase);
      return MembershipPurchaseBookkeepingResult(
        transaction: alreadyRecorded,
        created: false,
      );
    }

    final id = 'auto-membership-${stableAutoKey(orderId)}';
    final request = QuickBookkeepingRequest(
      transactionId: id,
      bookId: SeedIds.personalBook,
      type: TransactionType.expense,
      amount: purchase.amount,
      currency: purchase.currency,
      accountId: purchase.accountId,
      occurredAt: purchase.paidAt,
      categoryId: 'expense-digital',
      categoryName: '数码',
      merchant: '好好记账会员',
      note: '会员商品：${purchase.productId}',
      source: TransactionSource.auto,
      metadata: {
        'autoType': 'membershipPurchase',
        'membershipOrderId': orderId,
        'membershipProductId': purchase.productId,
        'paymentProvider': purchase.provider,
        'autoRenew': purchase.autoRenew,
        'isPermanent': purchase.isPermanent,
      },
    );
    try {
      final created = await bookkeeping.save(request);
      await _ensureRecurring(purchase);
      return MembershipPurchaseBookkeepingResult(
        transaction: created,
        created: true,
      );
    } on StateError {
      // A concurrent/retried callback may win the deterministic primary-key
      // race. Return the committed row rather than creating another record.
      final winner = await _findByOrderId(orderId);
      if (winner != null) {
        return MembershipPurchaseBookkeepingResult(
          transaction: winner,
          created: false,
        );
      }
      rethrow;
    }
  }

  /// Hook for a verified store callback that says auto-renew was cancelled.
  ///
  /// The callback is intentionally separate from [record]: a local purchase
  /// record must remain auditable, while the future recurring occurrences
  /// should stop at the store's cancellation boundary.
  Future<bool> stopAutoRenewForProduct(String productId) async {
    final repository = recurringBills;
    if (repository == null) return false;
    final recurringId =
        'membership-recurring-${stableAutoKey(productId.trim())}';
    final bill = (await repository.getAll())
        .where((item) => item.id == recurringId)
        .firstOrNull;
    if (bill == null || bill.status == RecurringBillStatus.ended) return false;
    await repository.archive(bill.id);
    return true;
  }

  Future<void> _ensureRecurring(VerifiedMembershipPurchase purchase) async {
    if (!purchase.autoRenew || purchase.isPermanent || recurringBills == null) {
      return;
    }
    final cycle = _cycleForProduct(purchase.productId);
    final now = purchase.paidAt;
    final id = 'membership-recurring-${stableAutoKey(purchase.productId)}';
    try {
      await recurringBills!.create(
        RecurringBill(
          id: id,
          bookId: SeedIds.personalBook,
          name: '好好记账会员',
          type: RecurringBillType.membership,
          amount: purchase.amount,
          cycle: cycle,
          startDate: now,
          nextDate: _nextDate(now, cycle),
          accountId: purchase.accountId,
          categoryId: 'expense-digital',
          autoRecord: true,
          reminder: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } on StateError {
      // A retried payment callback may already have created this deterministic
      // recurring row. The original transaction remains the idempotency key.
    }
  }

  RecurringBillCycle _cycleForProduct(String productId) {
    final value = productId.toLowerCase();
    if (value.contains('year') || value.contains('annual')) {
      return RecurringBillCycle.yearly;
    }
    if (value.contains('quarter') || value.contains('quarterly')) {
      return RecurringBillCycle.quarterly;
    }
    return RecurringBillCycle.monthly;
  }

  DateTime _nextDate(DateTime date, RecurringBillCycle cycle) {
    return switch (cycle) {
      RecurringBillCycle.yearly => _addMonths(date, 12),
      RecurringBillCycle.quarterly => _addMonths(date, 3),
      _ => _addMonths(date, 1),
    };
  }

  DateTime _addMonths(DateTime date, int months) {
    final target = DateTime(date.year, date.month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, date.day.clamp(1, lastDay));
  }

  Future<TransactionRecord?> _findByOrderId(String orderId) async {
    for (final transaction in await transactions.getAll()) {
      final metadata = transaction.metadataJson;
      if (metadata == null || metadata.isEmpty) continue;
      try {
        final value = jsonDecode(metadata);
        if (value is Map && value['membershipOrderId'] == orderId) {
          return transaction;
        }
      } on FormatException {
        // Legacy metadata is not an idempotency record.
      }
    }
    return null;
  }
}

String stableAutoKey(String value) {
  var hash = 17;
  for (final unit in value.codeUnits) {
    hash = hash * 31 + unit;
  }
  return hash.abs().toRadixString(16);
}

final membershipPurchaseBookkeepingProvider =
    Provider<MembershipPurchaseBookkeepingService>((ref) {
      final database = ref.watch(databaseProvider);
      // A verified purchase is always a personal ledger event, regardless of
      // which book is currently selected in the UI.
      final transactions = DriftTransactionRepository(database);
      return MembershipPurchaseBookkeepingService(
        transactions: transactions,
        bookkeeping: QuickBookkeepingService(
          transactions,
          ref.watch(appSettingsRepositoryProvider),
        ),
        recurringBills: DriftRecurringBillRepository(
          database,
          bookId: SeedIds.personalBook,
        ),
      );
    });
