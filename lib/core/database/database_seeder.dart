import 'package:drift/drift.dart';

import 'app_database.dart';
import '../models/family.dart';
import 'category_templates.dart';

abstract final class SeedIds {
  static const personalBook = 'book-personal';
  static const localUser = 'user-local';
  static const cashAccount = 'account-cash';
  static const wechatAccount = 'account-wechat';
  static const alipayAccount = 'account-alipay';
  static const bankAccount = 'account-bank';
}

class DatabaseSeeder {
  DatabaseSeeder(this._database);

  static const currentSeedVersion = 5;
  static const _seedVersionKey = 'seed_version';

  final AppDatabase _database;

  /// Seeds only neutral app defaults unless [includeDemoData] is requested.
  ///
  /// Demo transactions, balances, goals and budgets are intentionally opt-in
  /// so a new user never starts with fabricated financial history.
  Future<void> seedIfNeeded({bool includeDemoData = false}) async {
    final storedVersion = int.tryParse(
      await _database.appSettingsDao.getValue(_seedVersionKey) ?? '0',
    );
    if ((storedVersion ?? 0) >= currentSeedVersion && !includeDemoData) {
      await ensureExistingBookDefaults();
      return;
    }

    await _database.transaction(() async {
      if ((storedVersion ?? 0) < 1) {
        await _seedAccounts(includeDemoData: includeDemoData);
        await _seedCategories(type: BookType.personal);
        if (includeDemoData) {
          await _seedTransactions();
          await _seedGoal();
        }
      }
      if ((storedVersion ?? 0) < 2 && includeDemoData) {
        await _seedBudgets();
      }
      if ((storedVersion ?? 0) < 3) {
        await _seedMerchantRules();
      }
      if ((storedVersion ?? 0) < 4) {
        await _seedPersonalBook();
      }
      if ((storedVersion ?? 0) > 0 && (storedVersion ?? 0) < 5) {
        await _removeLegacyDemoData();
      }
      await _database.appSettingsDao.setValue(
        _seedVersionKey,
        currentSeedVersion.toString(),
        DateTime.now(),
      );
    });
    await ensureExistingBookDefaults();
  }

  Future<void> seedBookDefaults(String bookId, {required BookType type}) async {
    final now = DateTime.now();
    final cashId = scopedSeedId(bookId, SeedIds.cashAccount);
    if (await _database.accountDao.findById(cashId) == null) {
      await _database.accountDao.insertOne(
        AccountEntriesCompanion.insert(
          id: cashId,
          bookId: Value(bookId),
          name: '现金',
          type: 'cash',
          icon: 'payments_outlined',
          color: 0xFF73963B,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await _seedCategories(bookId: bookId, type: type);
    await _seedMerchantRules(bookId: bookId, type: type);
  }

  /// Repairs an old local book without touching any existing scoped data.
  /// Shared books are populated by the sync snapshot and must not be seeded
  /// while their remote entities are still being applied.
  Future<void> ensureExistingBookDefaults() async {
    final books = await _database
        .customSelect('SELECT id,type FROM books WHERE is_archived=0')
        .get();
    await _database.transaction(() async {
      for (final row in books) {
        await ensureBookDefaults(
          row.read<String>('id'),
          type: BookType.values.byName(row.read<String>('type')),
          restoreTarget: false,
        );
      }
    });
  }

  Future<void> ensureBookDefaults(
    String bookId, {
    BookType? type,
    BookType? previousType,
    bool restoreTarget = false,
  }) async {
    final shared = await _database
        .customSelect(
          'SELECT 1 FROM sync_books WHERE book_id=? LIMIT 1',
          variables: [Variable(bookId)],
        )
        .getSingleOrNull();
    if (shared != null) return;
    final bookType =
        type ??
        BookType.values.byName(
          (await _database.familyDao.findBook(bookId))!.type,
        );
    if (previousType != null && previousType != bookType) {
      await _archiveTypeDefaults(bookId, previousType);
    }
    if (restoreTarget) await _restoreTypeDefaults(bookId, bookType);
    await _upgradeCategoryTemplate(bookId, bookType);
    await _seedMerchantRules(bookId: bookId, type: bookType);
  }

  Future<void> _upgradeCategoryTemplate(String bookId, BookType type) async {
    if (type != BookType.personal) {
      const legacy = {
        'expense-food': ('餐饮', 'restaurant_outlined'),
        'expense-transport': ('交通', 'directions_car_outlined'),
        'expense-shopping': ('购物', 'shopping_bag_outlined'),
        'expense-entertainment': ('娱乐', 'movie_outlined'),
        'expense-housing': ('住房', 'home_outlined'),
        'expense-utilities': ('生活缴费', 'receipt_long_outlined'),
        'expense-medical': ('医疗', 'medical_services_outlined'),
        'expense-education': ('教育培训', 'school_outlined'),
        'expense-travel': ('旅行', 'flight_takeoff_outlined'),
        'expense-gift': ('人情', 'redeem_outlined'),
        'expense-pet': ('宠物', 'pets_outlined'),
        'expense-digital': ('数码', 'devices_outlined'),
        'expense-car': ('汽车', 'directions_car_filled_outlined'),
        'expense-other': ('其他', 'more_horiz'),
        'income-salary': ('工资', 'work_outline'),
        'income-bonus': ('奖金', 'stars_outlined'),
        'income-part-time': ('兼职', 'schedule_outlined'),
        'income-investment': ('投资收益', 'trending_up'),
        'income-refund': ('退款', 'undo'),
        'income-other': ('其他收入', 'add_circle_outline'),
      };
      for (final entry in legacy.entries) {
        final row = await _database.categoryDao.findById(
          scopedSeedId(bookId, entry.key),
        );
        final hasCustomChildren = row == null
            ? false
            : (await _database
                      .customSelect(
                        'SELECT 1 FROM categories WHERE parent_id=? AND is_archived=0 LIMIT 1',
                        variables: [Variable(row.id)],
                      )
                      .getSingleOrNull()) !=
                  null;
        if (row != null &&
            !hasCustomChildren &&
            row.isDefault &&
            row.name == entry.value.$1 &&
            row.icon == entry.value.$2) {
          await _database.categoryDao.upsert(
            CategoryEntriesCompanion(
              id: Value(row.id),
              bookId: Value(row.bookId),
              parentId: Value(row.parentId),
              name: Value(row.name),
              icon: Value(row.icon),
              type: Value(row.type),
              sortOrder: Value(row.sortOrder),
              isDefault: Value(row.isDefault),
              isArchived: const Value(true),
            ),
          );
        }
      }
    }
    await _seedCategories(bookId: bookId, type: type);
    await _archiveSupersededCategoryChildren(bookId, type);
  }

  Future<void> _archiveSupersededCategoryChildren(
    String bookId,
    BookType type,
  ) async {
    final deprecated = switch (type) {
      BookType.personal => const <String, String>{
          'expense-shopping-daily': '日用百货',
          'expense-shopping-furniture': '家居用品',
        },
      BookType.family => const <String, String>{
          'expense-shopping-daily': '家庭日用品',
          'expense-shopping-furniture': '家具',
          'expense-shopping-cleaning': '清洁用品',
        },
      BookType.enterprise => const <String, String>{},
    };
    for (final entry in deprecated.entries) {
      final id = _categorySeedId(bookId, entry.key, type);
      final row = await _database.categoryDao.findById(id);
      if (row == null ||
          !row.isDefault ||
          row.isArchived ||
          row.name != entry.value) {
        continue;
      }
      await _database.categoryDao.upsert(
        CategoryEntriesCompanion(
          id: Value(row.id),
          bookId: Value(row.bookId),
          parentId: Value(row.parentId),
          name: Value(row.name),
          icon: Value(row.icon),
          type: Value(row.type),
          sortOrder: Value(row.sortOrder),
          isDefault: Value(row.isDefault),
          isArchived: const Value(true),
        ),
      );
    }
  }

  Future<void> _archiveTypeDefaults(String bookId, BookType type) async {
    for (final template in categoryTemplates(type)) {
      final id = _categorySeedId(bookId, template.key, type);
      final row = await _database.categoryDao.findById(id);
      if (row != null &&
          row.isDefault &&
          row.name == template.name &&
          row.icon == template.icon) {
        final child = await _database
            .customSelect(
              'SELECT 1 FROM categories WHERE parent_id=? AND is_archived=0 LIMIT 1',
              variables: [Variable(id)],
            )
            .getSingleOrNull();
        if (child != null) continue;
        await (_database.update(_database.categoryEntries)
              ..where((category) => category.id.equals(id)))
            .write(const CategoryEntriesCompanion(isArchived: Value(true)));
      }
    }
  }

  Future<void> _restoreTypeDefaults(String bookId, BookType type) async {
    for (final template in categoryTemplates(type)) {
      final id = _categorySeedId(bookId, template.key, type);
      final row = await _database.categoryDao.findById(id);
      if (row != null &&
          row.isDefault &&
          row.name == template.name &&
          row.icon == template.icon) {
        await (_database.update(_database.categoryEntries)
              ..where((category) => category.id.equals(id)))
            .write(const CategoryEntriesCompanion(isArchived: Value(false)));
      }
    }
  }

  String _categorySeedId(String bookId, String key, BookType type) =>
      scopedSeedId(
        bookId,
        type == BookType.personal ? key : '${type.name}-$key',
      );

  Future<void> _seedAccounts({required bool includeDemoData}) async {
    final now = DateTime.now();
    final accounts = [
      (
        SeedIds.wechatAccount,
        '微信',
        'wechat',
        120000,
        'chat_bubble_outline',
        0xFF63A867,
        '3316',
      ),
      (
        SeedIds.alipayAccount,
        '支付宝',
        'alipay',
        200000,
        'account_balance_wallet_outlined',
        0xFF4A90E2,
        '4126',
      ),
      (
        SeedIds.bankAccount,
        '银行卡',
        'debitCard',
        800000,
        'account_balance_outlined',
        0xFF73963B,
        '7777',
      ),
      (
        SeedIds.cashAccount,
        '现金',
        'cash',
        50000,
        'payments_outlined',
        0xFFB68A55,
        null,
      ),
    ];
    for (var index = 0; index < accounts.length; index++) {
      final account = accounts[index];
      await _database.accountDao.insertOne(
        AccountEntriesCompanion.insert(
          id: account.$1,
          name: account.$2,
          type: account.$3,
          balanceInCents: Value(includeDemoData ? account.$4 : 0),
          identifierSuffix: Value(account.$7),
          icon: account.$5,
          color: account.$6,
          sortOrder: Value(index),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> _seedCategories({
    String bookId = SeedIds.personalBook,
    BookType type = BookType.personal,
  }) async {
    final templates = categoryTemplates(type);
    for (var index = 0; index < templates.length; index++) {
      final template = templates[index];
      final id = _categorySeedId(bookId, template.key, type);
      if (await _database.categoryDao.findById(id) == null) {
        await _database.categoryDao.insertOne(
          CategoryEntriesCompanion.insert(
            id: id,
            bookId: Value(bookId),
            name: template.name,
            icon: template.icon,
            type: template.type,
            sortOrder: Value(index),
            isDefault: const Value(true),
          ),
        );
      }
    }
    for (final rootTemplate in templates) {
      final parentId = _categorySeedId(bookId, rootTemplate.key, type);
      final parent = await _database.categoryDao.findById(parentId);
      if (parent == null || parent.isArchived || !parent.isDefault) continue;
      final children = subcategoryTemplates(type, rootTemplate);
      for (var index = 0; index < children.length; index++) {
        final template = children[index];
        final id = _categorySeedId(bookId, template.key, type);
        if (await _database.categoryDao.findById(id) != null) continue;
        // A matching user-created child takes precedence over a default.
        final duplicate = await _database
            .customSelect(
              'SELECT 1 FROM categories WHERE parent_id=? AND name=? LIMIT 1',
              variables: [Variable(parentId), Variable(template.name)],
            )
            .getSingleOrNull();
        if (duplicate != null) continue;
        await _database.categoryDao.insertOne(
          CategoryEntriesCompanion.insert(
            id: id,
            bookId: Value(bookId),
            parentId: Value(parentId),
            name: template.name,
            icon: template.icon,
            type: template.type,
            sortOrder: Value(index),
            isDefault: const Value(true),
          ),
        );
      }
    }
    return;
    // ignore: dead_code
    final expenses = switch (type) {
      BookType.personal => const [
        ('expense-food', '餐饮', 'restaurant_outlined'),
        ('expense-transport', '交通', 'directions_car_outlined'),
        ('expense-shopping', '购物', 'shopping_bag_outlined'),
        ('expense-entertainment', '娱乐', 'movie_outlined'),
        ('expense-housing', '住房', 'home_outlined'),
        ('expense-utilities', '生活缴费', 'receipt_long_outlined'),
        ('expense-medical', '医疗', 'medical_services_outlined'),
        ('expense-education', '教育培训', 'school_outlined'),
        ('expense-travel', '旅行', 'flight_takeoff_outlined'),
        ('expense-gift', '人情', 'redeem_outlined'),
        ('expense-pet', '宠物', 'pets_outlined'),
        ('expense-digital', '数码', 'devices_outlined'),
        ('expense-car', '汽车', 'directions_car_filled_outlined'),
        ('expense-other', '其他', 'more_horiz'),
      ],
      BookType.family => const [
        ('expense-food', '家庭采购', 'shopping_cart_outlined'),
        ('expense-transport', '家庭出行', 'directions_car_outlined'),
        ('expense-shopping', '家庭购物', 'shopping_bag_outlined'),
        ('expense-entertainment', '家庭娱乐', 'movie_outlined'),
        ('expense-housing', '房屋居住', 'home_outlined'),
        ('expense-utilities', '家庭缴费', 'receipt_long_outlined'),
        ('expense-medical', '家庭医疗', 'medical_services_outlined'),
        ('expense-education', '子女教育', 'school_outlined'),
        ('expense-travel', '家庭旅行', 'flight_takeoff_outlined'),
        ('expense-gift', '家庭人情', 'redeem_outlined'),
        ('expense-pet', '宠物', 'pets_outlined'),
        ('expense-digital', '家庭数码', 'devices_outlined'),
        ('expense-car', '家庭汽车', 'directions_car_filled_outlined'),
        ('expense-other', '其他', 'more_horiz'),
      ],
      BookType.enterprise => const [
        ('expense-food', '商务餐饮', 'restaurant_outlined'),
        ('expense-transport', '差旅交通', 'directions_car_outlined'),
        ('expense-shopping', '办公采购', 'shopping_bag_outlined'),
        ('expense-entertainment', '业务招待', 'movie_outlined'),
        ('expense-housing', '场地租赁', 'home_outlined'),
        ('expense-utilities', '办公缴费', 'receipt_long_outlined'),
        ('expense-medical', '员工福利', 'medical_services_outlined'),
        ('expense-education', '培训会议', 'school_outlined'),
        ('expense-travel', '商务旅行', 'flight_takeoff_outlined'),
        ('expense-gift', '商务礼赠', 'redeem_outlined'),
        ('expense-pet', '其他福利', 'pets_outlined'),
        ('expense-digital', '软件设备', 'devices_outlined'),
        ('expense-car', '车辆运营', 'directions_car_filled_outlined'),
        ('expense-other', '其他支出', 'more_horiz'),
      ],
    };
    final incomes = switch (type) {
      BookType.personal => const [
        ('income-salary', '工资', 'work_outline'),
        ('income-bonus', '奖金', 'stars_outlined'),
        ('income-part-time', '兼职', 'schedule_outlined'),
        ('income-investment', '投资收益', 'trending_up'),
        ('income-refund', '退款', 'undo'),
        ('income-other', '其他收入', 'add_circle_outline'),
      ],
      BookType.family => const [
        ('income-salary', '家庭工资', 'work_outline'),
        ('income-bonus', '家庭奖金', 'stars_outlined'),
        ('income-part-time', '家庭兼职', 'schedule_outlined'),
        ('income-investment', '家庭投资收益', 'trending_up'),
        ('income-refund', '家庭退款', 'undo'),
        ('income-other', '其他收入', 'add_circle_outline'),
      ],
      BookType.enterprise => const [
        ('income-salary', '主营业务收入', 'work_outline'),
        ('income-bonus', '经营奖励', 'stars_outlined'),
        ('income-part-time', '其他业务收入', 'schedule_outlined'),
        ('income-investment', '投资收益', 'trending_up'),
        ('income-refund', '销售退款', 'undo'),
        ('income-other', '其他收入', 'add_circle_outline'),
      ],
    };
    var sortOrder = 0;
    for (final category in expenses) {
      final id = _categorySeedId(bookId, category.$1, type);
      if (await _database.categoryDao.findById(id) == null) {
        await _database.categoryDao.insertOne(
          CategoryEntriesCompanion.insert(
            id: id,
            bookId: Value(bookId),
            name: category.$2,
            icon: category.$3,
            type: 'expense',
            sortOrder: Value(sortOrder),
            isDefault: const Value(true),
          ),
        );
      }
      sortOrder++;
    }
    sortOrder = 0;
    for (final category in incomes) {
      final id = _categorySeedId(bookId, category.$1, type);
      if (await _database.categoryDao.findById(id) == null) {
        await _database.categoryDao.insertOne(
          CategoryEntriesCompanion.insert(
            id: id,
            bookId: Value(bookId),
            name: category.$2,
            icon: category.$3,
            type: 'income',
            sortOrder: Value(sortOrder),
            isDefault: const Value(true),
          ),
        );
      }
      sortOrder++;
    }
  }

  Future<void> _seedMerchantRules({
    String bookId = SeedIds.personalBook,
    BookType type = BookType.personal,
  }) async {
    final now = DateTime.now();
    const rules = [
      (
        'exact-luckin',
        '瑞幸咖啡',
        '瑞幸咖啡',
        'exact',
        'expense-food',
        .98,
        'exactMerchant',
      ),
      (
        'exact-didi',
        '滴滴出行',
        '滴滴出行',
        'exact',
        'expense-transport',
        .98,
        'exactMerchant',
      ),
      (
        'keyword-delivery',
        '外卖',
        '外卖',
        'keyword',
        'expense-food',
        .86,
        'keyword',
      ),
      ('keyword-coffee', '咖啡', '咖啡', 'keyword', 'expense-food', .82, 'keyword'),
      (
        'keyword-taxi',
        '滴滴',
        '滴滴',
        'keyword',
        'expense-transport',
        .86,
        'keyword',
      ),
      (
        'keyword-market',
        '盒马',
        '盒马',
        'keyword',
        'expense-shopping',
        .82,
        'keyword',
      ),
    ];
    for (final rule in rules) {
      final id = scopedSeedId(bookId, rule.$1);
      final exists = await _database
          .customSelect(
            'SELECT 1 FROM merchant_rules WHERE id=? LIMIT 1',
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      if (exists != null) continue;
      await _database.intelligenceDao.upsertMerchantRule(
        MerchantRuleEntriesCompanion.insert(
          id: id,
          bookId: Value(bookId),
          merchantPattern: rule.$2,
          normalizedPattern: rule.$3,
          matchType: rule.$4,
          categoryId: _categorySeedId(bookId, rule.$5, type),
          confidence: rule.$6,
          source: rule.$7,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> _seedPersonalBook() async {
    final now = DateTime.now();
    await _database.familyDao.upsertBook(
      BookEntriesCompanion.insert(
        id: SeedIds.personalBook,
        name: '个人账本',
        type: 'personal',
        ownerUserId: SeedIds.localUser,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _seedTransactions() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final samples = [
      _SeedTransaction(
        'seed-expense-1',
        'expense',
        1800,
        'expense-food',
        SeedIds.alipayAccount,
        '瑞幸咖啡',
        today.add(const Duration(hours: 8, minutes: 36)),
      ),
      _SeedTransaction(
        'seed-expense-2',
        'expense',
        2800,
        'expense-transport',
        SeedIds.wechatAccount,
        '滴滴出行',
        today.add(const Duration(hours: 7, minutes: 58)),
      ),
      _SeedTransaction(
        'seed-expense-3',
        'expense',
        8600,
        'expense-shopping',
        SeedIds.alipayAccount,
        '盒马鲜生',
        today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 19, minutes: 32)),
      ),
      _SeedTransaction(
        'seed-income-1',
        'income',
        980000,
        'income-salary',
        SeedIds.bankAccount,
        '工资',
        today.add(const Duration(hours: 10, minutes: 15)),
      ),
      _SeedTransaction(
        'seed-expense-night',
        'expense',
        3800,
        'expense-food',
        SeedIds.wechatAccount,
        '美团外卖',
        today
            .subtract(const Duration(days: 2))
            .add(const Duration(hours: 22, minutes: 38)),
      ),
      _SeedTransaction(
        'seed-expense-coffee-2',
        'expense',
        4200,
        'expense-food',
        SeedIds.alipayAccount,
        '瑞幸咖啡',
        today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 8, minutes: 32)),
      ),
    ];
    for (final sample in samples) {
      await _database.transactionDao.insertOne(
        TransactionEntriesCompanion.insert(
          id: sample.id,
          bookId: SeedIds.personalBook,
          userId: const Value(SeedIds.localUser),
          type: sample.type,
          amountInCents: sample.amountInCents,
          categoryId: Value(sample.categoryId),
          accountId: sample.accountId,
          merchant: Value(sample.merchant),
          occurredAt: sample.occurredAt,
          createdAt: sample.occurredAt,
          updatedAt: sample.occurredAt,
          syncStatus: const Value('localOnly'),
        ),
      );
      final sign = sample.type == 'income' ? 1 : -1;
      await _database.accountDao.adjustBalance(
        sample.accountId,
        sample.amountInCents * sign,
        sample.occurredAt,
      );
    }
  }

  Future<void> _seedGoal() async {
    final now = DateTime.now();
    const goalId = 'goal-car';
    await _database.goalDao.insertGoal(
      GoalEntriesCompanion.insert(
        id: goalId,
        name: '买车计划',
        goalType: const Value('car'),
        icon: 'car',
        targetAmountInCents: 16000000,
        currentAmountInCents: const Value(6850000),
        targetDate: DateTime(now.year + 1, 12),
        createdAt: DateTime(now.year - 1, 1),
        updatedAt: now,
        description: const Value('开一辆属于自己的车，去更远的地方'),
      ),
    );
    const milestoneAmounts = [2000000, 4000000, 6850000, 10000000, 16000000];
    for (var index = 0; index < milestoneAmounts.length; index++) {
      final amount = milestoneAmounts[index];
      await _database.goalDao.insertMilestone(
        GoalMilestoneEntriesCompanion.insert(
          id: 'goal-car-milestone-$index',
          goalId: goalId,
          amountInCents: amount,
          title: '¥${(amount / 100).round()}',
          sortOrder: index,
          completedAt: amount <= 6850000 ? Value(now) : const Value.absent(),
          celebrationShown: Value(amount <= 6850000),
        ),
      );
    }
    await _database.goalDao.insertContribution(
      GoalContributionEntriesCompanion.insert(
        id: 'goal-car-initial',
        goalId: goalId,
        amountInCents: 6850000,
        type: 'adjustment',
        createdAt: DateTime(now.year - 1, 1),
        note: const Value('初始金额'),
        contributorUserId: const Value(SeedIds.localUser),
      ),
    );
  }

  Future<void> _seedBudgets() async {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final budgets = [
      ('budget-$monthKey-total', null, 600000),
      ('budget-$monthKey-food', 'expense-food', 150000),
      ('budget-$monthKey-transport', 'expense-transport', 80000),
      ('budget-$monthKey-entertainment', 'expense-entertainment', 50000),
    ];
    for (final budget in budgets) {
      await _database.budgetDao.upsert(
        BudgetEntriesCompanion.insert(
          id: budget.$1,
          monthKey: monthKey,
          categoryId: Value(budget.$2),
          amountInCents: budget.$3,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> _removeLegacyDemoData() async {
    final now = DateTime.now();
    const demoTransactions = {
      'seed-expense-1',
      'seed-expense-2',
      'seed-expense-3',
      'seed-income-1',
      'seed-expense-night',
      'seed-expense-coffee-2',
    };
    for (final id in demoTransactions) {
      final transaction = await _database.transactionDao.findById(id);
      if (transaction == null || transaction.deletedAt != null) continue;
      final delta = switch (transaction.type) {
        'income' => -transaction.amountInCents,
        'expense' => transaction.amountInCents,
        _ => 0,
      };
      if (delta != 0) {
        await _database.accountDao.adjustBalance(
          transaction.accountId,
          delta,
          now,
        );
      }
      await _database.transactionDao.softDeleteById(id, now);
    }

    await _database.goalDao.deleteById('goal-car');

    const initialBalances = {
      SeedIds.wechatAccount: 120000,
      SeedIds.alipayAccount: 200000,
      SeedIds.bankAccount: 800000,
      SeedIds.cashAccount: 50000,
    };
    for (final entry in initialBalances.entries) {
      final account = await _database.accountDao.findById(entry.key);
      if (account == null) continue;
      await _database.accountDao.adjustBalance(entry.key, -entry.value, now);
    }
  }
}

class _SeedTransaction {
  const _SeedTransaction(
    this.id,
    this.type,
    this.amountInCents,
    this.categoryId,
    this.accountId,
    this.merchant,
    this.occurredAt,
  );

  final String id;
  final String type;
  final int amountInCents;
  final String categoryId;
  final String accountId;
  final String merchant;
  final DateTime occurredAt;
}

String scopedSeedId(String bookId, String seedId) =>
    bookId == SeedIds.personalBook ? seedId : '$bookId::$seedId';
