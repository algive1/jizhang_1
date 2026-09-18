import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/widgets/app_bottom_navigation.dart';
import 'package:jizhang_app/core/widgets/app_scaffold.dart';

void main() {
  test('global navigation is limited to primary workspace routes', () {
    const primaryRoutes = ['/', '/transactions', '/goals', '/profile'];
    const secondaryRoutes = [
      '/assistant',
      '/analysis',
      '/transactions/search',
      '/transactions/inbox',
      '/transactions/reimbursements',
      '/transactions/calendar',
      '/transactions/transaction-1',
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
