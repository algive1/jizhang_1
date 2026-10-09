import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/budgets/application/budget_alert_notification_service.dart';
import 'package:jizhang_app/features/budgets/application/budget_weekly_review_service.dart';
import 'package:jizhang_app/features/budgets/data/budget_preferences_repository.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test('preferences persist per book, concurrent fields survive, failed writes roll back', () async {
    final settings = MemorySettings();
    ProviderContainer container(String book) => ProviderContainer(
      overrides: [
        activeBookIdProvider.overrideWith(() => FixedBook(book)),
        appSettingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    final first = container('first');
    addTearDown(first.dispose);
    await first.read(budgetPreferencesProvider.future);
    final controller = first.read(budgetPreferencesProvider.notifier);
    await Future.wait([
      controller.setEnabled(BudgetPreference.overspend, false),
      controller.setEnabled(BudgetPreference.smartAdvice, false),
    ]);
    expect(first.read(budgetPreferencesProvider).value!.overspend, isFalse);
    expect(first.read(budgetPreferencesProvider).value!.smartAdvice, isFalse);
    final reopened = container('first'), other = container('other');
    addTearDown(reopened.dispose);
    addTearDown(other.dispose);
    expect(
      (await reopened.read(budgetPreferencesProvider.future)).overspend,
      isFalse,
    );
    expect(
      (await other.read(budgetPreferencesProvider.future)).overspend,
      isTrue,
    );
    settings.fail = true;
    await expectLater(
      controller.setEnabled(BudgetPreference.weeklyReview, false),
      throwsStateError,
    );
    expect(first.read(budgetPreferencesProvider).value!.weeklyReview, isTrue);
    expect(first.read(budgetPreferencesProvider).value!.smartAdvice, isFalse);
  });
  test('weekly report saves without permission, notifies once after grant, preserves book scope', () async {
    final settings = MemorySettings(), bridge = FakeBridge()..granted = false;
    final service = BudgetWeeklyReviewService(settings, bridge);
    final date = DateTime(2026, 9, 22);
    final repo = FakeTransactions([
      tx(
        100,
        date,
      ).copyWith(refundAmount: 10, refundStatus: RefundStatus.partial),
      tx(200, date).copyWith(
        reimbursementAmount: 150,
        reimbursementStatus: ReimbursementStatus.pending,
      ),
      tx(1000, date).copyWith(type: TransactionType.income),
      tx(999, date, book: 'other'),
      tx(999, DateTime(2026, 9, 28)),
      tx(999, date).copyWith(currency: 'USD'),
      tx(999, date).copyWith(deletedAt: date),
      tx(999, date).copyWith(type: TransactionType.transfer),
    ]);
    Future<void> sync() => service.sync(
      bookId: 'book-personal',
      transactions: repo,
      now: DateTime(2026, 10, 4),
    );
    await sync();
    await sync();
    final reports = await service.load('book-personal');
    expect(reports, hasLength(1));
    expect(reports.single.spent, 140);
    expect(reports.single.income, 1000);
    expect(reports.single.count, 2);
    expect(reports.single.start, DateTime(2026, 9, 21));
    expect(reports.single.end, DateTime(2026, 9, 28));
    expect(bridge.routes, isEmpty);
    bridge.granted = true;
    await Future.wait([sync(), sync()]);
    expect(bridge.routes, hasLength(1));
    expect(bridge.routes.single, contains('review=1&bookId=book-personal'));
    expect(await service.load('other'), isEmpty);
  });
  test(
    'disabled review produces nothing and re-enabling can generate the report',
    () async {
      final settings = MemorySettings(), bridge = FakeBridge();
      final key = budgetPreferenceKey(
        'book-personal',
        BudgetPreference.weeklyReview,
      );
      settings.values[key] = '0';
      final service = BudgetWeeklyReviewService(settings, bridge);
      final repo = FakeTransactions([tx(25, DateTime(2026, 9, 22))]);
      await service.sync(
        bookId: 'book-personal',
        transactions: repo,
        now: DateTime(2026, 10, 4),
      );
      expect(await service.load('book-personal'), isEmpty);
      expect(bridge.routes, isEmpty);
      settings.values[key] = '1';
      await service.sync(
        bookId: 'book-personal',
        transactions: repo,
        now: DateTime(2026, 10, 4),
      );
      expect(await service.load('book-personal'), hasLength(1));
      settings.values['budget.weekly.bad.reports'] = '{broken';
      expect(await service.load('bad'), isEmpty);
    },
  );
  test('disabled overspend does not consume notification threshold', () async {
    final settings = MemorySettings(), bridge = FakeBridge();
    final key = budgetPreferenceKey(
      'book-personal',
      BudgetPreference.overspend,
    );
    final service = BudgetAlertNotificationService(settings, bridge);
    final budget = Budget(
      id: 'total',
      monthKey: '2026-10',
      amount: 100,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final data = BudgetOverview(
      total: BudgetProgress(
        budget: budget,
        used: 85,
        remaining: 15,
        percentage: .85,
        remainingDays: 20,
        dailyAvailable: .75,
        status: BudgetAlertStatus.nearLimit,
      ),
      categories: [],
    );
    settings.values[key] = '0';
    await service.sync(data);
    expect(bridge.routes, isEmpty);
    settings.values[key] = '1';
    await service.sync(data);
    expect(bridge.routes, hasLength(1));
  });
}

class FixedBook extends ActiveBookIdController {
  FixedBook(this.id);
  final String id;
  @override
  String build() => id;
}

class MemorySettings implements AppSettingsRepository {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> get(String key) async => values[key];
  @override
  Future<void> set(String key, String value) async {
    if (fail) throw StateError('disk');
    values[key] = value;
  }
}

class FakeBridge implements BudgetNotificationBridge {
  bool granted = true;
  final routes = <String>[];
  @override
  Future<bool> isGranted() async => granted;
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String route,
  }) async {
    routes.add(route);
  }
}

class FakeTransactions implements TransactionRepository {
  FakeTransactions(this.rows);
  final List<TransactionRecord> rows;
  @override
  Future<List<TransactionRecord>> getRange({
    required DateTime start,
    required DateTime endExclusive,
  }) async => rows;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TransactionRecord tx(
  double amount,
  DateTime date, {
  String book = 'book-personal',
}) => TransactionRecord(
  id: '$date-$amount',
  bookId: book,
  type: TransactionType.expense,
  amount: amount,
  categoryName: '餐饮',
  accountId: 'cash',
  occurredAt: date,
  createdAt: date,
  updatedAt: date,
);
