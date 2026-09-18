import 'package:jizhang_app/core/widgets/app_action_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/budgets/presentation/budget_page.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  for (final archiveAll in [false, true]) {
    testWidgets(
      'edit archived budget preserves scope, all archived=$archiveAll',
      (tester) async {
        final db = createMemoryDatabase();
        addTearDown(db.close);
        await DatabaseSeeder(db).seedIfNeeded();
        final categories = DriftCategoryRepository(db);
        final initial = await categories.getActive();
        final category = initial.firstWhere(
          (c) => c.type == CategoryType.expense,
        );
        final repo = DriftBudgetRepository(db, const SafeToSpendService());
        final month = budgetMonthKey(DateTime.now());
        await repo.setBudget(monthKey: month, amount: 1000);
        await repo.setBudget(
          monthKey: month,
          amount: 100,
          categoryId: category.id,
        );
        for (final item in archiveAll ? initial : [category]) {
          await categories.archive(item.id);
        }
        final all = await categories.getAll();
        final active = await categories.getActive();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              categoriesProvider.overrideWithValue(AsyncData(active)),
              allCategoriesProvider.overrideWithValue(AsyncData(all)),
              transactionsProvider.overrideWithValue(const AsyncData([])),
              goalsProvider.overrideWithValue(const AsyncData([])),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: BudgetPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (archiveAll) expect(find.text('添加'), findsNothing);
        final menu = find.byType(AppActionMenuButton<String>);
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('调整').last);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(category.name),
          ),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), 'NaN');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          (await repo.getMonth(month))
              .singleWhere((b) => b.categoryId == category.id)
              .amount,
          100,
        );
        await tester.enterText(find.byType(TextField), '250');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
        final saved = await repo.getMonth(month);
        expect(saved, hasLength(2));
        expect(
          saved.singleWhere((b) => b.categoryId == category.id).amount,
          250,
        );
        expect(saved.singleWhere((b) => b.categoryId == null).amount, 1000);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
