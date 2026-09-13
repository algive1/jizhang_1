import 'package:flutter/material.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_colors.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/widgets/app_card.dart';
import 'package:jizhang_app/features/analysis/data/analysis_repository.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';
import 'package:jizhang_app/features/analysis/presentation/analysis_page.dart';

void main() {
  for (final scenario in [(393.0, 1.0), (320.0, 1.3)]) {
    testWidgets(
      'heatmap paints 168 visible cells at width ${scenario.$1} and text scale ${scenario.$2}',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(scenario.$1, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final now = DateTime(2026, 9, 8, 12);
        final occurredAt = DateTime(2026, 9, 7, 22, 27);
        final snapshot = const StatisticalAnalysisService().analyze([
          TransactionRecord(
            id: 'visible-heatmap-expense',
            bookId: 'book-personal',
            type: TransactionType.expense,
            amount: 100,
            accountId: 'account-cash',
            categoryId: 'expense-food',
            categoryName: '餐饮',
            occurredAt: occurredAt,
            createdAt: occurredAt,
            updatedAt: occurredAt,
          ),
        ], now: now);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              transactionsProvider.overrideWith((ref) => Stream.value([])),
              analysisSnapshotProvider.overrideWith((ref) => snapshot),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scenario.$2)),
                child: child!,
              ),
              home: const Scaffold(body: AnalysisPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('cashflow-trend-plot')),
          findsOneWidget,
        );
        final heading = find.text('7×24 消费热力图');
        await tester.scrollUntilVisible(
          heading,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final card = find
            .ancestor(of: heading, matching: find.byType(AppCard))
            .first;
        final cells = find.descendant(
          of: card,
          matching: find.byWidgetPredicate((widget) {
            if (widget is! DecoratedBox) return false;
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.borderRadius == BorderRadius.circular(3);
          }),
        );
        expect(cells, findsNWidgets(7 * 24));
        for (final element in cells.evaluate()) {
          final box = element.renderObject! as RenderBox;
          expect(box.size.width, greaterThan(0));
          expect(
            box.size.height,
            greaterThanOrEqualTo(8),
            reason:
                'A label-only heatmap with zero-height cells hides spending.',
          );
        }
        final highlighted = cells.evaluate().where((element) {
          final decoration =
              (element.widget as DecoratedBox).decoration as BoxDecoration;
          return decoration.color == AppColors.primary;
        });
        expect(highlighted, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
