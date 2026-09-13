enum AccountType {
  cash,
  wechat,
  alipay,
  debitCard,
  creditCard,
  other,
  liability,
}

enum AssetForm {
  unspecified,
  cash,
  walletBalance,
  demandDeposit,
  termDeposit,
  investment,
  other,
}

extension AssetFormLabel on AssetForm {
  String get label => switch (this) {
    AssetForm.unspecified => '未注明',
    AssetForm.cash => '现金',
    AssetForm.walletBalance => '支付账户余额',
    AssetForm.demandDeposit => '活期存款',
    AssetForm.termDeposit => '定期存款',
    AssetForm.investment => '投资理财',
    AssetForm.other => '其他资产',
  };
}

extension AccountTypeLabel on AccountType {
  bool get isDebt =>
      this == AccountType.creditCard || this == AccountType.liability;

  /// Accounts whose user-visible identity needs a card/phone suffix.
  ///
  /// Cash and a generic debt ledger do not represent a physical payment
  /// channel, so they intentionally do not require a suffix.
  bool get requiresIdentifierSuffix => switch (this) {
    AccountType.wechat ||
    AccountType.alipay ||
    AccountType.debitCard ||
    AccountType.creditCard ||
    AccountType.other => true,
    AccountType.cash || AccountType.liability => false,
  };

  String get identifierInputLabel => switch (this) {
    AccountType.wechat || AccountType.alipay => '手机号后四位',
    AccountType.debitCard ||
    AccountType.creditCard ||
    AccountType.other => '卡号后四位',
    AccountType.cash || AccountType.liability => '识别后四位',
  };

  String get label => switch (this) {
    AccountType.cash => '现金',
    AccountType.wechat => '微信',
    AccountType.alipay => '支付宝',
    AccountType.debitCard => '银行卡',
    AccountType.creditCard => '信用卡',
    AccountType.other => '其他账户',
    AccountType.liability => '负债账户',
  };
}

class Account {
  const Account({
    this.bookId = 'book-personal',
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.currency,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.openingBalance,
    this.assetForm = AssetForm.unspecified,
    this.identifierSuffix,
  });

  final String bookId;
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final double? openingBalance;
  final String currency;
  final String icon;
  final int color;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AssetForm assetForm;
  final String? identifierSuffix;

  /// The stable label shown to users when they need to distinguish accounts.
  /// The persisted [name] remains the editable base name; the suffix is kept
  /// as structured data so every historical transaction can resolve it from
  /// its existing account ID.
  String get displayName {
    final suffix = identifierSuffix?.trim();
    if (suffix == null || suffix.isEmpty) return name;
    return '$name-$suffix';
  }
}
