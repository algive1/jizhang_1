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
}
