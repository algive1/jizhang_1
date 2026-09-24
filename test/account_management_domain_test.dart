import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/account_balance_effect.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/domain/account_management.dart';
import 'package:jizhang_app/features/accounts/domain/asset_overview.dart';

void main() {
  Account account(String id, double balance) => Account(
    id: id,
    name: id,
    type: AccountType.cash,
    balance: balance,
    openingBalance: balance,
    currency: 'CNY',
    icon: 'wallet',
    color: 0xff000000,
    sortOrder: 0,
    isArchived: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('excluded accounts stay in list but do not contribute to asset total', () {
    final visible = account('visible', 1000);
    final excluded = account('excluded', 3000);
    final overview = AssetOverview(
      'CNY',
      [visible, excluded],
      excludedAccountIds: const {'excluded'},
    );

    expect(overview.accounts, hasLength(2));
    expect(overview.assets, 1000);
    expect(overview.netAssets, 1000);
    expect(overview.byForm.values.fold<double>(0, (a, b) => a + b), 1000);
  });

  test('restricted transfer is an internal movement, not income or expense', () {
    final now = DateTime(2026, 1, 1);
    final record = TransactionRecord(
      id: 't1',
      bookId: 'book-personal',
      type: TransactionType.transfer,
      amount: 500,
      accountId: 'bank',
      destinationAccountId: 'deposit',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );

    expect(record.isIncome, isFalse);
    expect(record.isExpense, isFalse);
    expect(record.isConsumptionExpense, isFalse);
    expect(accountBalanceEffect(record), {'bank': -50000, 'deposit': 50000});
  });

  test('receivable collection adjustment changes balance without income stats', () {
    final now = DateTime(2026, 1, 1);
    final record = TransactionRecord(
      id: 't2',
      bookId: 'book-personal',
      type: TransactionType.adjustment,
      amount: 560,
      accountId: 'bank',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );

    expect(record.isIncome, isFalse);
    expect(record.isExpense, isFalse);
    expect(accountBalanceEffect(record), {'bank': 56000});
  });

  test('receivable derives remaining amount and overdue state', () {
    final item = Receivable(
      id: 'r1',
      bookId: 'book-personal',
      name: '差旅待报销',
      type: ReceivableType.reimbursement,
      counterparty: '公司',
      totalAmount: 1000,
      receivedAmount: 400,
      occurredAt: DateTime(2025, 1, 1),
      expectedAt: DateTime(2025, 1, 10),
      status: ReceivableStatus.partial,
      businessStatus: '部分回收',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
    );

    expect(item.remainingAmount, 600);
    expect(item.effectiveStatus, ReceivableStatus.overdue);
    expect(item.visibleStatus, '逾期');
  });

  test('custom account is grouped with available funds in overview', () {
    final managed = ManagedAccount(
      account: account('custom', 20),
      category: AccountFundCategory.custom,
    );

    expect(managed.overviewCategory, AccountFundCategory.available);
  });
}
