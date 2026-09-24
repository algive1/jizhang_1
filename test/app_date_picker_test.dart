import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/widgets/app_date_picker.dart';

void main() {
  testWidgets('date picker keeps its range and clamps out of range initial dates', (
    tester,
  ) async {
    final minimum = DateTime(2026, 1, 10);
    final maximum = DateTime(2026, 1, 20);
    var initial = DateTime(2026, 1, 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => AppDatePicker.show(
                context,
                initial,
                minimumDate: minimum,
                maximumDate: maximum,
              ),
              child: const Text('选择日期'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择日期'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.minimumDate, minimum);
    expect(picker.maximumDate, maximum);
    expect(picker.initialDateTime, minimum);

    await tester.tap(find.text('确认日期'));
    await tester.pumpAndSettle();
    initial = DateTime(2026, 1, 30);
    await tester.tap(find.text('选择日期'));
    await tester.pumpAndSettle();

    final pickerAfterMaximum = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(pickerAfterMaximum.initialDateTime, maximum);
  });
}
