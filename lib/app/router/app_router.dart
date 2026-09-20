import '../../features/assistant/presentation/assistant_page.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analysis/presentation/analysis_page.dart';
import '../../features/analysis/presentation/annual_report_page.dart';
import '../../features/insights/presentation/insights_page.dart';
import '../../features/insights/presentation/insight_detail_page.dart';
import '../../features/insights/domain/insight_models.dart';
import '../../features/account/presentation/account_center_page.dart';
import '../../features/account/presentation/account_login_page.dart';
import '../../features/account/presentation/account_recovery_page.dart';
import '../../features/account/presentation/dataset_binding_page.dart';
import '../../features/account/presentation/account_register_page.dart';
import '../../features/accounts/presentation/account_management_page.dart';
import '../../features/accounts/presentation/asset_overview_page.dart';
import '../../features/accounts/presentation/account_detail_page.dart';
import '../../features/budgets/presentation/budget_page.dart';
import '../../features/categories/presentation/category_management_page.dart';
import '../../features/goals/presentation/goal_detail_page.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/family/presentation/family_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/investments/domain/investment_asset.dart';
import '../../features/investments/presentation/investment_add_page.dart';
import '../../features/investments/presentation/investment_detail_page.dart';
import '../../features/investments/presentation/investment_overview_page.dart';
import '../../features/intelligence/presentation/bill_inbox_page.dart';
import '../../features/notifications/presentation/payment_notification_page.dart';
import '../../features/notifications/presentation/notification_settings_page.dart';
import '../../features/messages/presentation/message_center_page.dart';
import '../../features/support/presentation/feedback_page.dart';
import '../../features/support/presentation/help_page.dart';
import '../../features/support/presentation/about_page.dart';
import '../../features/support/presentation/support_tickets_page.dart';
import '../../features/support/presentation/support_ticket_detail_page.dart';
import '../../features/autobookkeeping/presentation/auto_bookkeeping_page.dart';
import '../../features/autobookkeeping/presentation/ios_shortcut_bookkeeping_page.dart';
import '../../features/autobookkeeping/presentation/auto_bookkeeping_confirm_page.dart';
import '../../features/autobookkeeping/presentation/auto_bookkeeping_logs_page.dart';
import '../../features/membership/presentation/membership_page.dart';
import '../../features/membership/presentation/membership_records_page.dart';
import '../../features/legal/presentation/legal_document_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/settings/presentation/theme_settings_page.dart';
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
import '../../features/finance_center/presentation/finance_center_page.dart';
import '../../features/bill_import/presentation/bill_import_page.dart';
import '../../features/ocr/presentation/receipt_ocr_page.dart';
import '../../core/widgets/app_scaffold.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/account/login',
        builder: (context, state) => const AccountLoginPage(),
      ),
      GoRoute(
        path: '/account/register',
        builder: (context, state) => const AccountRegisterPage(),
      ),
      GoRoute(
        path: '/account/recover',
        builder: (context, state) => const AccountRecoveryPage(),
      ),
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
                builder: (context, state) => TransactionSearchPage(
                  month: _queryMonth(state.uri),
                  transactionIds: state.extra is List<String>
                      ? (state.extra! as List<String>).toSet()
                      : const {},
                ),
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
            routes: [
              GoRoute(
                path: 'annual-report',
                builder: (context, state) => const AnnualReportPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/insights',
            builder: (context, state) => const InsightsPage(),
            routes: [
              GoRoute(
                path: ':insightId',
                builder: (context, state) => InsightDetailPage(
                  insightId: Uri.decodeComponent(
                    state.pathParameters['insightId']!,
                  ),
                  fallback: state.extra is FinancialInsightItem
                      ? state.extra! as FinancialInsightItem
                      : null,
                ),
              ),
            ],
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
                path: 'account',
                builder: (context, state) => const AccountCenterPage(),
                routes: [
                  GoRoute(
                    path: 'data-binding',
                    builder: (context, state) => const DatasetBindingPage(),
                  ),
                ],
              ),
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
                  GoRoute(
                    path: 'agreement',
                    builder: (context, state) => const LegalDocumentPage(
                      kind: LegalDocumentKind.membership,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'appearance',
                builder: (context, state) => const ThemeSettingsPage(),
              ),
              GoRoute(
                path: 'privacy',
                builder: (context, state) =>
                    const LegalDocumentPage(kind: LegalDocumentKind.privacy),
              ),
              GoRoute(
                path: 'legal',
                builder: (context, state) => const LegalDocumentsPage(),
              ),
              GoRoute(
                path: 'family',
                builder: (context, state) => const FamilyPage(),
              ),
              GoRoute(
                path: 'messages',
                builder: (context, state) => const MessageCenterPage(),
              ),
              GoRoute(
                path: 'notification-settings',
                builder: (context, state) => const NotificationSettingsPage(),
              ),
              GoRoute(
                path: 'help',
                builder: (context, state) => const HelpPage(),
              ),
              GoRoute(
                path: 'feedback',
                builder: (context, state) => const FeedbackPage(),
              ),
              GoRoute(
                path: 'support-tickets',
                builder: (context, state) => const SupportTicketsPage(),
                routes: [
                  GoRoute(
                    path: ':ticketId',
                    builder: (context, state) => SupportTicketDetailPage(
                      ticketId: state.pathParameters['ticketId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutPage(),
              ),
              GoRoute(
                path: 'payment-notifications',
                builder: (context, state) => const PaymentNotificationPage(),
              ),
              GoRoute(
                path: 'autobookkeeping',
                builder: (context, state) => const AutoBookkeepingPage(),
                routes: [
                  GoRoute(
                    path: 'shortcut',
                    builder: (context, state) =>
                        const IosShortcutBookkeepingPage(),
                  ),
                  GoRoute(
                    path: 'logs',
                    builder: (context, state) =>
                        const AutoBookkeepingLogsPage(),
                  ),
                  GoRoute(
                    path: 'confirm',
                    builder: (context, state) =>
                        const AutoBookkeepingConfirmPage(),
                  ),
                ],
              ),
              GoRoute(
                path: 'recurring-bills',
                builder: (context, state) => RecurringBillsPage(
                  focusBillId: state.uri.queryParameters['billId'],
                ),
              ),
              GoRoute(
                path: 'receipt-ocr',
                builder: (context, state) => const ReceiptOcrPage(),
              ),
              GoRoute(
                path: 'bill-import',
                builder: (context, state) => const BillImportPage(),
              ),
              GoRoute(
                path: 'finance-center',
                builder: (context, state) => const FinanceCenterPage(),
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
              GoRoute(
                path: 'investments',
                builder: (context, state) => const InvestmentOverviewPage(),
                routes: [
                  // One route per class keeps the URL shareable and keeps the
                  // four classes on the exact same page implementation.
                  GoRoute(
                    path: 'holdings/:assetType',
                    builder: (context, state) => InvestmentOverviewPage(
                      initialTab: _assetType(state.pathParameters['assetType']),
                    ),
                  ),
                  // `detail` is a sibling of `:assetType`, never its child, so
                  // the two patterns cannot compete for the same segment.
                  GoRoute(
                    path: 'holdings/detail/:holdingId',
                    builder: (context, state) => InvestmentDetailPage(
                      holdingId: state.pathParameters['holdingId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => InvestmentAddPage(
                      initialType: _assetType(
                        state.uri.queryParameters['type'],
                      ),
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

/// Maps a route/query value onto an asset class, defaulting to 股票.
InvestmentAssetType _assetType(String? value) {
  if (value == null) return InvestmentAssetType.stock;
  return InvestmentAssetType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => InvestmentAssetType.stock,
  );
}

DateTime? _queryMonth(Uri uri) {
  final value = uri.queryParameters['month'];
  if (value == null || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value))
    return null;
  final month = DateTime.parse('$value-01');
  final now = DateTime.now();
  return month.isAfter(DateTime(now.year, now.month)) ? null : month;
}
