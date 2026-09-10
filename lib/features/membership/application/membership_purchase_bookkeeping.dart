import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/database_seeder.dart';
import '../../../core/models/transaction_record.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../transactions/data/transactions_repository.dart';

class VerifiedMembershipPurchase {
  const VerifiedMembershipPurchase({
    required this.orderId,
    required this.productId,
    required this.amount,
    required this.currency,
    required this.accountId,
    required this.paidAt,
    required this.provider,
  });

  final String orderId;
  final String productId;
  final double amount;
  final String currency;
  final String accountId;
  final DateTime paidAt;
  final String provider;
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
  });

  final TransactionRepository transactions;
  final QuickBookkeepingService bookkeeping;

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
      },
    );
    try {
      final created = await bookkeeping.save(request);
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
      );
    });
