import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/features/app_runtime/data/app_runtime_repository.dart';
import 'package:jizhang_app/features/support/presentation/help_page.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'published help stays readable with large text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appOperationsProvider('faq').overrideWith(
                (ref) async => const AppOperationsResult(
                  [
                    AppOperation(
                      id: 'faq',
                      title: '后台发布的云备份使用说明',
                      body: '请先登录并绑定本地数据，然后创建首次云备份。',
                    ),
                  ],
                  cached: true,
                  unavailable: true,
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const HelpPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('后台发布的云备份使用说明'), findsOneWidget);
        expect(find.textContaining('已保存的帮助内容'), findsOneWidget);
        await tester.tap(find.text('后台发布的云备份使用说明'));
        await tester.pumpAndSettle();
        expect(find.textContaining('创建首次云备份'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'help uses built-in instructions when remote content is unavailable',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appOperationsProvider('faq').overrideWith(
              (ref) async => const AppOperationsResult([], unavailable: true),
            ),
          ],
          child: const MaterialApp(home: HelpPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('如何开始记账？'), findsOneWidget);
      expect(find.textContaining('内置使用手册'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
