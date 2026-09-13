import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/models/dashboard_snapshot.dart';
import 'package:jizhang_app/features/home/presentation/home_insight_drawer.dart';
import 'package:jizhang_app/features/home/presentation/home_promotional_cards.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';

void main() {
  testWidgets(
    'empty data stays hidden; daily display persists across remounts',
    (tester) async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      var day = DateTime(2026, 9, 11);
      var amount = 0.0;
      var available = true;
      var mount = 0;
      Future<void> pumpDrawer({bool settle = true}) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: HomeInsightDrawer(
                  key: ValueKey('$day-$mount'),
                  bookId: 'daily-book',
                  day: day,
                  available: available,
                  insight: FinancialInsight(
                    timeLabel: '22:00后消费',
                    amount: amount,
                    increasePercent: null,
                    description: '消费提醒',
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        if (settle) await tester.pumpAndSettle();
      }

      await pumpDrawer();
      expect(find.byType(HomeInsightCard).hitTestable(), findsNothing);
      final settings = container.read(appSettingsRepositoryProvider);
      expect(await settings.get('home.insight.lastShown.daily-book'), isNull);
      amount = 120;
      available = false;
      await pumpDrawer();
      expect(find.byType(HomeInsightCard).hitTestable(), findsNothing);
      available = true;
      await pumpDrawer();
      expect(find.byType(HomeInsightCard).hitTestable(), findsOneWidget);
      expect(find.text('向上滑动可收起'), findsOneWidget);
      expect(
        await settings.get('home.insight.lastShown.daily-book'),
        day.toIso8601String(),
      );
      await tester.drag(find.byType(HomeInsightCard), const Offset(0, -90));
      await tester.pumpAndSettle();
      expect(find.byType(HomeInsightCard).hitTestable(), findsNothing);
      amount = 240;
      await pumpDrawer();
      expect(find.byType(HomeInsightCard).hitTestable(), findsNothing);
      mount++;
      await pumpDrawer();
      expect(find.byType(HomeInsightCard).hitTestable(), findsNothing);
      day = day.add(const Duration(days: 1));
      await pumpDrawer(settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(HomeInsightCard).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
