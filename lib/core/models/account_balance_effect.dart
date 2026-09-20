import 'dart:convert';

import 'transaction_record.dart';

/// The signed ledger effect, shared by persistence and asset history.
Map<String, int> accountBalanceEffect(TransactionRecord transaction) {
  if (_ignoresAccountBalanceEffect(transaction)) return const {};

  final cents = (transaction.amount * 100).round();
  final source = transaction.accountId;
  final destination = transaction.destinationAccountId;
  return switch (transaction.type) {
    TransactionType.expense ||
    TransactionType.lend ||
    TransactionType.assetPurchase => {source: -cents},
    TransactionType.transfer ||
    TransactionType.repayment => {source: -cents, ?destination: cents},
    TransactionType.income ||
    TransactionType.refund ||
    TransactionType.reimbursement ||
    TransactionType.borrow ||
    TransactionType.adjustment ||
    TransactionType.assetSale => {source: cents},
  };
}

bool _ignoresAccountBalanceEffect(TransactionRecord transaction) {
  final metadataJson = transaction.metadataJson;
  if (metadataJson == null || metadataJson.trim().isEmpty) return false;
  try {
    final decoded = jsonDecode(metadataJson);
    return decoded is Map && decoded['ignoreAccountBalanceEffect'] == true;
  } on Object {
    return false;
  }
}
