import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/budgets/domain/budget_period.dart';

void main() {
  test('annual aggregation uses saved monthly budgets, including unbudgeted spending', () {
    final result = calculate(
      BudgetPeriod.year(DateTime(2024)),
      budgets: [
        budget('2024-01', 1000),
        budget('2024-02', 2000),
        budget('2023-12', 9999),
        budget('2024-03', 9999, book: 'other'),
      ],
      transactions: [
        expense(100, DateTime(2024, 1, 5)),
        expense(300, DateTime(2024, 3, 5)),
        expense(200, DateTime(2023, 3, 5)),
        expense(999, DateTime(2025, 1, 1)),
      ],
    );
    expect(result.overview.total!.budget.amount, 3000);
    expect(result.spent, 400);
    expect(result.previousSpent, 200);
    expect(result.overview.total!.remaining, 2600);
    expect(result.overview.total!.dailyAvailable, 0); // Past year.
  });
  test(
    'custom range prorates leap-month budgets and goal reservations to cents',
    () {
      final range = BudgetPeriod(
        DateTime(2024, 2, 15),
        DateTime(2024, 3, 11),
        BudgetPeriodKind.custom,
      );
      final result = calculate(
        range,
        budgets: [budget('2024-02', 2900), budget('2024-03', 3100)],
        transactions: [expense(100, range.start), expense(999, range.end)],
        goals: [
          goal(290),
          goal(999, status: GoalStatus.paused),
        ],
      );
      expect(range.days, 25);
      expect(range.months, hasLength(2));
      expect(range.previous.end, range.start);
      expect(range.previous.days, range.days);
      expect(result.overview.total!.budget.amount, 2500);
      expect(result.spent, 100);
      expect(result.overview.total!.goalReservation, 243.55);
      expect(result.overview.total!.remaining, 2156.45);
      expect(range.contains(range.end), isFalse);
      expect(range.label, '2/15–3/10');
    },
  );
  test(
    'category ancestry and personal consumption preserve existing budget rules',
    () {
      final date = DateTime(2024, 5, 5);
      final parent = Category(
        id: 'parent',
        name: '餐饮',
        icon: 'food',
        type: CategoryType.expense,
        sortOrder: 0,
        isDefault: true,
        isArchived: true,
      );
      final child = Category(
        id: 'child',
        parentId: 'parent',
        name: '午饭',
        icon: 'food',
        type: CategoryType.expense,
        sortOrder: 0,
        isDefault: true,
        isArchived: false,
      );
      final result = calculate(
        BudgetPeriod.month(date),
        now: DateTime(2024, 5, 20),
        budgets: [
          budget('2024-05', 500),
          budget('2024-05', 300, category: 'parent'),
        ],
        categories: [parent, child],
        goals: [goal(100)],
        transactions: [
          expense(200, date).copyWith(
            categoryId: 'child',
            refundAmount: 20,
            refundStatus: RefundStatus.partial,
            reimbursementStatus: ReimbursementStatus.pending,
            reimbursementAmount: 30,
          ),
          expense(20, date).copyWith(categoryId: 'parent'),
          expense(999, date, book: 'other'),
          expense(999, date).copyWith(currency: 'USD'),
          expense(999, date).copyWith(deletedAt: date),
          expense(999, date).copyWith(type: TransactionType.assetPurchase),
          expense(999, DateTime(2024, 5, 25)),
        ],
      );
      expect(result.spent, 170);
      expect(result.overview.categories.single.used, 170);
      expect(result.overview.categories.single.category!.isArchived, isTrue);
      expect(result.overview.total!.remaining, 230);
      expect(result.overview.total!.percentage, .54);
      expect(result.overview.total!.remainingDays, 12);
      expect(result.overview.total!.dailyAvailable, closeTo(230 / 12, .001));
    },
  );
  test('invalid range fails; absent budgets never fabricate a total', () {
    expect(
      () =>
          BudgetPeriod(DateTime(2024), DateTime(2024), BudgetPeriodKind.custom),
      throwsArgumentError,
    );
    expect(
      calculate(BudgetPeriod.month(DateTime(2024))).overview.total,
      isNull,
    );
  });
}

BudgetPeriodOverview calculate(
  BudgetPeriod period, {
  List<Budget> budgets = const [],
  List<TransactionRecord> transactions = const [],
  List<Category> categories = const [],
  List<Goal> goals = const [],
  DateTime? now,
}) => const BudgetPeriodService().calculate(
  period: period,
  bookId: 'book-personal',
  now: now ?? DateTime(2026, 10, 4),
  budgets: budgets,
  transactions: transactions,
  categories: categories,
  goals: goals,
);
Budget budget(
  String month,
  double amount, {
  String? category,
  String book = 'book-personal',
}) => Budget(
  id: '$month-$category',
  bookId: book,
  monthKey: month,
  amount: amount,
  categoryId: category,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);
TransactionRecord expense(
  double amount,
  DateTime date, {
  String book = 'book-personal',
}) => TransactionRecord(
  id: 'tx-$date-$amount',
  bookId: book,
  type: TransactionType.expense,
  amount: amount,
  accountId: 'cash',
  occurredAt: date,
  createdAt: date,
  updatedAt: date,
);
Goal goal(double reservation, {GoalStatus status = GoalStatus.active}) => Goal(
  id: 'goal-$reservation',
  name: '旅行',
  icon: 'travel',
  targetAmount: 1000,
  currentAmount: 0,
  targetDate: DateTime(2027),
  status: status,
  createdAt: DateTime(2024),
  milestones: const [],
  monthlyReservation: reservation,
);
