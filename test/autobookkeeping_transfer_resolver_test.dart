import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_transfer_resolver.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';

void main() {
  test('transfer scene does not become internal transfer without strong evidence', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final resolver = AutoBookkeepingTransferResolver(
      DriftAppSettingsRepository(database),
    );
    final accounts = await DriftAccountRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getActive();
    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'transfer-no-evidence',
      amountInCents: 8800,
      merchant: '张三',
      paymentMethod: '微信支付',
      timestamp: DateTime(2026, 9, 20, 10),
      sourceApp: 'WECHAT',
      scene: 'WECHAT_TRANSFER_SUCCESS',
      transactionType: 'TRANSFER',
    );

    final recommendation = await resolver.recommend(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accounts: accounts,
      sourceAccountId: SeedIds.wechatAccount,
    );

    expect(recommendation.suggestsInternalTransfer, isFalse);
    expect(recommendation.destinationAccountId, isNull);
    expect(recommendation.evidence, AutoBookkeepingTransferEvidence.none);
  });

  test('unique target suffix suggests a different owned account', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final resolver = AutoBookkeepingTransferResolver(
      DriftAppSettingsRepository(database),
    );
    final accounts = await DriftAccountRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getActive();
    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'transfer-bank-target',
      amountInCents: 12000,
      merchant: '本人银行卡',
      paymentMethod: '微信支付',
      timestamp: DateTime(2026, 9, 20, 10),
      sourceApp: 'WECHAT',
      scene: 'WECHAT_TRANSFER_SUCCESS',
      transactionType: 'TRANSFER',
      targetIdentifierSuffix: '7777',
      targetAccountHint: '招商银行储蓄卡 尾号7777',
    );

    final recommendation = await resolver.recommend(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accounts: accounts,
      sourceAccountId: SeedIds.wechatAccount,
    );

    expect(recommendation.suggestsInternalTransfer, isTrue);
    expect(recommendation.destinationAccountId, SeedIds.bankAccount);
    expect(
      recommendation.evidence,
      AutoBookkeepingTransferEvidence.targetIdentifierSuffix,
    );
  });

  test('confirmed internal destination is learned and external correction clears it', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final resolver = AutoBookkeepingTransferResolver(
      DriftAppSettingsRepository(database),
    );
    final accounts = await DriftAccountRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getActive();
    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'learn-transfer',
      amountInCents: 5000,
      merchant: '我的工资卡',
      paymentMethod: '支付宝',
      timestamp: DateTime(2026, 9, 20, 11),
      sourceApp: 'ALIPAY',
      scene: 'ALIPAY_TRANSFER_SUCCESS',
      transactionType: 'TRANSFER',
    );

    await resolver.rememberDecision(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      internalTransfer: true,
      destinationAccountId: SeedIds.bankAccount,
      remember: true,
    );
    final learned = await resolver.recommend(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accounts: accounts,
      sourceAccountId: SeedIds.alipayAccount,
    );
    expect(learned.destinationAccountId, SeedIds.bankAccount);
    expect(
      learned.evidence,
      AutoBookkeepingTransferEvidence.learnedDestination,
    );

    await resolver.rememberDecision(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      internalTransfer: false,
      destinationAccountId: null,
      remember: true,
    );
    final cleared = await resolver.recommend(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accounts: accounts,
      sourceAccountId: SeedIds.alipayAccount,
    );
    expect(cleared.suggestsInternalTransfer, isFalse);
  });

  test('target suffix never suggests the same account as source', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final resolver = AutoBookkeepingTransferResolver(
      DriftAppSettingsRepository(database),
    );
    final accounts = await DriftAccountRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getActive();
    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'same-source-suffix',
      amountInCents: 3000,
      merchant: '某收款人',
      paymentMethod: '微信支付',
      timestamp: DateTime(2026, 9, 20, 11),
      sourceApp: 'WECHAT',
      scene: 'WECHAT_TRANSFER_SUCCESS',
      transactionType: 'TRANSFER',
      targetIdentifierSuffix: '3316',
      targetAccountHint: '微信账户 尾号3316',
    );

    final recommendation = await resolver.recommend(
      candidate: candidate,
      bookId: SeedIds.personalBook,
      accounts: accounts,
      sourceAccountId: SeedIds.wechatAccount,
    );
    expect(recommendation.suggestsInternalTransfer, isFalse);
  });
}
