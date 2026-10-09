import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/widgets/goal_icon.dart';
import 'package:jizhang_app/features/goals/presentation/goal_type_picker.dart';
import 'package:jizhang_app/features/goals/presentation/goal_creation_sheet.dart';

void main() {
  testWidgets('creation keeps entered fields and returns selected goal type', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    GoalCreationDraft? result;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showGoalCreationSheet(context);
                  },
                  child: const Text('新建'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    final name = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '目标名称',
    );
    final amount = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '目标金额',
    );
    await tester.enterText(name, '家庭旅行');
    await tester.enterText(amount, '12000');
    await tester.tap(find.byKey(const ValueKey('goal-type-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-type-travel')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(name).controller!.text, '家庭旅行');
    expect(tester.widget<TextField>(amount).controller!.text, '12000');
    expect(
      tester.widget<GoalTypeSelect>(find.byType(GoalTypeSelect)).value,
      GoalType.travel,
    );
    final submit = find.widgetWithText(FilledButton, '创建目标');
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(result?.name, '家庭旅行');
    expect(result?.targetAmount, 12000);
    expect(result?.type, GoalType.travel);
    expect(tester.takeException(), isNull);
  });
  for (final config in [
    (const Size(393, 844), 1.0, 3, false),
    (const Size(320, 640), 1.6, 2, false),
    (const Size(600, 960), 1.6, 2, true),
  ]) {
    testWidgets(
      'goal type cards select, dismiss and fit ${config.$1} / ${config.$2}',
      (tester) async {
        await tester.binding.setSurfaceSize(config.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var selected = GoalType.travel;
        await tester.pumpWidget(
          MaterialApp(
            theme: config.$4 ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(config.$2)),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: GoalTypeSelect(
                      value: selected,
                      onChanged: (value) => setState(() => selected = value),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final field = find.byKey(const ValueKey('goal-type-select'));
        await tester.tap(field);
        await tester.pumpAndSettle();
        final grid = tester.widget<GridView>(
          find.byKey(const ValueKey('goal-type-grid')),
        );
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          config.$3,
        );
        expect(
          grid.childrenDelegate.estimatedChildCount,
          GoalType.values.length,
        );
        final travel = find.byKey(const ValueKey('goal-type-travel'));
        expect(
          find.descendant(
            of: travel,
            matching: find.byIcon(goalTypeIcon(GoalType.travel)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: travel,
            matching: find.byIcon(Icons.check_circle),
          ),
          findsOneWidget,
        );
        final custom = find.byKey(const ValueKey('goal-type-custom'));
        await tester.ensureVisible(custom);
        await tester.pumpAndSettle();
        await tester.tap(custom);
        await tester.pumpAndSettle();
        expect(selected, GoalType.custom);
        expect(find.byKey(const ValueKey('goal-type-grid')), findsNothing);
        expect(
          find.descendant(of: field, matching: find.text('自定义')),
          findsOneWidget,
        );
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(selected, GoalType.custom);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
