import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// The four investment classes the MVP supports.
///
/// Every class shares one page structure; [InvestmentAssetType] is the single
/// discriminator, so no class-specific page or repository is ever created.
enum InvestmentAssetType { stock, fund, bond, crypto }

extension InvestmentAssetTypeX on InvestmentAssetType {
  String get label => switch (this) {
    InvestmentAssetType.stock => '股票',
    InvestmentAssetType.fund => '基金',
    InvestmentAssetType.bond => '债券',
    InvestmentAssetType.crypto => '虚拟币',
  };

  /// Used by the empty state: “暂无股票持仓”.
  String get emptyLabel => switch (this) {
    InvestmentAssetType.stock => '暂无股票持仓',
    InvestmentAssetType.fund => '暂无基金持仓',
    InvestmentAssetType.bond => '暂无债券持仓',
    InvestmentAssetType.crypto => '暂无虚拟币持仓',
  };

  /// Market segment used inside a shared quote cache key:
  /// `quote:stock:CN:600519`.
  String get market => switch (this) {
    InvestmentAssetType.stock => 'CN',
    InvestmentAssetType.fund => 'CN',
    InvestmentAssetType.bond => 'CN',
    InvestmentAssetType.crypto => 'GLOBAL',
  };

  /// Southern-market convention: gains are warm red, losses soft green.
  Color get accent => switch (this) {
    InvestmentAssetType.stock => const Color(0xFFE96D6D),
    InvestmentAssetType.fund => const Color(0xFF6F9638),
    InvestmentAssetType.bond => const Color(0xFFCE9A45),
    InvestmentAssetType.crypto => const Color(0xFF7C8BD9),
  };

  Color get surface => switch (this) {
    InvestmentAssetType.stock => const Color(0xFFFBEDEB),
    InvestmentAssetType.fund => AppColors.primarySoft,
    InvestmentAssetType.bond => const Color(0xFFF8F0DE),
    InvestmentAssetType.crypto => const Color(0xFFEDEFF9),
  };

  IconData get icon => switch (this) {
    InvestmentAssetType.stock => Icons.show_chart_outlined,
    InvestmentAssetType.fund => Icons.pie_chart_outline,
    InvestmentAssetType.bond => Icons.receipt_long_outlined,
    InvestmentAssetType.crypto => Icons.currency_bitcoin_outlined,
  };

  static InvestmentAssetType fromName(String value) =>
      InvestmentAssetType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => InvestmentAssetType.stock,
      );
}

/// Where a quote comes from. `manual` assets have no market data source and
/// expose a user-editable valuation instead.
enum PriceSource { market, manual }

extension PriceSourceX on PriceSource {
  String get label => switch (this) {
    PriceSource.market => '行情自动更新',
    PriceSource.manual => '手动估值',
  };

  static PriceSource fromName(String value) =>
      PriceSource.values.firstWhere(
        (source) => source.name == value,
        orElse: () => PriceSource.manual,
      );
}

enum InvestmentTransactionType { buy, sell, dividend, interest }

extension InvestmentTransactionTypeX on InvestmentTransactionType {
  String get label => switch (this) {
    InvestmentTransactionType.buy => '买入',
    InvestmentTransactionType.sell => '卖出',
    InvestmentTransactionType.dividend => '分红',
    InvestmentTransactionType.interest => '利息',
  };

  /// Cash-flow direction seen from the investor's pocket.
  bool get isCashIn =>
      this == InvestmentTransactionType.dividend ||
      this == InvestmentTransactionType.interest;

  static InvestmentTransactionType fromName(String value) =>
      InvestmentTransactionType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => InvestmentTransactionType.buy,
      );
}

/// A tradable instrument as the app knows it. Shared across all users; the
/// per-user money lives on [InvestmentHolding].
class InvestmentAsset {
  const InvestmentAsset({
    required this.id,
    required this.type,
    required this.symbol,
    required this.name,
    required this.market,
    this.currency = 'CNY',
    this.priceSource = PriceSource.market,
    this.manualPrice,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final InvestmentAssetType type;

  /// Ticker: `600519`, `510300`, `230023`, `BTC`.
  final String symbol;

  final String name;
  final String market;
  final String currency;
  final PriceSource priceSource;

  /// Last user-entered valuation. Only meaningful for
  /// [PriceSource.manual] assets, which have no market data source.
  final double? manualPrice;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Canonical shared cache/quote key, e.g. `quote:stock:CN:600519`.
  String get quoteKey => 'quote:${type.name}:$market:$symbol';

  String get displayCode => symbol.toUpperCase();

  InvestmentAsset copyWith({
    InvestmentAssetType? type,
    String? symbol,
    String? name,
    String? market,
    String? currency,
    PriceSource? priceSource,
    double? manualPrice,
    DateTime? updatedAt,
  }) => InvestmentAsset(
    id: id,
    type: type ?? this.type,
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    market: market ?? this.market,
    currency: currency ?? this.currency,
    priceSource: priceSource ?? this.priceSource,
    manualPrice: manualPrice ?? this.manualPrice,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
