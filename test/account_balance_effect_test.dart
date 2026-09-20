import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/account_balance_effect.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';

void main() {
  test('historical import can opt out of current balance effects', () {
    final transaction = _transaction(
      type: TransactionType.expense,
      metadata: {'ignoreAccountBalanceEffect': true},
    );

    expect(accountBalanceEffect(transaction), isEmpty);
  });

  test('normal imported transactions still affect balances by default', () {
    final transaction = _transaction(type: TransactionType.expense);

    expect(accountBalanceEffect(transaction), {'account-a': -1250});
  });

  test('balance-neutral transfer stays neutral on both accounts', () {
    final transaction = _transaction(
      type: TransactionType.transfer,
      destinationAccountId: 'account-b',
      metadata: {'ignoreAccountBalanceEffect': true},
    );

    expect(accountBalanceEffect(transaction), isEmpty);
  });
}

TransactionRecord _transaction({
  required TransactionType type,
  String? destinationAccountId,
  Map<String, Object?> metadata = const {},
}) {
  final now = DateTime(2026, 9, 20);
  return TransactionRecord(
    id: 'test',
    bookId: 'book-personal',
    type: type,
    amount: 12.5,
    accountId: 'account-a',
    destinationAccountId: destinationAccountId,
    occurredAt: now,
    createdAt: now,
    updatedAt: now,
    metadataJson: metadata.isEmpty ? null : jsonEncode(metadata),
  );
}
