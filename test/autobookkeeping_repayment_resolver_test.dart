import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_repayment_resolver.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';

void main() {
  test('repayment only matches owned debt accounts by suffix', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final repository = DriftAccountRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final now = DateTime(2026, 9, 20);
    await repository.create(
      Account(
        id: 'credit-4321',
        name: '招商信用卡',
        type: AccountType.creditCard,
        balance: -1000,
        currency: 'CNY',
        icon: 'credit_card',
        color: 0xff73963b,
        sortOrder: 10,
        isArchived: false,
        identifierSuffix: '4321',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final resolver = AutoBookkeepingRepaymentResolver(
      DriftAppSettingsRepository(database),
    );
    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'repayment-1',
      amountInCents: 50000,
      merchant: '招商银行信用卡 尾号4321',
      paymentMethod: '支付宝余额',
      timestamp: now,
      sourceApp: 'ALIPAY',
      scene: 'ALIPAY_REPAYMENT_SUCCESS',
      transactionType: 'REPAYMENT',
      targetIdentifierSuffix: '4321',
      targetAccountHint: '招商银行信用卡 尾号4321',
    );

    final recommendation = await resolver.recommend(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accounts: await repository.getActive(),
      sourceAccountId: SeedIds.alipayAccount,
    );
    expect(recommendation.destinationAccountId, 'credit-4321');
    expect(
      recommendation.evidence,
      AutoBookkeepingRepaymentEvidence.targetIdentifierSuffix,
    );
  });

  test('repayment never recommends a normal bank account with the same suffix', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final resolver = AutoBookkeepingRepaymentResolver(
      DriftAppSettingsRepository(database),
    );
    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'repayment-bank',
      amountInCents: 50000,
      merchant: '银行卡还款',
      paymentMethod: '支付宝余额',
      timestamp: DateTime(2026, 9, 20),
      sourceApp: 'ALIPAY',
      scene: 'ALIPAY_REPAYMENT_SUCCESS',
      transactionType: 'REPAYMENT',
      targetIdentifierSuffix: '7777',
      targetAccountHint: '银行卡 尾号7777',
    );
    final accounts = await DriftAccountRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getActive();

    final recommendation = await resolver.recommend(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accounts: accounts,
      sourceAccountId: SeedIds.alipayAccount,
    );
    expect(recommendation.hasDestination, isFalse);
  });

  test('confirmed repayment destination is learned for the same target', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final repository = DriftAccountRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    final now = DateTime(2026, 9, 20);
    await repository.create(
      Account(
        id: 'liability-company',
        name: '公司消费贷',
        type: AccountType.liability,
        balance: -3000,
        currency: 'CNY',
        icon: 'receipt_long',
        color: 0xff73963b,
        sortOrder: 11,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final resolver = AutoBookkeepingRepaymentResolver(
      DriftAppSettingsRepository(database),
    );
    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'repayment-learn',
      amountInCents: 30000,
      merchant: '公司消费贷',
      paymentMethod: '银行卡尾号7777',
      timestamp: now,
      sourceApp: 'UNIONPAY',
      scene: 'UNIONPAY_REPAYMENT_SUCCESS',
      transactionType: 'REPAYMENT',
    );

    await resolver.remember(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      destinationAccountId: 'liability-company',
      remember: true,
    );
    final recommendation = await resolver.recommend(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accounts: await repository.getActive(),
      sourceAccountId: SeedIds.bankAccount,
    );
    expect(recommendation.destinationAccountId, 'liability-company');
    expect(
      recommendation.evidence,
      AutoBookkeepingRepaymentEvidence.learnedDestination,
    );
  });
}
