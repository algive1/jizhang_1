import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/bookkeeping/application/amount_input.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'package:jizhang_app/features/intelligence/application/transaction_intelligence_service.dart';
import 'package:jizhang_app/features/intelligence/data/bill_inbox_repository.dart';
import 'package:jizhang_app/features/intelligence/data/economic_event_repository.dart';
import 'package:jizhang_app/features/intelligence/data/merchant_rule_repository.dart';
import 'package:jizhang_app/features/intelligence/domain/merchant_classification_service.dart';
import 'package:jizhang_app/features/intelligence/domain/transaction_fingerprint_service.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transaction_attachment_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test('custom amount input rejects invalid decimal states', () {
    var input = const AmountInput();
    for (final key in ['3', '8', '.', '5', '0', '9', '.']) {
      input = input.enter(key);
    }
    expect(input.value, '38.50');
    expect(input.amount, 38.5);
    expect(input.displayValue, '38.50');
    expect(input.isValid, isTrue);

    input = input.backspace().backspace();
    expect(input.value, '38.');
    expect(input.displayValue, '38.00');
  });

  test('quick bookkeeping persists expense, income and transfer', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final settings = DriftAppSettingsRepository(database);
    final service = QuickBookkeepingService(transactions, settings);
    final now = DateTime(2026, 8, 31, 20, 45);

    final cashBefore = (await database.accountDao.findById(
      SeedIds.cashAccount,
    ))!.balanceInCents;
    final bankBefore = (await database.accountDao.findById(
      SeedIds.bankAccount,
    ))!.balanceInCents;

    await service.save(
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 38.5,
        categoryId: 'expense-food',
        categoryName: '餐饮',
        accountId: SeedIds.cashAccount,
        occurredAt: now,
        tags: const ['聚餐'],
      ),
    );
    await service.save(
      QuickBookkeepingRequest(
        type: TransactionType.income,
        amount: 100,
        categoryId: 'income-other',
        categoryName: '其他收入',
        accountId: SeedIds.bankAccount,
        occurredAt: now,
      ),
    );
    await service.save(
      QuickBookkeepingRequest(
        type: TransactionType.transfer,
        amount: 25,
        accountId: SeedIds.bankAccount,
        destinationAccountId: SeedIds.cashAccount,
        occurredAt: now,
      ),
    );

    final cashAfter = (await database.accountDao.findById(SeedIds.cashAccount))!
        .balanceInCents;
    final bankAfter = (await database.accountDao.findById(SeedIds.bankAccount))!
        .balanceInCents;
    expect(cashAfter, cashBefore - 3850 + 2500);
    expect(bankAfter, bankBefore + 10000 - 2500);
    expect(
      await settings.get(QuickBookkeepingService.lastAccountKey),
      SeedIds.bankAccount,
    );

    final saved = await transactions.getAll();
    expect(saved.where((item) => item.occurredAt == now), hasLength(3));
    expect(
      saved.firstWhere((item) => item.amount == 38.5).metadataJson,
      contains('聚餐'),
    );
  });

  test('internal transfer requires two different accounts and is not consumption', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final service = QuickBookkeepingService(
      transactions,
      DriftAppSettingsRepository(database),
    );

    await expectLater(
      service.save(
        QuickBookkeepingRequest(
          type: TransactionType.transfer,
          amount: 10,
          accountId: SeedIds.wechatAccount,
          occurredAt: DateTime(2026, 9, 20, 10),
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.save(
        QuickBookkeepingRequest(
          type: TransactionType.transfer,
          amount: 10,
          accountId: SeedIds.wechatAccount,
          destinationAccountId: SeedIds.wechatAccount,
          occurredAt: DateTime(2026, 9, 20, 10),
        ),
      ),
      throwsArgumentError,
    );

    final sourceBefore =
        (await database.accountDao.findById(SeedIds.wechatAccount))!
            .balanceInCents;
    final destinationBefore =
        (await database.accountDao.findById(SeedIds.bankAccount))!
            .balanceInCents;

    final saved = await service.save(
      QuickBookkeepingRequest(
        type: TransactionType.transfer,
        amount: 66,
        accountId: SeedIds.wechatAccount,
        destinationAccountId: SeedIds.bankAccount,
        merchant: '本人银行卡',
        occurredAt: DateTime(2026, 9, 20, 10, 30),
        source: TransactionSource.auto,
      ),
    );

    expect(saved.type, TransactionType.transfer);
    expect(saved.destinationAccountId, SeedIds.bankAccount);
    expect(saved.categoryId, isNull);
    expect(saved.isConsumptionExpense, isFalse);
    expect(
      (await database.accountDao.findById(SeedIds.wechatAccount))!
          .balanceInCents,
      sourceBefore - 6600,
    );
    expect(
      (await database.accountDao.findById(SeedIds.bankAccount))!.balanceInCents,
      destinationBefore + 6600,
    );
  });

  test('editing can clear or replace a persisted child category', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final service = QuickBookkeepingService(
      transactions,
      DriftAppSettingsRepository(database),
    );
    final categories = await database.categoryDao.getAll();
    final food = categories.firstWhere(
      (item) => item.name == '餐饮' && item.parentId == null,
    );
    final breakfast = categories.firstWhere(
      (item) => item.parentId == food.id,
    );
    final transport = categories.firstWhere(
      (item) => item.name == '交通' && item.parentId == null,
    );

    final created = await service.save(
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 18,
        accountId: SeedIds.cashAccount,
        categoryId: food.id,
        subcategoryId: breakfast.id,
        categoryName: food.name,
        occurredAt: DateTime(2026, 9, 21, 8),
      ),
    );
    expect(created.subcategoryId, breakfast.id);

    final cleared = await service.update(
      created,
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 18,
        accountId: SeedIds.cashAccount,
        categoryId: food.id,
        categoryName: food.name,
        clearSubcategory: true,
        occurredAt: created.occurredAt,
      ),
    );
    expect(cleared.subcategoryId, isNull);
    expect((await transactions.getById(created.id))?.subcategoryId, isNull);

    final changedCategory = await service.update(
      created,
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 18,
        accountId: SeedIds.cashAccount,
        categoryId: transport.id,
        categoryName: transport.name,
        occurredAt: created.occurredAt,
      ),
    );
    expect(
      changedCategory.subcategoryId,
      isNull,
      reason: 'Changing the parent category must not retain a child from the old parent.',
    );
  });

  test('family payer attribution is explicit and stable across edits', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final service = QuickBookkeepingService(
      transactions,
      DriftAppSettingsRepository(database),
    );
    final occurredAt = DateTime(2026, 9, 19, 12);

    final selectedPayer = await service.save(
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 18,
        accountId: SeedIds.cashAccount,
        occurredAt: occurredAt,
        payerUserId: 'family-member-a',
      ),
    );
    expect(selectedPayer.userId, 'family-member-a');

    final preserved = await service.update(
      selectedPayer,
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 20,
        accountId: SeedIds.cashAccount,
        occurredAt: occurredAt,
      ),
    );
    expect(preserved.userId, 'family-member-a');

    final changed = await service.update(
      preserved,
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 22,
        accountId: SeedIds.cashAccount,
        occurredAt: occurredAt,
        payerUserId: 'family-member-b',
      ),
    );
    expect(changed.userId, 'family-member-b');

    final defaultPayer = await service.save(
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 8,
        accountId: SeedIds.cashAccount,
        occurredAt: occurredAt,
      ),
    );
    expect(defaultPayer.userId, SeedIds.localUser);
  });

  test('saved records reload with category title and note title', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final service = QuickBookkeepingService(
      transactions,
      DriftAppSettingsRepository(database),
    );

    final withoutNote = await service.save(
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 18,
        accountId: SeedIds.cashAccount,
        categoryId: 'expense-food',
        occurredAt: DateTime(2026, 9, 11, 12),
      ),
    );
    final reloadedWithoutNote = await transactions.getById(withoutNote.id);
    expect(reloadedWithoutNote, isNotNull);
    expect(reloadedWithoutNote!.categoryName, '餐饮');
    expect(reloadedWithoutNote.displayTitle, '餐饮');

    final withNote = await service.save(
      QuickBookkeepingRequest(
        type: TransactionType.expense,
        amount: 20,
        accountId: SeedIds.cashAccount,
        categoryId: 'expense-food',
        note: '和同事一起',
        occurredAt: DateTime(2026, 9, 11, 13),
      ),
    );
    final reloadedWithNote = await transactions.getById(withNote.id);
    expect(reloadedWithNote!.categoryName, '餐饮');
    expect(reloadedWithNote.displayTitle, '和同事一起');
  });

  test(
    'editing a saved transaction updates its fields and balance effect',
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
          amount: 10,
          categoryId: 'expense-food',
          categoryName: '餐饮',
          accountId: SeedIds.cashAccount,
          merchant: '早餐店',
          occurredAt: DateTime(2026, 8, 31, 8),
        ),
      );

      final updated = await service.update(
        saved,
        QuickBookkeepingRequest(
          type: TransactionType.income,
          amount: 25,
          categoryId: 'income-other',
          categoryName: '其他收入',
          accountId: SeedIds.bankAccount,
          merchant: '退款',
          occurredAt: DateTime(2026, 8, 31, 9),
        ),
      );

      expect(updated.id, saved.id);
      expect(updated.type, TransactionType.income);
      expect(updated.amount, 25);
      expect(updated.accountId, SeedIds.bankAccount);
      expect((await transactions.getAll()), hasLength(1));
      expect(
        (await database.accountDao.findById(SeedIds.cashAccount))!
            .balanceInCents,
        0,
      );
      expect(
        (await database.accountDao.findById(SeedIds.bankAccount))!
            .balanceInCents,
        2500,
      );
    },
  );

  test(
    'quick bookkeeping persists attachments outside transaction metadata',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      final service = QuickBookkeepingService(
        transactions,
        DriftAppSettingsRepository(database),
        attachments: DriftTransactionAttachmentRepository(database),
      );

      final saved = await service.save(
        QuickBookkeepingRequest(
          type: TransactionType.expense,
          amount: 18,
          accountId: SeedIds.cashAccount,
          categoryId: 'expense-food',
          occurredAt: DateTime(2026, 9, 11, 12),
          tags: const ['午餐'],
          attachmentPaths: const ['/documents/receipt.pdf'],
        ),
      );
      expect(saved.metadataJson, contains('午餐'));
      expect(saved.metadataJson, isNot(contains('attachments')));
      expect(
        await DriftTransactionAttachmentRepository(database)
            .getForTransaction(saved.id, bookId: saved.bookId),
        hasLength(1),
      );

      await service.update(
        saved,
        QuickBookkeepingRequest(
          type: TransactionType.expense,
          amount: 18,
          accountId: SeedIds.cashAccount,
          categoryId: 'expense-food',
          occurredAt: saved.occurredAt,
          tags: const ['已核对'],
        ),
      );
      expect(
        await DriftTransactionAttachmentRepository(database)
            .getForTransaction(saved.id, bookId: saved.bookId),
        isEmpty,
      );
      final updated = await transactions.getById(saved.id);
      expect(updated!.metadataJson, contains('已核对'));
      expect(updated.metadataJson, isNot(contains('attachments')));
    },
  );

  test('batch bookkeeping rolls back every item when one item fails', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final service = QuickBookkeepingService(
      transactions,
      DriftAppSettingsRepository(database),
    );
    final before = await transactions.getAll();
    final cashBefore = (await database.accountDao.findById(
      SeedIds.cashAccount,
    ))!.balanceInCents;

    await expectLater(
      service.saveAll([
        QuickBookkeepingRequest(
          type: TransactionType.expense,
          amount: 12,
          accountId: SeedIds.cashAccount,
          occurredAt: DateTime(2026, 8, 31),
        ),
        QuickBookkeepingRequest(
          type: TransactionType.expense,
          amount: 20,
          accountId: 'missing-account',
          occurredAt: DateTime(2026, 8, 31),
        ),
      ]),
      throwsStateError,
    );

    expect(await transactions.getAll(), hasLength(before.length));
    expect(
      (await database.accountDao.findById(SeedIds.cashAccount))!.balanceInCents,
      cashBefore,
    );
  });

  test(
    'saved transactions run classification and duplicate inspection',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      final inbox = DriftBillInboxRepository(database);
      const fingerprints = TransactionFingerprintService();
      final rules = DriftMerchantRuleRepository(
        database,
        transactions,
        const MerchantClassificationService(),
      );
      final intelligence = TransactionIntelligenceService(
        transactions: transactions,
        merchantRules: rules,
        inbox: inbox,
        economicEvents: EconomicEventRepository(database, fingerprints),
        fingerprints: fingerprints,
      );
      final service = QuickBookkeepingService(
        transactions,
        DriftAppSettingsRepository(database),
        intelligence: intelligence,
      );
      final occurredAt = DateTime(2026, 8, 31, 19);

      await service.save(
        QuickBookkeepingRequest(
          type: TransactionType.expense,
          amount: 38,
          accountId: SeedIds.cashAccount,
          merchant: '瑞幸咖啡',
          occurredAt: occurredAt,
        ),
      );
      final classified = (await transactions.getAll()).single;
      expect(classified.categoryId, 'expense-food');

      await service.save(
        QuickBookkeepingRequest(
          type: TransactionType.expense,
          amount: 38,
          categoryId: 'expense-food',
          categoryName: '餐饮',
          accountId: SeedIds.cashAccount,
          merchant: '瑞幸咖啡',
          occurredAt: occurredAt.add(const Duration(seconds: 30)),
        ),
      );
      final pending = await inbox.getPending();
      expect(pending, hasLength(1));
      expect(pending.single.reason.name, 'suspectedDuplicate');
      expect((await transactions.getAll()).first.duplicateConfidence, .72);
    },
  );
}
