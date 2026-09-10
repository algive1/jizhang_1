import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_intelligence.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/intelligence/application/transaction_intelligence_service.dart';
import 'package:jizhang_app/features/intelligence/data/bill_inbox_repository.dart';
import 'package:jizhang_app/features/intelligence/data/economic_event_repository.dart';
import 'package:jizhang_app/features/intelligence/data/merchant_rule_repository.dart';
import 'package:jizhang_app/features/intelligence/domain/merchant_classification_service.dart';
import 'package:jizhang_app/features/intelligence/domain/transaction_fingerprint_service.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  group('classification priority', () {
    const classifier = MerchantClassificationService();
    final now = DateTime(2026, 8, 31);
    final rules = [
      _rule(
        'keyword',
        '雅迪',
        'food',
        MerchantRuleSource.keyword,
        MerchantRuleMatchType.keyword,
        now,
      ),
      _rule(
        'exact',
        '雅迪',
        'shopping',
        MerchantRuleSource.exactMerchant,
        MerchantRuleMatchType.exact,
        now,
      ),
      _rule(
        'personal',
        '雅迪',
        'transport',
        MerchantRuleSource.userCorrection,
        MerchantRuleMatchType.exact,
        now,
        userId: 'user',
      ),
    ];

    test('personal rule overrides exact, keyword and default categories', () {
      final result = classifier.classify(
        merchant: '支付宝-雅迪',
        rules: rules,
        userId: 'user',
        defaultCategoryId: 'other',
      );
      expect(result.categoryId, 'transport');
      expect(result.source, ClassificationSource.personalRule);
    });

    test(
      'unknown merchant uses default then pending when no default exists',
      () {
        expect(
          classifier
              .classify(
                merchant: '未知商户',
                rules: rules,
                userId: 'user',
                defaultCategoryId: 'other',
              )
              .source,
          ClassificationSource.defaultCategory,
        );
        expect(
          classifier
              .classify(merchant: null, rules: rules, userId: 'user')
              .source,
          ClassificationSource.pending,
        );
      },
    );
  });

  group('fingerprints avoid false merging', () {
    const fingerprints = TransactionFingerprintService();
    final time = DateTime(2026, 8, 31, 12);

    test('same amount with different merchants is unrelated', () {
      final result = fingerprints.compare(
        _transaction('a', 38, time, merchant: '咖啡店'),
        _transaction(
          'b',
          38,
          time.add(const Duration(seconds: 30)),
          merchant: '便利店',
        ),
      );
      expect(result.type, DuplicateDecisionType.unrelated);
    });

    test('same amount at nearby time alone is insufficient evidence', () {
      final result = fingerprints.compare(
        _transaction('a', 88, time),
        _transaction('b', 88, time.add(const Duration(minutes: 2))),
      );
      expect(result.type, DuplicateDecisionType.unrelated);
      expect(result.confidence, lessThan(.5));
    });

    test('Alipay and bank records become one economic-event candidate', () {
      final result = fingerprints.compare(
        _transaction(
          'wallet',
          128,
          time,
          accountId: SeedIds.alipayAccount,
          source: TransactionSource.import,
          metadata: {'paymentChannel': 'alipay'},
        ),
        _transaction(
          'bank',
          128,
          time.add(const Duration(minutes: 1)),
          accountId: SeedIds.bankAccount,
          source: TransactionSource.import,
          metadata: {'paymentChannel': 'bank', 'cardLastFour': '1234'},
        ),
      );
      expect(result.type, DuplicateDecisionType.sameEconomicEvent);
      expect(result.confidence, .9);
    });

    test('two manual entries are never treated as auto-merge candidates', () {
      final result = fingerprints.compare(
        _transaction('manual-a', 66, time, merchant: '面馆'),
        _transaction(
          'manual-b',
          66,
          time.add(const Duration(seconds: 20)),
          merchant: '面馆',
        ),
      );
      expect(result.type, DuplicateDecisionType.suspicious);
      expect(result.type, isNot(DuplicateDecisionType.highConfidenceDuplicate));
    });
  });

  test(
    'remembered correction persists and wins future classification',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      const classifier = MerchantClassificationService();
      final rules = DriftMerchantRuleRepository(
        database,
        transactions,
        classifier,
      );
      final now = DateTime.now();
      final original = _transaction(
        'merchant-memory',
        199,
        now,
        merchant: '雅迪',
        accountId: SeedIds.cashAccount,
        userId: SeedIds.localUser,
      );
      await transactions.create(original);

      await rules.correctTransaction(
        transactionId: original.id,
        categoryId: 'expense-transport',
        rememberForMerchant: true,
      );
      final updated = (await transactions.getAll()).firstWhere(
        (item) => item.id == original.id,
      );
      expect(updated.userCorrected, isTrue);
      expect(updated.categoryId, 'expense-transport');
      final future = await rules.classify(
        merchant: '支付宝 雅迪',
        userId: SeedIds.localUser,
        transactionType: TransactionType.expense,
      );
      expect(future.source, ClassificationSource.personalRule);
      expect(future.categoryId, 'expense-transport');
    },
  );

  test(
    'economic event links source rows without deleting either transaction',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      const fingerprints = TransactionFingerprintService();
      final inbox = DriftBillInboxRepository(database);
      final rules = DriftMerchantRuleRepository(
        database,
        transactions,
        const MerchantClassificationService(),
      );
      final service = TransactionIntelligenceService(
        transactions: transactions,
        merchantRules: rules,
        inbox: inbox,
        economicEvents: EconomicEventRepository(database, fingerprints),
        fingerprints: fingerprints,
      );
      final now = DateTime.now();
      final wallet = _transaction(
        'event-wallet',
        123.45,
        now,
        accountId: SeedIds.alipayAccount,
        source: TransactionSource.import,
        metadata: {'paymentChannel': 'alipay'},
      );
      final bank = _transaction(
        'event-bank',
        123.45,
        now.add(const Duration(minutes: 1)),
        accountId: SeedIds.bankAccount,
        source: TransactionSource.import,
        metadata: {'paymentChannel': 'bank'},
      );
      await transactions.create(wallet);
      await transactions.create(bank);

      final decision = await service.inspectExisting(bank.id);
      expect(decision.type, DuplicateDecisionType.sameEconomicEvent);
      await service.confirmEconomicEvent(bank.id);
      final events = await database.select(database.economicEventEntries).get();
      expect(events, hasLength(1));
      expect(events.single.status, 'confirmed');
      expect(
        await database.intelligenceDao.getEventRecords(events.single.id),
        hasLength(2),
      );
      expect(
        (await transactions.getAll()).map((item) => item.id),
        containsAll([wallet.id, bank.id]),
      );
      expect(await inbox.getPending(), hasLength(1));
    },
  );
}

MerchantRule _rule(
  String id,
  String normalized,
  String category,
  MerchantRuleSource source,
  MerchantRuleMatchType match,
  DateTime now, {
  String? userId,
}) {
  return MerchantRule(
    id: id,
    merchantPattern: normalized,
    normalizedPattern: normalized.toLowerCase(),
    matchType: match,
    categoryId: category,
    userId: userId,
    confidence: 1,
    source: source,
    createdAt: now,
    updatedAt: now,
  );
}

TransactionRecord _transaction(
  String id,
  double amount,
  DateTime occurredAt, {
  String? merchant,
  String accountId = 'account',
  String? userId,
  TransactionSource source = TransactionSource.manual,
  Map<String, Object?>? metadata,
}) {
  return TransactionRecord(
    id: id,
    bookId: SeedIds.personalBook,
    userId: userId,
    type: TransactionType.expense,
    amount: amount,
    accountId: accountId,
    merchant: merchant,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
    source: source,
    metadataJson: metadata == null ? null : jsonEncode(metadata),
  );
}
