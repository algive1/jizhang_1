import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/widgets/app_form.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/budgets/presentation/budget_editor.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';

void main() {
  testWidgets(
    'adding category alongside a total does not lock selection or overwrite total',
    (tester) async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      final repo = DriftBudgetRepository(db, const SafeToSpendService());
      await repo.setBudget(monthKey: '2024-05', amount: 6000);
      final category = (await DriftCategoryRepository(db).getActive())
          .firstWhere(
            (c) => c.parentId == null && c.type == CategoryType.expense,
          );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => showBudgetEditor(
                    context,
                    ref,
                    month: DateTime(2024, 5),
                    categoryBudget: true,
                  ),
                  child: const Text('添加分类'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('添加分类'));
      await tester.pumpAndSettle();
      final selection = tester.widget<AppSelect<String>>(
        find.byType(AppSelect<String>),
      );
      expect(selection.onChanged, isNotNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.byType(AppSelect<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(category.name).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1500');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final rows = await repo.getMonth('2024-05');
      expect(rows.singleWhere((b) => b.categoryId == null).amount, 6000);
      expect(rows.singleWhere((b) => b.categoryId == category.id).amount, 1500);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
