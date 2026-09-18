import 'dart:math' as math;

import 'investment_asset.dart';

/// One user's position in one [InvestmentAsset], optionally attributed to a
/// ledger account from the existing 账户管理 system.
class InvestmentHolding {
  const InvestmentHolding({
    required this.id,
    required this.asset,
    required this.quantity,
    required this.averageCost,
    this.accountId,
    this.note,
    this.bookId = 'book-personal',
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final InvestmentAsset asset;

  /// Units held. Funds use 份额, bonds/stocks use 股/张, crypto uses coin units.
  final double quantity;

  /// Simple average cost per unit, the MVP's only cost basis.
  final double averageCost;

  final String? accountId;
  final String? note;
  final String bookId;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get cost => averageCost * quantity;

  double marketValue(double currentPrice) => currentPrice * quantity;

  /// Unrealised profit: `(currentPrice - averageCost) × quantity`.
  double profit(double currentPrice) => (currentPrice - averageCost) * quantity;

  /// Return rate in percent, or null when cost is zero (nothing comparable).
  double? profitPercent(double currentPrice) {
    if (averageCost <= 0) return null;
    return (currentPrice - averageCost) / averageCost * 100;
  }

  InvestmentHolding copyWith({
    InvestmentAsset? asset,
    double? quantity,
    double? averageCost,
    String? accountId,
    bool clearAccountId = false,
    String? note,
    bool? isArchived,
    DateTime? updatedAt,
  }) => InvestmentHolding(
    id: id,
    asset: asset ?? this.asset,
    quantity: quantity ?? this.quantity,
    averageCost: averageCost ?? this.averageCost,
    accountId: clearAccountId ? null : (accountId ?? this.accountId),
    note: note ?? this.note,
    bookId: bookId,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Applied to a holding. MVP supports exactly four types.
class InvestmentTransaction {
  const InvestmentTransaction({
    required this.id,
    required this.holdingId,
    required this.type,
    required this.quantity,
    required this.price,
    required this.transactionDate,
    this.note,
    this.bookId = 'book-personal',
    this.createdAt,
  });

  final String id;
  final String holdingId;
  final InvestmentTransactionType type;
  final double quantity;
  final double price;
  final DateTime transactionDate;
  final String? note;
  final String bookId;
  final DateTime? createdAt;

  /// Signed cash effect. A buy is money out (negative), a sell/dividend/
  /// interest is money in (positive). It is never treated as consumption.
  double get cashFlow {
    final gross = quantity * price;
    return type == InvestmentTransactionType.buy ? -gross : gross;
  }

  /// Absolute amount shown to the user, e.g. `100股 × ¥100.00` → ¥10,000.
  ///
  /// A cash distribution (分红 / 利息) has no unit count, so it reports the
  /// income directly instead of a quantity × price product.
  double get amount => switch (type) {
    InvestmentTransactionType.dividend ||
    InvestmentTransactionType.interest => price.abs(),
    _ => (quantity * price).abs(),
  };

  /// `100 股 × ¥100.00` — the quantity unit differs per asset class, so the
  /// caller appends the unit label when it has the asset at hand.
  String amountLabel({String unit = '份'}) =>
      '${formatQuantity(quantity)} $unit × ¥${price.toStringAsFixed(2)}';

  /// Drops a trailing `.0` so whole share counts read as `100`, not `100.0`.
  static String formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toString();
  }
}

/// Computes the next position after applying a transaction, using simple
/// average cost. Returns the resulting quantity and average cost.
///
/// - BUY  : weighted average of the existing position and the new purchase.
/// - SELL : quantity drops, average cost is unchanged, and the realised part
///          is not folded into the remaining cost basis.
/// - DIVIDEND / INTEREST : cash income, position unchanged.
({double quantity, double averageCost}) applyTransaction({
  required InvestmentTransactionType type,
  required double quantity,
  required double averageCost,
  required double transactionQuantity,
  required double price,
}) {
  switch (type) {
    case InvestmentTransactionType.buy:
      final nextQuantity = quantity + transactionQuantity;
      if (nextQuantity <= 0) return (quantity: 0, averageCost: price);
      final nextCost =
          (quantity * averageCost) + (transactionQuantity * price);
      return (
        quantity: nextQuantity,
        averageCost: nextCost / nextQuantity,
      );
    case InvestmentTransactionType.sell:
      // Average cost is unchanged by a sale: the remaining units keep the cost
      // basis they were bought at. A closed position keeps the last average
      // cost for display; with quantity 0 it no longer affects profit.
      return (
        quantity: math.max(0, quantity - transactionQuantity),
        averageCost: averageCost,
      );
    case InvestmentTransactionType.dividend:
    case InvestmentTransactionType.interest:
      return (quantity: quantity, averageCost: averageCost);
  }
}
