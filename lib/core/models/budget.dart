import 'category.dart';

enum BudgetAlertStatus { normal, nearLimit, exceeded }

class Budget {
  const Budget({
    this.bookId = 'book-personal',
    required this.id,
    required this.monthKey,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
  });

  final String bookId;
  final String id;
  final String monthKey;
  final String? categoryId;
  final double amount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.used,
    required this.remaining,
    required this.percentage,
    required this.remainingDays,
    required this.dailyAvailable,
    required this.status,
    this.category,
    this.goalReservation = 0,
  });

  final Budget budget;
  final double goalReservation;
  final Category? category;
  final double used;
  final double remaining;
  final double percentage;
  final int remainingDays;
  final double dailyAvailable;
  final BudgetAlertStatus status;
}

class BudgetOverview {
  const BudgetOverview({required this.categories, this.total});

  final BudgetProgress? total;
  final List<BudgetProgress> categories;
}
