import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/widgets/app_scaffold.dart';

void main() {
  test('global navigation is limited to primary workspace routes', () {
    const primaryRoutes = ['/', '/transactions', '/goals', '/profile'];
    const secondaryRoutes = [
      '/analysis',
      '/profile/assets',
      '/profile/accounts',
      '/profile/accounts/account-bank',
      '/profile/categories',
      '/profile/budgets',
      '/profile/data',
      '/profile/membership',
      '/profile/family',
      '/profile/payment-notifications',
      '/profile/autobookkeeping',
      '/profile/recurring-bills',
      '/profile/installments',
      '/profile/installments/plan-1',
      '/transactions/search',
      '/transactions/inbox',
      '/transactions/reimbursements',
      '/transactions/calendar',
      '/transactions/transaction-1',
      '/goals/goal-1',
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
}
