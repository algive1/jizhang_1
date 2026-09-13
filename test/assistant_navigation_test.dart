import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/assistant/application/assistant_conversation.dart';
import 'package:jizhang_app/features/assistant/presentation/assistant_entry_button.dart';
import 'package:jizhang_app/features/assistant/presentation/assistant_page.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/quick_add_sheet.dart';
import 'package:jizhang_app/features/transactions/presentation/transaction_detail_page.dart';

void main() {
  testWidgets('home robot navigates; real record opens edit and detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = createMemoryDatabase();
    await DatabaseSeeder(db).seedIfNeeded();
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    await c.read(assistantConversationProvider.future);
    await c.read(assistantConversationProvider.notifier).send('午餐12元微信');
    final router = c.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AssistantEntryButton), findsOneWidget);
    expect(c.read(assistantUnreadProvider), true);
    await tester.tap(find.byType(AssistantEntryButton));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantPage), findsOneWidget);
    expect(c.read(assistantUnreadProvider), false);
    await tester.tap(find.byTooltip('语音记账'));
    await tester.pumpAndSettle();
    expect(find.text('自动记账需要会员'), findsOneWidget);
    await tester.tap(find.text('快捷开通会员'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/profile/membership');
    router.go('/assistant');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('修改'));
    await tester.tap(find.text('修改'));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsOneWidget);
    final sheet = tester.widget<QuickAddSheet>(find.byType(QuickAddSheet));
    expect(sheet.initialTransaction?.amount, 12);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看详情'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
