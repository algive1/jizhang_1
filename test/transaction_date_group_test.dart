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
}
