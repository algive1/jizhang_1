import '../../features/assistant/presentation/assistant_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analysis/presentation/analysis_page.dart';
import '../../features/accounts/presentation/account_management_page.dart';
import '../../features/accounts/presentation/asset_overview_page.dart';
import '../../features/accounts/presentation/account_detail_page.dart';
import '../../features/budgets/presentation/budget_page.dart';
import '../../features/categories/presentation/category_management_page.dart';
import '../../features/goals/presentation/goal_detail_page.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/family/presentation/family_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/intelligence/presentation/bill_inbox_page.dart';
import '../../features/notifications/presentation/payment_notification_page.dart';
import '../../features/membership/presentation/membership_page.dart';
import '../../features/membership/presentation/membership_records_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/data_export/presentation/data_export_page.dart';
import '../../core/models/transaction_record.dart';
import '../../features/transactions/presentation/transactions_page.dart';
import '../../features/transactions/presentation/transaction_search_page.dart';
import '../../features/transactions/presentation/transaction_detail_page.dart';
import '../../features/reimbursements/presentation/reimbursement_page.dart';
import '../../features/calendar/presentation/consumption_calendar_page.dart';
import '../../features/recurring/presentation/recurring_bills_page.dart';
import '../../features/installments/presentation/installment_plans_page.dart';
import '../../features/installments/presentation/installment_plan_detail_page.dart';
import '../../core/widgets/app_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppScaffold(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/assistant',
            builder: (context, state) => const AssistantPage(),
          ),
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
                path: 'reimbursements',
                builder: (context, state) => const ReimbursementPage(),
              ),
              GoRoute(
                path: 'calendar',
                builder: (context, state) => const ConsumptionCalendarPage(),
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
                routes: [
                  GoRoute(
                    path: ':accountId',
                    builder: (context, state) => AccountDetailPage(
                      accountId: state.pathParameters['accountId']!,
                    ),
                  ),
                ],
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
                routes: [
                  GoRoute(
                    path: 'records',
                    builder: (context, state) => const MembershipRecordsPage(),
                  ),
                ],
              ),
              GoRoute(
                path: 'family',
                builder: (context, state) => const FamilyPage(),
              ),
              GoRoute(
                path: 'payment-notifications',
                builder: (context, state) => const PaymentNotificationPage(),
              ),
              GoRoute(
                path: 'recurring-bills',
                builder: (context, state) => const RecurringBillsPage(),
              ),
              GoRoute(
                path: 'installments',
                builder: (context, state) => const InstallmentPlansPage(),
                routes: [
                  GoRoute(
                    path: ':planId',
                    builder: (context, state) => InstallmentPlanDetailPage(
                      planId: state.pathParameters['planId']!,
                    ),
                  ),
                ],
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
