import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analysis/presentation/analysis_page.dart';
import '../../features/accounts/presentation/account_management_page.dart';
import '../../features/accounts/presentation/asset_overview_page.dart';
import '../../features/budgets/presentation/budget_page.dart';
import '../../features/categories/presentation/category_management_page.dart';
import '../../features/goals/presentation/goal_detail_page.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/family/presentation/family_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/intelligence/presentation/bill_inbox_page.dart';
import '../../features/notifications/presentation/payment_notification_page.dart';
import '../../features/membership/presentation/membership_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/data_export/presentation/data_export_page.dart';
import '../../core/models/transaction_record.dart';
import '../../features/transactions/presentation/transactions_page.dart';
import '../../features/transactions/presentation/transaction_search_page.dart';
import '../../features/transactions/presentation/transaction_detail_page.dart';
import '../../core/widgets/app_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppScaffold(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/transactions',
            builder: (context, state) =>
                TransactionsPage(month: _queryMonth(state.uri)),
            routes: [
              GoRoute(
                path: 'search',
                builder: (context, state) =>
                    TransactionSearchPage(month: _queryMonth(state.uri)),
              ),
              GoRoute(
                path: 'inbox',
                builder: (context, state) => const BillInboxPage(),
              ),
              GoRoute(
                path: ':transactionId',
                builder: (context, state) => TransactionDetailPage(
                  transactionId: state.pathParameters['transactionId']!,
                  initialTransaction: state.extra is TransactionRecord
                      ? state.extra as TransactionRecord
                      : null,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/analysis',
            builder: (context, state) =>
                AnalysisPage(month: _queryMonth(state.uri)),
          ),
          GoRoute(
            path: '/goals',
            builder: (context, state) => const GoalsPage(),
            routes: [
              GoRoute(
                path: ':goalId',
                builder: (context, state) =>
                    GoalDetailPage(goalId: state.pathParameters['goalId']!),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'data',
                builder: (context, state) => const DataExportPage(),
              ),
              GoRoute(
                path: 'assets',
                builder: (context, state) => const AssetOverviewPage(),
              ),
              GoRoute(
                path: 'accounts',
                builder: (context, state) => const AccountManagementPage(),
              ),
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoryManagementPage(),
              ),
              GoRoute(
                path: 'budgets',
                builder: (context, state) => const BudgetPage(),
              ),
              GoRoute(
                path: 'membership',
                builder: (context, state) => const MembershipPage(),
              ),
              GoRoute(
                path: 'family',
                builder: (context, state) => const FamilyPage(),
              ),
              GoRoute(
                path: 'payment-notifications',
                builder: (context, state) => const PaymentNotificationPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

DateTime? _queryMonth(Uri uri) {
  final value = uri.queryParameters['month'];
  if (value == null || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value))
    return null;
  final month = DateTime.parse('$value-01');
  final now = DateTime.now();
  return month.isAfter(DateTime(now.year, now.month)) ? null : month;
}
