import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/transaction_record.dart';
import '../../books/data/book_repository.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/budget_preferences_repository.dart';
import 'budget_alert_notification_service.dart';

class BudgetWeeklyReview {
  const BudgetWeeklyReview({
    required this.start,
    required this.end,
    required this.spent,
    required this.income,
    required this.count,
    required this.topCategory,
    required this.topAmount,
  });
  final DateTime start;
  final DateTime end;
  final double spent;
  final double income;
  final int count;
  final String topCategory;
  final double topAmount;
  String get id => '${start.year}-${start.month}-${start.day}';
  String get title =>
      '${start.month}月${start.day}日—'
      '${DateTime(end.year, end.month, end.day - 1).month}月'
      '${DateTime(end.year, end.month, end.day - 1).day}日';
  Map<String, Object> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'spent': spent,
    'income': income,
    'count': count,
    'topCategory': topCategory,
    'topAmount': topAmount,
  };
  factory BudgetWeeklyReview.fromJson(Map<String, dynamic> value) =>
      BudgetWeeklyReview(
        start: DateTime.parse(value['start'] as String),
        end: DateTime.parse(value['end'] as String),
        spent: (value['spent'] as num).toDouble(),
        income: (value['income'] as num).toDouble(),
        count: value['count'] as int,
        topCategory: value['topCategory'] as String,
        topAmount: (value['topAmount'] as num).toDouble(),
      );
}

class BudgetWeeklyReviewService {
  BudgetWeeklyReviewService(this.settings, this.notifications);
  final AppSettingsRepository settings;
  final BudgetNotificationBridge notifications;
  Future<void> _tail = Future.value();

  Future<List<BudgetWeeklyReview>> load(String bookId) async {
    final raw = await settings.get('budget.weekly.$bookId.reports');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map(
            (value) => BudgetWeeklyReview.fromJson(
              (value as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> sync({
    required String bookId,
    required TransactionRepository transactions,
    DateTime? now,
  }) {
    final next = _tail
        .catchError((Object _) {})
        .then((_) => _sync(bookId, transactions, now ?? DateTime.now()));
    _tail = next;
    return next;
  }

  Future<void> _sync(
    String bookId,
    TransactionRepository transactions,
    DateTime now,
  ) async {
    if (await settings.get(
          budgetPreferenceKey(bookId, BudgetPreference.weeklyReview),
        ) ==
        '0')
      return;
    final end = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final start = DateTime(end.year, end.month, end.day - 7);
    final reports = await load(bookId);
    var report = reports.where((r) => r.start == start).firstOrNull;
    if (report == null) {
      final rows =
          (await transactions.getRange(start: start, endExclusive: end))
              .where(
                (t) =>
                    t.bookId == bookId &&
                    t.deletedAt == null &&
                    t.currency.toUpperCase() == 'CNY' &&
                    !t.occurredAt.isBefore(start) &&
                    t.occurredAt.isBefore(end),
              )
              .toList();
      final expenses = rows.where((t) => t.isConsumptionExpense).toList();
      final incomes = rows
          .where((t) => t.type == TransactionType.income)
          .toList();
      if (expenses.isEmpty && incomes.isEmpty) return;
      final byCategory = <String, int>{};
      var spent = 0;
      for (final row in expenses) {
        final cents = (row.personalExpenseAmount * 100).round();
        spent += cents;
        byCategory.update(
          row.categoryName ?? '其他',
          (value) => value + cents,
          ifAbsent: () => cents,
        );
      }
      final ranked = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      report = BudgetWeeklyReview(
        start: start,
        end: end,
        spent: spent / 100,
        income:
            incomes.fold<int>(0, (sum, t) => sum + (t.amount * 100).round()) /
            100,
        count: expenses.length,
        topCategory: ranked.firstOrNull?.key ?? '暂无支出',
        topAmount: (ranked.firstOrNull?.value ?? 0) / 100,
      );
      reports.removeWhere((r) => r.start == start);
      reports.insert(0, report);
      await settings.set(
        'budget.weekly.$bookId.reports',
        jsonEncode(reports.take(12).map((r) => r.toJson()).toList()),
      );
    }
    final notifiedKey = 'budget.weekly.$bookId.notified.${report.id}';
    if (await settings.get(notifiedKey) == '1' ||
        !await notifications.isGranted())
      return;
    // Recheck after IO so switching off while generating a report is respected.
    if (await settings.get(
          budgetPreferenceKey(bookId, BudgetPreference.weeklyReview),
        ) ==
        '0')
      return;
    await notifications.show(
      id: 'budget-weekly-$bookId-${report.id}',
      title: '每周复盘已生成',
      body:
          '${report.title}，共 ${report.count} 笔消费，'
          '支出 ¥${MoneyFormatter.decimal(report.spent)}。点击查看汇总。',
      route: '/profile/budgets?review=1&bookId=${Uri.encodeComponent(bookId)}',
    );
    await settings.set(notifiedKey, '1');
  }
}

final budgetWeeklyReviewServiceProvider = Provider<BudgetWeeklyReviewService>(
  (ref) => BudgetWeeklyReviewService(
    ref.watch(appSettingsRepositoryProvider),
    ref.watch(budgetNotificationBridgeProvider),
  ),
);

final budgetWeeklyReviewsProvider =
    FutureProvider.autoDispose<List<BudgetWeeklyReview>>((ref) async {
      final bookId = ref.watch(activeBookIdProvider);
      ref.watch(budgetPreferencesProvider);
      await ref.watch(databaseBootstrapProvider.future);
      final service = ref.watch(budgetWeeklyReviewServiceProvider);
      await service.sync(
        bookId: bookId,
        transactions: ref.watch(transactionRepositoryProvider),
      );
      return service.load(bookId);
    });
