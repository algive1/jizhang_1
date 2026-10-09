import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/widgets/app_bottom_navigation.dart';
import 'package:jizhang_app/core/widgets/app_profile_glass_card.dart';
import 'package:jizhang_app/core/widgets/app_scaffold.dart';
import 'package:jizhang_app/features/assistant/application/assistant_conversation.dart';
import 'package:jizhang_app/features/assistant/presentation/assistant_page.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';

void main() {
  testWidgets(
    'secondary backgrounds fill the viewport; membership stays inset',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = createMemoryDatabase();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      const pageKey = ValueKey('page-viewport');
      for (final (route, bottom) in [
        ('/profile', 842.0),
        ('/profile/assets', 874.0),
        ('/assistant', 874.0),
        ('/analysis', 874.0),
        ('/transactions/calendar', 874.0),
        ('/profile/membership', 842.0),
        ('/profile/membership/records', 842.0),
        ('/profile/membership/agreement', 842.0),
      ]) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(BuiltInThemes.liquidGlass),
              home: MediaQuery(
                data: const MediaQueryData(
                  padding: EdgeInsets.only(bottom: 24),
                ),
                child: AppScaffold(
                  location: route,
                  child: const SizedBox.expand(key: pageKey),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.getRect(find.byKey(pageKey)).bottom,
          bottom,
          reason: route,
        );
        expect(
          find.byType(AppBottomNavigation),
          route == '/profile' ? findsOneWidget : findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final (width, scale, dark, glass) in [
    (393.0, 1.0, false, true),
    (393.0, 1.0, true, true),
    (320.0, 1.8, false, true),
    (320.0, 1.8, true, true),
    (393.0, 1.0, false, false),
    (393.0, 1.0, true, false),
    (320.0, 1.8, false, false),
    (320.0, 1.8, true, false),
  ]) {
    testWidgets(
      'assistant input fits $width/$scale/$dark/$glass and keyboard',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        await tester.binding.setSurfaceSize(Size(width, 852));
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = createMemoryDatabase();
        await DatabaseSeeder(db).seedIfNeeded();
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sessionProvider.overrideWithValue(const AsyncData(null)),
          ],
        );
        addTearDown(container.dispose);
        await container.read(assistantConversationProvider.future);
        final theme = glass
            ? BuiltInThemes.liquidGlass
            : BuiltInThemes.freshGreen;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: dark ? AppTheme.dark(theme) : AppTheme.light(theme),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: EdgeInsets.only(
                    top: 24,
                    bottom: MediaQuery.viewInsetsOf(context).bottom > 0
                        ? 0
                        : 24,
                  ),
                  viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: const AppScaffold(
                location: '/assistant',
                child: AssistantPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = tester.getRect(find.byType(AppProfileGlassCard));
        expect(card.left, 12);
        expect(card.right, width - 12);
        expect(card.bottom, 852 - 24);
        if (width < 360) {
          expect(tester.getSize(find.byType(TextField)).width, greaterThan(80));
          await tester.tap(find.byTooltip('更多输入方式'));
          await tester.pumpAndSettle();
          expect(find.text('选择图片'), findsOneWidget);
          expect(find.text('附件'), findsOneWidget);
          await tester.tapAt(const Offset(1, 1));
          await tester.pumpAndSettle();
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(852 - 280),
        );
        await tester.enterText(find.byType(TextField), '本月收支');
        await tester.pump();
        await tester.tap(find.byTooltip('发送'));
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        final messages = container
            .read(assistantConversationProvider)
            .requireValue;
        expect(
          messages.any((message) => message.isUser && message.text == '本月收支'),
          isTrue,
        );
        expect(messages.last.isUser, isFalse);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
