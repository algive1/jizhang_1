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
///
/// Historical samples are calculated with a single reverse pass over the
/// ledger. This keeps range switching O(records + samples * accounts) instead
/// of rescanning the full transaction list once for every chart point.
class AssetHistory {
  AssetHistory(this.accounts, List<TransactionRecord> transactions, this.now) {
    _accountIds = accounts.map((a) => a.id).toSet();
    records =
        transactions
            .where(
              (t) =>
                  t.deletedAt == null &&
                  (_accountIds.contains(t.accountId) ||
                      _accountIds.contains(t.destinationAccountId)),
            )
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  final List<Account> accounts;
  final DateTime now;
  late final Set<String> _accountIds;
  late final List<TransactionRecord> records;

  bool get hasFutureRecords {
    final today = DateTime(now.year, now.month, now.day);
    return records.any((transaction) {
      final date = transaction.occurredAt.toLocal();
      return DateTime(date.year, date.month, date.day).isAfter(today);
    });
  }

  int effect(TransactionRecord record, {String? accountId}) {
    final ids = accountId == null ? _accountIds : {accountId};
    return accountBalanceEffect(record).entries
        .where((entry) => ids.contains(entry.key))
        .fold(0, (sum, entry) => sum + entry.value);
  }

  /// Returns balances at every requested instant while scanning history once.
  /// Results keep the same order as [dates].
  List<double> balancesAt(
    List<DateTime> dates, {
    String? accountId,
    bool positiveOnly = false,
  }) {
    if (dates.isEmpty) return const [];
    final selectedAccounts = accounts.where(
      (account) => accountId == null || account.id == accountId,
    );
    final balances = <String, int>{
      for (final account in selectedAccounts)
        account.id: (account.balance * 100).round(),
    };
    if (balances.isEmpty) return List<double>.filled(dates.length, 0);

    final targets = [
      for (var index = 0; index < dates.length; index++)
        (index: index, date: dates[index]),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final result = List<double>.filled(dates.length, 0);
    var recordIndex = 0;
    for (final target in targets) {
      while (recordIndex < records.length &&
          records[recordIndex].occurredAt.isAfter(target.date)) {
        final recordEffects = accountBalanceEffect(records[recordIndex]);
        for (final entry in recordEffects.entries) {
          if (balances.containsKey(entry.key)) {
            balances[entry.key] = balances[entry.key]! - entry.value;
          }
        }
        recordIndex++;
      }
      final cents = positiveOnly
          ? balances.values.fold<int>(
              0,
              (sum, value) => value > 0 ? sum + value : sum,
            )
          : balances.values.fold<int>(0, (sum, value) => sum + value);
      result[target.index] = cents / 100;
    }
    return result;
  }

  double balanceAt(DateTime date, {String? accountId}) =>
      balancesAt([date], accountId: accountId).single;

  /// Total positive account assets at each requested instant. Debts are kept
  /// out of this series exactly like the current asset cards.
  List<double> positiveBalancesAt(List<DateTime> dates) =>
      balancesAt(dates, positiveOnly: true);

  List<AssetHistoryPoint> points(int days) {
    final start = DateTime(now.year, now.month, now.day - days + 1);
    final step = days > 32 ? 7 : 1;
    final sampleDates = <DateTime>[
      for (var day = 0; day < days - 1; day += step)
        DateTime(
          start.year,
          start.month,
          start.day + day + 1,
        ).subtract(const Duration(microseconds: 1)),
      now,
    ];
    final balances = balancesAt(sampleDates);
    return [
      for (var index = 0; index < sampleDates.length; index++)
        AssetHistoryPoint(
          index == sampleDates.length - 1
              ? now
              : DateTime(
                  sampleDates[index].year,
                  sampleDates[index].month,
                  sampleDates[index].day,
                ),
          balances[index],
        ),
    ];
  }

  double change(int days, {String? accountId}) {
    final beforeStart = DateTime(
      now.year,
      now.month,
      now.day - days + 1,
    ).subtract(const Duration(microseconds: 1));
    final values = balancesAt([now, beforeStart], accountId: accountId);
    return values[0] - values[1];
  }

  double? percent(int days, {String? accountId}) {
    final beforeStart = DateTime(
      now.year,
      now.month,
      now.day - days + 1,
    ).subtract(const Duration(microseconds: 1));
    final values = balancesAt([now, beforeStart], accountId: accountId);
    final initial = values[1];
    return initial > 0 ? (values[0] - initial) / initial * 100 : null;
  }
}
