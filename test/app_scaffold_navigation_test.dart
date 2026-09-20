import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/widgets/app_bottom_navigation.dart';
import 'package:jizhang_app/core/widgets/app_bottom_sheet.dart';
import 'package:jizhang_app/core/widgets/app_scaffold.dart';

void main() {
  test('global navigation is limited to primary workspace routes', () {
    const primaryRoutes = ['/', '/transactions', '/insights', '/profile'];
    const secondaryRoutes = [
      '/assistant',
      '/analysis',
      '/transactions/search',
      '/transactions/inbox',
      '/transactions/reimbursements',
      '/transactions/calendar',
      '/transactions/transaction-1',
      '/insights/analysis%3Acategory%3Afood',
      '/goals',
      '/goals/goal-1',
      '/profile/account',
      '/profile/account/data-binding',
      '/profile/data',
      '/profile/assets',
      '/profile/accounts',
      '/profile/accounts/account-bank',
      '/profile/categories',
      '/profile/budgets',
      '/profile/membership',
      '/profile/membership/records',
      '/profile/membership/agreement',
      '/profile/privacy',
      '/profile/legal',
      '/profile/family',
      '/profile/payment-notifications',
      '/profile/autobookkeeping',
      '/profile/autobookkeeping/logs',
      '/profile/autobookkeeping/confirm',
      '/profile/recurring-bills',
      '/profile/installments',
      '/profile/installments/plan-1',
      '/profile/investments',
      '/profile/investments/holdings/stock',
      '/profile/investments/holdings/detail/holding-1',
      '/profile/investments/add',
    ];

    for (final route in primaryRoutes) {
      expect(
        isPrimaryAppRoute(route),
        isTrue,
        reason: '$route should keep the global navigation entry points',
      );
    }
    for (final route in secondaryRoutes) {
      expect(
        isPrimaryAppRoute(route),
        isFalse,
        reason: '$route should use its own page-level actions',
      );
    }
  });

  test('primary workspace modal sheets are promoted above the app shell', () {
    const paths = [
      'lib/core/widgets/app_bottom_sheet.dart',
      'lib/core/widgets/app_scaffold.dart',
      'lib/features/books/presentation/book_selector.dart',
      'lib/features/goals/presentation/goal_creation_sheet.dart',
      'lib/features/goals/presentation/goal_planning_sheet.dart',
      'lib/features/home/presentation/home_page.dart',
      'lib/features/profile/presentation/profile_page.dart',
      'lib/features/transactions/presentation/transaction_actions.dart',
      'lib/features/transactions/presentation/transactions_page.dart',
    ];

    for (final path in paths) {
      final lines = File(path).readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (!lines[index].contains('showModalBottomSheet')) continue;
        final end = index + 12 < lines.length ? index + 12 : lines.length;
        final callHead = lines.sublist(index, end).join('\n');
        expect(
          callHead,
          contains('useRootNavigator: true'),
          reason:
              '$path:${index + 1} must present above the ShellRoute navigator '
              'so primary navigation cannot remain visible.',
        );
      }
    }
  });

  testWidgets('AppBottomSheet pushes onto the root navigator', (tester) async {
    final rootObserver = _RecordingNavigatorObserver();
    final nestedObserver = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [rootObserver],
        home: Navigator(
          observers: [nestedObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (nestedContext) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open-root-sheet'),
                  onPressed: () => AppBottomSheet.show<void>(
                    context: nestedContext,
                    builder: (_) => const SizedBox(
                      height: 120,
                      child: Center(child: Text('root sheet')),
                    ),
                  ),
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-root-sheet')));
    await tester.pumpAndSettle();

    expect(rootObserver.popupPushes, 1);
    expect(nestedObserver.popupPushes, 0);
    expect(find.text('root sheet'), findsOneWidget);
  });

  testWidgets(
    'bottom app bar keeps full scaffold width so FAB and notch share X coordinates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(432, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            extendBody: true,
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: const AppBottomNavigation(location: '/'),
          ),
        ),
      );
      await tester.pump();

      final barRect = tester.getRect(
        find.byKey(const ValueKey('app-bottom-navigation-bar')),
      );
      final fabRect = tester.getRect(find.byType(FloatingActionButton));

      expect(
        barRect.left,
        closeTo(0, .1),
        reason:
            'BottomAppBar must stay in the Scaffold coordinate system; visual horizontal inset belongs to its shape, not an outer Padding.',
      );
      expect(barRect.right, closeTo(432, .1));
      expect(
        barRect.center.dx,
        closeTo(fabRect.center.dx, .1),
        reason: 'FAB and notch host must use the same horizontal center.',
      );
    },
  );
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int popupPushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PopupRoute<dynamic>) popupPushes++;
  }
}
