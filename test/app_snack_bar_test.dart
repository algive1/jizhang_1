import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/widgets/app_snack_bar.dart';

void main() {
  testWidgets('app snackbar floats above the global navigation and fab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 844),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => AppSnackBar.show(context, '已保存到本地账本'),
                child: const Text('显示提示'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('显示提示'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.backgroundColor, isNot(Colors.black));
    expect(
      snackBar.margin!.resolve(TextDirection.ltr).bottom,
      greaterThan(100),
    );
  });

  testWidgets('app snackbar drops an older message before showing a new one', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('旧提示一')),
                );
                messenger.showSnackBar(
                  const SnackBar(content: Text('旧提示二')),
                );
                AppSnackBar.show(context, '旧提示');
                AppSnackBar.show(context, '新提示');
              },
              child: const Text('连续显示'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('连续显示'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('旧提示一'), findsNothing);
    expect(find.text('旧提示二'), findsNothing);
    expect(find.text('旧提示'), findsNothing);
    expect(find.text('新提示'), findsOneWidget);
  });
}
