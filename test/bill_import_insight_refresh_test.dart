import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/insights/application/insight_feed_provider.dart';
import 'package:jizhang_app/features/insights/data/insight_preferences_repository.dart';
import 'package:jizhang_app/features/insights/domain/insight_models.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test(
    'imported full-month history recalculates budget recommendation',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();

      final personalFood = (await DriftCategoryRepository(
        database,
        bookId: SeedIds.personalBook,
      ).getAll()).firstWhere((category) => category.name == '餐饮');
      // Another ledger already has recommendation-ready history. It must not
      // influence the active personal ledger's suggestion.
      final familyBook = await DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      ).create(name: '家庭账本', type: BookType.family);
      await DriftTransactionRepository(
        database,
        bookId: familyBook.id,
      ).createAll(
        _monthTransactions(
              bookId: familyBook.id,
              accountId: scopedSeedId(familyBook.id, SeedIds.cashAccount),
              categoryId: null,
              month: 6,
              total: 420,
              prefix: 'family-june',
            ) +
            _monthTransactions(
              bookId: familyBook.id,
              accountId: scopedSeedId(familyBook.id, SeedIds.cashAccount),
              categoryId: null,
              month: 7,
              total: 440,
              prefix: 'family-july',
            ) +
            _monthTransactions(
              bookId: familyBook.id,
              accountId: scopedSeedId(familyBook.id, SeedIds.cashAccount),
              categoryId: null,
              month: 8,
              total: 440,
              prefix: 'family-august',
            ),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          insightPreferencesProvider.overrideWith(
            (ref) async => const InsightPreferences(
              intents: {BookkeepingIntent.controlSpending},
              focus: {InsightFocus.dining},
              configured: true,
            ),
          ),
          confirmedInsightFeedProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      final transactionSubscription = container.listen(
        transactionsProvider,
        (previous, next) {},
      );
      final budgetSubscription = container.listen(
        currentMonthBudgetsProvider,
        (previous, next) {},
      );
      final categorySubscription = container.listen(
        allCategoriesProvider,
        (previous, next) {},
      );
      final insightSubscription = container.listen(
        localInsightFeedProvider,
        (previous, next) {},
      );
      addTearDown(transactionSubscription.close);
      addTearDown(budgetSubscription.close);
      addTearDown(categorySubscription.close);
      addTearDown(insightSubscription.close);

      await container.read(transactionsProvider.future);
      await container.read(insightPreferencesProvider.future);
      await container.read(allCategoriesProvider.future);
      await container.read(currentMonthBudgetsProvider.future);
      await container.pump();
      final beforeImport = container.read(localInsightFeedProvider);
      expect(
        beforeImport.items.any(
          (item) =>
              item.id == 'budget:recommendation:category:${personalFood.id}',
        ),
        isFalse,
        reason: 'History in another ledger must not drive this recommendation.',
      );

      final importRequests = [
        for (final month in [6, 7, 8])
          for (final transaction in _monthTransactions(
            bookId: SeedIds.personalBook,
            accountId: scopedSeedId(SeedIds.personalBook, SeedIds.cashAccount),
            categoryId: personalFood.id,
            month: month,
            total: month == 6 ? 420 : 440,
            prefix: 'imported-$month',
          ))
            QuickBookkeepingRequest(
              type: transaction.type,
              amount: transaction.amount,
              accountId: transaction.accountId,
              bookId: transaction.bookId,
              occurredAt: transaction.occurredAt,
              categoryId: transaction.categoryId,
              categoryName: '餐饮',
              source: TransactionSource.import,
              isOneTime: false,
            ),
      ];
      await QuickBookkeepingService(
        DriftTransactionRepository(database, bookId: SeedIds.personalBook),
        DriftAppSettingsRepository(database),
      ).saveAll(importRequests);

      // This is the refresh performed by BillImportPage after saveAll commits.
      container.invalidate(transactionsProvider);
      await container.read(transactionsProvider.future);
      await container.pump();
      final afterImport = container.read(localInsightFeedProvider);
      final recommendation = afterImport.items.firstWhere(
        (item) =>
            item.id == 'budget:recommendation:category:${personalFood.id}',
      );

      expect(recommendation.amount, inInclusiveRange(350, 420));
      final personalTransactions = DriftTransactionRepository(
        database,
        bookId: SeedIds.personalBook,
      );
      expect(
        (await personalTransactions.getAll()).where(
          (item) => item.source == TransactionSource.import,
        ),
        hasLength(24),
      );
    },
  );
}

List<TransactionRecord> _monthTransactions({
  required String bookId,
  required String accountId,
  required String? categoryId,
  required int month,
  required double total,
  required String prefix,
}) {
  return [
    for (var index = 0; index < 8; index++)
      TransactionRecord(
        id: '$prefix-$index',
        bookId: bookId,
        type: TransactionType.expense,
        amount: total / 8,
        accountId: accountId,
        categoryId: categoryId,
        categoryName: '餐饮',
        occurredAt: DateTime(2026, month, 3 + index),
        createdAt: DateTime(2026, month, 3 + index),
        updatedAt: DateTime(2026, month, 3 + index),
        source: TransactionSource.import,
        isOneTime: false,
      ),
  ];
}
