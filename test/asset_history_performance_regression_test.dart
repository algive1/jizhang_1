import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/domain/asset_history.dart';

void main() {
  test('asset history bulk scan preserves historical balances and order', () {
    final now = DateTime(2026, 9, 5, 12);
    final accounts = [
      _account('cash', 850),
      _account('bank', 750),
      _account('debt', -100),
    ];
    final transactions = [
      _record(
        'income',
        TransactionType.income,
        1000,
        'cash',
        DateTime(2026, 9, 1, 9),
      ),
      _record(
        'expense',
        TransactionType.expense,
        200,
        'cash',
        DateTime(2026, 9, 2, 12),
      ),
      _record(
        'transfer',
        TransactionType.transfer,
        300,
        'cash',
        DateTime(2026, 9, 3, 18),
        destination: 'bank',
      ),
      _record(
        'bank-expense',
        TransactionType.expense,
        50,
        'bank',
        DateTime(2026, 9, 4, 10),
      ),
    ];
    final history = AssetHistory(accounts, transactions, now);

    final endSep1 = DateTime(2026, 9, 2)
        .subtract(const Duration(microseconds: 1));
    final endSep2 = DateTime(2026, 9, 3)
        .subtract(const Duration(microseconds: 1));
    final endSep3 = DateTime(2026, 9, 4)
        .subtract(const Duration(microseconds: 1));
    final endSep4 = DateTime(2026, 9, 5)
        .subtract(const Duration(microseconds: 1));

    expect(
      history.balancesAt([endSep3, endSep1, endSep4, endSep2]),
      [1550, 1750, 1500, 1550],
    );
    expect(
      history.positiveBalancesAt([endSep1, endSep2, endSep3, endSep4]),
      [1850, 1650, 1650, 1600],
    );
    expect(history.balanceAt(endSep3, accountId: 'cash'), 850);
    expect(history.balanceAt(endSep3, accountId: 'bank'), 800);
  });

  test('asset history range points keep the current balance as final sample', () {
    final now = DateTime(2026, 9, 5, 12);
    final history = AssetHistory(
      [_account('cash', 850), _account('bank', 750)],
      [
        _record(
          'expense',
          TransactionType.expense,
          50,
          'bank',
          DateTime(2026, 9, 4, 10),
        ),
      ],
      now,
    );

    final points = history.points(3);
    expect(points.last.date, now);
    expect(points.last.balance, 1600);
    expect(history.change(3), -50);
    expect(history.percent(3), closeTo(-50 / 1650 * 100, 1e-9));
  });
}

Account _account(String id, double balance) => Account(
      id: id,
      name: id,
      type: id == 'debt' ? AccountType.liability : AccountType.debitCard,
      balance: balance,
      currency: 'CNY',
      icon: 'wallet',
      color: 0,
      sortOrder: 0,
      isArchived: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

TransactionRecord _record(
  String id,
  TransactionType type,
  double amount,
  String accountId,
  DateTime occurredAt, {
  String? destination,
}) =>
    TransactionRecord(
      id: id,
      bookId: 'book',
      type: type,
      amount: amount,
      accountId: accountId,
      destinationAccountId: destination,
      occurredAt: occurredAt,
      createdAt: occurredAt,
      updatedAt: occurredAt,
    );
