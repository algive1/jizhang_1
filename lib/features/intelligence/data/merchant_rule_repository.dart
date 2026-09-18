import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/database_seeder.dart';
import '../../../core/models/transaction_intelligence.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/models/family.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/merchant_classification_service.dart';

abstract interface class MerchantRuleRepository {
  Future<List<MerchantRule>> getRules({String bookId = SeedIds.personalBook});
  Future<ClassificationResult> classify({
    required String? merchant,
    required String? userId,
    required TransactionType transactionType,
    String bookId = SeedIds.personalBook,
  });
  Future<void> correctTransaction({
    required String transactionId,
    required String categoryId,
    String? subcategoryId,
    required bool rememberForMerchant,
  });
}

class DriftMerchantRuleRepository implements MerchantRuleRepository {
  DriftMerchantRuleRepository(
    this._database,
    this._transactions,
    this._classifier,
  );

  final AppDatabase _database;
  final TransactionRepository _transactions;
  final MerchantClassificationService _classifier;

  @override
  Future<List<MerchantRule>> getRules({
    String bookId = SeedIds.personalBook,
  }) async {
    final rows = await (_database.select(
      _database.merchantRuleEntries,
    )..where((r) => r.bookId.equals(bookId))).get();
    return rows.map(_fromEntity).toList(growable: false);
  }

  @override
  Future<ClassificationResult> classify({
    required String? merchant,
    required String? userId,
    required TransactionType transactionType,
    String bookId = SeedIds.personalBook,
  }) async {
    final book = await _database.familyDao.findBook(bookId);
    final type = book == null
        ? BookType.personal
        : BookType.values.byName(book.type);
    String seeded(String key) => scopedSeedId(
      bookId,
      type == BookType.personal ? key : '${type.name}-$key',
    );
    final defaultCategory = switch (transactionType) {
      TransactionType.income ||
      TransactionType.refund ||
      TransactionType.reimbursement ||
      TransactionType.borrow => seeded('income-other'),
      TransactionType.transfer ||
      TransactionType.repayment ||
      TransactionType.adjustment ||
      TransactionType.assetSale => null,
      _ => seeded('expense-other'),
    };
    final categoryExists = defaultCategory == null
        ? false
        : await _database.categoryDao.findById(defaultCategory) != null;
    final activeRules = <MerchantRule>[];
    for (final rule in await getRules(bookId: bookId)) {
      final category = await _database.categoryDao.findById(rule.categoryId);
      if (category != null && !category.isArchived) activeRules.add(rule);
    }
    return _classifier.classify(
      merchant: merchant,
      rules: activeRules,
      userId: userId,
      defaultCategoryId: categoryExists ? defaultCategory : null,
    );
  }

  @override
  Future<void> correctTransaction({
    required String transactionId,
    required String categoryId,
    String? subcategoryId,
    required bool rememberForMerchant,
  }) async {
    if (await _database.categoryDao.findById(categoryId) == null) {
      throw StateError('Category $categoryId does not exist');
    }
    final transactions = await _transactions.getAll();
    final transaction = transactions
        .where((item) => item.id == transactionId)
        .firstOrNull;
    if (transaction == null) {
      throw StateError('Transaction $transactionId does not exist');
    }
    final category = await _database.categoryDao.findById(categoryId);
    if (category!.bookId != transaction.bookId)
      throw ArgumentError('分类不属于流水账本');
    final now = DateTime.now();
    await _transactions.update(
      transaction.copyWith(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        userCorrected: true,
        updatedAt: now,
      ),
    );
    final merchant = transaction.merchant?.trim();
    if (!rememberForMerchant || merchant == null || merchant.isEmpty) return;

    final normalized = _classifier.normalizer.normalize(merchant);
    final rules = await getRules(bookId: transaction.bookId);
    final existing = rules
        .where(
          (rule) =>
              rule.userId == transaction.userId &&
              rule.source == MerchantRuleSource.userCorrection &&
              rule.normalizedPattern == normalized,
        )
        .firstOrNull;
    await _database.intelligenceDao.upsertMerchantRule(
      MerchantRuleEntriesCompanion.insert(
        id: existing?.id ?? 'merchant-rule-${now.microsecondsSinceEpoch}',
        bookId: Value(transaction.bookId),
        merchantPattern: merchant,
        normalizedPattern: normalized,
        matchType: MerchantRuleMatchType.exact.name,
        categoryId: categoryId,
        subcategoryId: Value(subcategoryId),
        userId: Value(transaction.userId),
        confidence: 1,
        source: MerchantRuleSource.userCorrection.name,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  MerchantRule _fromEntity(MerchantRuleEntity entity) {
    return MerchantRule(
      id: entity.id,
      merchantPattern: entity.merchantPattern,
      normalizedPattern: entity.normalizedPattern,
      matchType: MerchantRuleMatchType.values.byName(entity.matchType),
      categoryId: entity.categoryId,
      subcategoryId: entity.subcategoryId,
      userId: entity.userId,
      confidence: entity.confidence,
      source: MerchantRuleSource.values.byName(entity.source),
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}

final merchantClassificationServiceProvider = Provider(
  (ref) => const MerchantClassificationService(),
);

final merchantRuleRepositoryProvider = Provider<MerchantRuleRepository>((ref) {
  return DriftMerchantRuleRepository(
    ref.watch(databaseProvider),
    DriftTransactionRepository(ref.watch(databaseProvider)),
    ref.watch(merchantClassificationServiceProvider),
  );
});
