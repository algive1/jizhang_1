import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/widgets/transaction_date_group.dart';

void main() {
  testWidgets(
    'transfer is excluded from date-group income and spending totals',
    (tester) async {
      final now = DateTime(2026, 9, 1, 12);
      final transfer = TransactionRecord(
        id: 'transfer',
        bookId: 'book',
        type: TransactionType.transfer,
        amount: 100,
        accountId: 'cash',
        destinationAccountId: 'bank',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionDateGroup(
              dateLabel: '今天',
              transactions: [transfer],
            ),
          ),
        ),
      );

      expect(find.text('支出 ¥0.00'), findsOneWidget);
      expect(find.text('收入 ¥0.00'), findsOneWidget);
    },
  );

  testWidgets('date-group income totals use the income amount', (tester) async {
    final now = DateTime(2026, 9, 1, 12);
    final income = TransactionRecord(
      id: 'income',
      bookId: 'book',
      type: TransactionType.income,
      amount: 88,
      accountId: 'cash',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionDateGroup(dateLabel: '今天', transactions: [income]),
        ),
      ),
    );

    expect(find.text('收入 ¥88.00'), findsOneWidget);
  });

  testWidgets('date-group spending totals use net refund amount', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 1, 12);
    final refunded = TransactionRecord(
      id: 'refunded',
      bookId: 'book',
      type: TransactionType.expense,
      amount: 500,
      accountId: 'cash',
      refundStatus: RefundStatus.partial,
      refundAmount: 200,
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionDateGroup(dateLabel: '今天', transactions: [refunded]),
        ),
      ),
    );

    expect(find.text('支出 ¥300.00'), findsOneWidget);
  });
}
