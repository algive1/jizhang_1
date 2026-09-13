import '../../../core/models/account.dart';
import '../../../core/models/account_balance_effect.dart';
import '../../../core/models/transaction_record.dart';

class AssetHistoryPoint {
  const AssetHistoryPoint(this.date, this.balance);
  final DateTime date;
  final double balance;
}

/// Reconstructs ledger balances, not market prices, from the persisted ledger.
/// All visible ledgers must be supplied, including those sharing these accounts.
class AssetHistory {
  AssetHistory(this.accounts, List<TransactionRecord> transactions, this.now) {
    final ids = accounts.map((a) => a.id).toSet();
    records =
        transactions
            .where(
              (t) =>
                  t.deletedAt == null &&
                  (ids.contains(t.accountId) ||
                      ids.contains(t.destinationAccountId)),
            )
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }
  final List<Account> accounts;
  final DateTime now;
  late final List<TransactionRecord> records;

  bool get hasFutureRecords => records.any((t) => t.occurredAt.isAfter(now));

  int effect(TransactionRecord record, {String? accountId}) {
    final ids = accountId == null
        ? accounts.map((a) => a.id).toSet()
        : {accountId};
    return accountBalanceEffect(record).entries
        .where((entry) => ids.contains(entry.key))
        .fold(0, (sum, entry) => sum + entry.value);
  }

  double balanceAt(DateTime date, {String? accountId}) {
    final selected = accounts.where(
      (a) => accountId == null || a.id == accountId,
    );
    var cents = selected.fold(0, (sum, a) => sum + (a.balance * 100).round());
    for (final record in records) {
      if (record.occurredAt.isAfter(date))
        cents -= effect(record, accountId: accountId);
    }
    return cents / 100;
  }

  List<AssetHistoryPoint> points(int days) {
    final start = DateTime(now.year, now.month, now.day - days + 1);
    // A year uses weekly samples to keep the chart legible.
    final step = days > 32 ? 7 : 1;
    return [
      for (var day = 0; day < days - 1; day += step)
        AssetHistoryPoint(
          DateTime(start.year, start.month, start.day + day),
          balanceAt(
            DateTime(
              start.year,
              start.month,
              start.day + day + 1,
            ).subtract(const Duration(microseconds: 1)),
          ),
        ),
      AssetHistoryPoint(now, balanceAt(now)),
    ];
  }

  double change(int days, {String? accountId}) =>
      balanceAt(now, accountId: accountId) -
      balanceAt(
        DateTime(
          now.year,
          now.month,
          now.day - days + 1,
        ).subtract(const Duration(microseconds: 1)),
        accountId: accountId,
      );

  double? percent(int days, {String? accountId}) {
    final delta = change(days, accountId: accountId);
    final initial = balanceAt(now, accountId: accountId) - delta;
    // A percentage across zero or from debt is not a meaningful return rate.
    return initial > 0 ? delta / initial * 100 : null;
  }
}
