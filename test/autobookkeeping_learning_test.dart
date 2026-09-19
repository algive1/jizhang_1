import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_learning.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/intelligence/data/merchant_rule_repository.dart';
import 'package:jizhang_app/features/intelligence/domain/merchant_classification_service.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test('merchant confirmation is remembered for future auto bookkeeping', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final transactions = DriftTransactionRepository(database);
    final rules = DriftMerchantRuleRepository(
      database,
      transactions,
      const MerchantClassificationService(),
    );
    final learning = AutoBookkeepingLearningService(
      DriftAppSettingsRepository(database),
      rules,
    );
    final category = (await database.categoryDao.getActive()).firstWhere(
      (item) => item.type == 'expense' && item.bookId == SeedIds.personalBook,
    );
    final now = DateTime(2026, 9, 20, 12);
    final record = TransactionRecord(
      id: 'auto-learning-1',
      bookId: SeedIds.personalBook,
      userId: SeedIds.localUser,
      type: TransactionType.expense,
      amount: 28,
      accountId: SeedIds.alipayAccount,
      categoryId: category.id,
      merchant: '瑞幸咖啡',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      source: TransactionSource.auto,
    );
    await transactions.create(record);

    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'learning-1',
      amountInCents: 2800,
      merchant: '瑞幸咖啡',
      paymentMethod: '支付宝',
      timestamp: now,
      sourceApp: 'ALIPAY',
      scene: 'ALIPAY_PAYMENT_SUCCESS',
      transactionType: 'EXPENSE',
    );

    await learning.remember(
      transactionId: record.id,
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accountId: SeedIds.alipayAccount,
      categoryId: category.id,
      rememberForMerchant: true,
    );

    final recommendation = await learning.recommend(
      candidate: candidate,
      fallbackBookId: SeedIds.personalBook,
      transactionType: TransactionType.expense,
    );
    expect(recommendation.bookId, SeedIds.personalBook);
    expect(recommendation.accountId, SeedIds.alipayAccount);
    expect(recommendation.categoryId, category.id);
    expect(recommendation.useCount, 1);
    expect(recommendation.learnedFromMerchant, isTrue);

    final classification = await rules.classify(
      merchant: '支付宝 瑞幸咖啡',
      userId: SeedIds.localUser,
      transactionType: TransactionType.expense,
    );
    expect(classification.categoryId, category.id);
  });

  test('payment method mapping helps a new merchant choose account', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final transactions = DriftTransactionRepository(database);
    final rules = DriftMerchantRuleRepository(
      database,
      transactions,
      const MerchantClassificationService(),
    );
    final learning = AutoBookkeepingLearningService(
      DriftAppSettingsRepository(database),
      rules,
    );
    final category = (await database.categoryDao.getActive()).firstWhere(
      (item) => item.type == 'expense' && item.bookId == SeedIds.personalBook,
    );
    final now = DateTime(2026, 9, 20, 12);
    final first = PendingAutoBookkeepingCandidate(
      fingerprint: 'mapping-1',
      amountInCents: 1800,
      merchant: '测试餐厅A',
      paymentMethod: '支付宝',
      timestamp: now,
      sourceApp: 'MEITUAN',
      scene: 'MEITUAN_PAYMENT_SUCCESS',
      transactionType: 'EXPENSE',
    );
    final record = TransactionRecord(
      id: 'auto-mapping-1',
      bookId: SeedIds.personalBook,
      userId: SeedIds.localUser,
      type: TransactionType.expense,
      amount: 18,
      accountId: SeedIds.alipayAccount,
      categoryId: category.id,
      merchant: first.merchant,
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      source: TransactionSource.auto,
    );
    await transactions.create(record);
    await learning.remember(
      transactionId: record.id,
      candidate: first,
      bookId: SeedIds.personalBook,
      accountId: SeedIds.alipayAccount,
      categoryId: category.id,
      rememberForMerchant: true,
    );

    final second = PendingAutoBookkeepingCandidate(
      fingerprint: 'mapping-2',
      amountInCents: 2200,
      merchant: '完全不同的新商户',
      paymentMethod: '支付宝',
      timestamp: now.add(const Duration(minutes: 5)),
      sourceApp: 'MEITUAN',
      scene: 'MEITUAN_PAYMENT_SUCCESS',
      transactionType: 'EXPENSE',
    );
    final recommendation = await learning.recommend(
      candidate: second,
      fallbackBookId: SeedIds.personalBook,
      transactionType: TransactionType.expense,
    );
    expect(recommendation.accountId, SeedIds.alipayAccount);
    expect(recommendation.learnedFromMerchant, isFalse);
  });

  test('disabled merchant memory does not persist a personal preference', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final transactions = DriftTransactionRepository(database);
    final learning = AutoBookkeepingLearningService(
      DriftAppSettingsRepository(database),
      DriftMerchantRuleRepository(
        database,
        transactions,
        const MerchantClassificationService(),
      ),
    );
    final category = (await database.categoryDao.getActive()).firstWhere(
      (item) => item.type == 'expense' && item.bookId == SeedIds.personalBook,
    );
    final now = DateTime(2026, 9, 20, 12);
    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'no-memory',
      amountInCents: 1200,
      merchant: '不记忆商户',
      paymentMethod: '微信支付',
      timestamp: now,
      sourceApp: 'WECHAT',
      scene: 'WECHAT_PAYMENT_SUCCESS',
      transactionType: 'EXPENSE',
    );

    await learning.remember(
      transactionId: 'does-not-need-to-exist',
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accountId: SeedIds.wechatAccount,
      categoryId: category.id,
      rememberForMerchant: false,
    );

    final raw = await DriftAppSettingsRepository(
      database,
    ).get(AutoBookkeepingLearningService.preferenceKey);
    expect(raw, isNull);
  });
}
