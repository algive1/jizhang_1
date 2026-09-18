import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/widgets/money_text.dart';
import 'package:jizhang_app/core/widgets/transaction_date_group.dart';
import 'package:jizhang_app/core/widgets/transaction_tile.dart';

import 'support/reference_capture.dart';

void main() {
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('transaction rows align at $width dp and $scale text scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.binding.setSurfaceSize(null);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await loadReferenceFonts(tester);
        final now = DateTime(2026, 9, 14, 12, 30);
        final records = [
          for (final (index, type) in [
            TransactionType.expense,
            TransactionType.income,
            TransactionType.transfer,
          ].indexed)
            TransactionRecord(
              id: 'row-$index',
              bookId: 'book',
              type: type,
              amount: index == 0 ? 12345678.99 : 200,
              accountId: 'cash',
              destinationAccountId: type == TransactionType.transfer
                  ? 'bank'
                  : null,
              categoryName: type == TransactionType.income ? '工资' : '餐饮',
              note: index == 0 ? '与同事聚餐及交通费用（测试很长的备注）' : null,
              occurredAt: now,
              createdAt: now,
              updatedAt: now,
            ),
        ];
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('rows-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TransactionDateGroup(
                    dateLabel: '今天 · 9月14日',
                    transactions: records,
                    accountNames: const {
                      'cash': '微信支付（很长的账户名称）',
                      'bank': '招商银行',
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final amounts = find.byType(MoneyText);
        final right = tester.getBottomRight(amounts.first).dx;
        for (var i = 1; i < amounts.evaluate().length; i++) {
          expect(tester.getBottomRight(amounts.at(i)).dx, closeTo(right, .1));
        }
        expect(find.byType(TransactionTile), findsNWidgets(3));
        await captureReference(
          tester,
          find.byKey(const ValueKey('rows-capture')),
          '../quick-add-layout-2026-09-14/transactions-$width-$scale',
        );
      });
    }
  }
}
