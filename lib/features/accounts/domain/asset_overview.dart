import '../../../core/models/account.dart';

/// All totals use signed ledger balances, including archived accounts.
/// Different currencies are never converted or added together.
class AssetOverview {
  AssetOverview(this.currency, this.accounts, {this.investmentValue = 0});

  final String currency;
  final List<Account> accounts;

  /// Market value of the investment positions held in this currency.
  ///
  /// Investments are positions rather than accounts, so they are folded into
  /// net worth here instead of being faked as an account row.
  final double investmentValue;

  int get _investmentCents => (investmentValue * 100).round();

  int get _assetCents =>
      accounts
          .where((a) => a.balance > 0)
          .fold(0, (sum, a) => sum + (a.balance * 100).round()) +
      _investmentCents;
  int get _debtCents => accounts
      .where((a) => a.balance < 0)
      .fold(0, (sum, a) => sum - (a.balance * 100).round());
  double get assets => _assetCents / 100;
  double get liabilities => _debtCents / 100;
  double get netAssets => (_assetCents - _debtCents) / 100;
  bool get hasUnverifiedNegativeBalance =>
      accounts.any((a) => !a.type.isDebt && a.balance < 0);

  Map<AssetForm, double> get byForm {
    final cents = <AssetForm, int>{};
    for (final account in accounts.where((a) => a.balance > 0)) {
      cents.update(
        account.assetForm,
        (v) => v + (account.balance * 100).round(),
        ifAbsent: () => (account.balance * 100).round(),
      );
    }
    if (_investmentCents != 0) {
      cents.update(
        AssetForm.investment,
        (v) => v + _investmentCents,
        ifAbsent: () => _investmentCents,
      );
    }
    return cents.map((key, value) => MapEntry(key, value / 100));
  }

  static List<AssetOverview> group(
    List<Account> accounts, {
    Map<String, double> investmentByCurrency = const {},
  }) {
    final groups = <String, List<Account>>{};
    for (final account in accounts) {
      groups.putIfAbsent(account.currency.toUpperCase(), () => []).add(account);
    }
    // A currency can hold investments without holding any account, so those
    // currencies take part in the grouping as well.
    for (final currency in investmentByCurrency.keys) {
      groups.putIfAbsent(currency.toUpperCase(), () => []);
    }
    final currencies = groups.keys.toList()
      ..sort((a, b) {
        if (a == b) return 0;
        if (a == 'CNY') return -1;
        if (b == 'CNY') return 1;
        return a.compareTo(b);
      });
    return [
      for (final currency in currencies)
        AssetOverview(
          currency,
          groups[currency]!,
          investmentValue: investmentByCurrency[currency] ?? 0,
        ),
    ];
  }
}
