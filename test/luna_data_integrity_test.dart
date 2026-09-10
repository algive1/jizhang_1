import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/widgets/money_text.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/intelligence/domain/transaction_fingerprint_service.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test('post-commit settings failure reports committed records', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final service = QuickBookkeepingService(
      transactions,
      const _FailingSettingsRepository(),
    );

    await expectLater(
      service.save(
        QuickBookkeepingRequest(
          type: TransactionType.expense,
          amount: 12,
          accountId: SeedIds.cashAccount,
          categoryId: 'expense-food',
          occurredAt: DateTime(2026, 9, 7),
        ),
      ),
      throwsA(
        isA<BookkeepingCommittedException>().having(
          (error) => error.records,
          'records',
          hasLength(1),
        ),
      ),
    );
    expect(await transactions.getAll(), hasLength(1));
  });

  test(
    'editing metadata clears known fields and preserves extended fields',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      final service = QuickBookkeepingService(
        transactions,
        DriftAppSettingsRepository(database),
      );
      final saved = await service.save(
        QuickBookkeepingRequest(
          type: TransactionType.expense,
          amount: 12,
          accountId: SeedIds.cashAccount,
          categoryId: 'expense-food',
          subcategoryId: 'expense-food',
          isLargeTransaction: true,
          occurredAt: DateTime(2026, 9, 7),
          tags: const ['外卖'],
          attachmentPaths: const ['/tmp/bill.jpg'],
        ),
      );
      await service.update(
        saved,
        QuickBookkeepingRequest(
          type: TransactionType.expense,
          amount: 12,
          accountId: SeedIds.cashAccount,
          categoryId: 'expense-food',
          occurredAt: saved.occurredAt,
        ),
      );
      final updated = (await transactions.getAll()).single;
      expect(updated.subcategoryId, 'expense-food');
      expect(updated.isLargeTransaction, isTrue);
      expect(updated.metadataJson, contains('"tags":[]'));
      expect(updated.metadataJson, contains('"attachments":[]'));
    },
  );

  test('parent budget includes both child storage shapes once', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final parent = Category(
      id: 'food',
      name: '餐饮',
      icon: 'restaurant',
      type: CategoryType.expense,
      sortOrder: 0,
      isDefault: true,
      isArchived: false,
    );
    final child = Category(
      id: 'food-delivery',
      parentId: 'food',
      name: '外卖',
      icon: 'takeout',
      type: CategoryType.expense,
      sortOrder: 1,
      isDefault: true,
      isArchived: false,
    );
    final now = DateTime(2026, 9, 7);
    final overview = DriftBudgetRepository(
      database,
      const SafeToSpendService(),
    );
    final result = overview.calculateOverview(
      budgets: [
        Budget(
          id: 'budget-food',
          monthKey: budgetMonthKey(now),
          categoryId: 'food',
          amount: 100,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      transactions: [
        _transaction('root', 10, categoryId: 'food'),
        _transaction('child-direct', 20, categoryId: 'food-delivery'),
        _transaction(
          'child-explicit',
          30,
          categoryId: 'food',
          subcategoryId: 'food-delivery',
        ),
      ],
      categories: [parent, child],
      now: now,
    );
    expect(result.categories.single.used, 60);
  });

  testWidgets('money text keeps a negative balance sign by default', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MoneyText(-12.5)));
    expect(find.text('- ¥12.50'), findsOneWidget);
  });

  test('fingerprints do not cross books or currencies', () {
    const service = TransactionFingerprintService();
    final left = _transaction('left', 10, bookId: 'book-a');
    final otherBook = _transaction('other-book', 10, bookId: 'book-b');
    final otherCurrency = _transaction('other-currency', 10, currency: 'USD');
    expect(service.compare(left, otherBook).confidence, 0);
    expect(service.compare(left, otherCurrency).confidence, 0);
  });

  test(
    'calendar month comparison does not include a shorter prior month tail',
    () {
      const service = StatisticalAnalysisService();
      final snapshot = service.analyze([
        _transaction('feb-start', 10, occurredAt: DateTime(2026, 2, 1)),
      ], now: DateTime(2026, 3, 31));
      expect(snapshot.previousRegularExpense, 10);
    },
  );
}

TransactionRecord _transaction(
  String id,
  double amount, {
  String bookId = 'book-personal',
  String currency = 'CNY',
  String? categoryId,
  String? subcategoryId,
  DateTime? occurredAt,
}) {
  final date = occurredAt ?? DateTime(2026, 9, 7);
  return TransactionRecord(
    id: id,
    bookId: bookId,
    type: TransactionType.expense,
    amount: amount,
    currency: currency,
    accountId: 'cash',
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    occurredAt: date,
    createdAt: date,
    updatedAt: date,
  );
}

class _FailingSettingsRepository implements AppSettingsRepository {
  const _FailingSettingsRepository();

  @override
  Future<String?> get(String key) async => null;

  @override
  Future<void> set(String key, String value) =>
      Future.error(StateError('settings failed'));
}
