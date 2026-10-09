import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_management_repository.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/accounts/domain/account_management.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  testWidgets(
    'asset liability total opens the debt filter including cleared accounts',
    (tester) async {
      final db = await _database();
      await DriftAccountRepository(db)
          .create(_account('cleared-debt', 0, type: AccountType.liability));
      await _pump(tester, db, '/profile/assets');
      await tester.ensureVisible(find.text('总负债 '));
      await tester.tap(find.text('总负债 '));
      await tester.pumpAndSettle();
      expect(find.text('账户总览'), findsOneWidget);
      expect(find.text('负债账户（1）'), findsOneWidget);
      expect(find.text('cleared-debt'), findsOneWidget);
      expect(find.text('微信-3316'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overview edits and calibrates the selected account', (
    tester,
  ) async {
    final db = await _database();
    final accounts = DriftAccountRepository(db);
    await accounts.create(_account('cash-test', 100));
    await _pump(tester, db, '/profile/accounts');
    await _action(tester, 'cash-test', '编辑账户');
    await tester.enterText(_field('账户名称'), '备用现金');
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();
    expect((await accounts.getById('cash-test'))!.name, '备用现金');
    expect((await accounts.getById('cash-test'))!.balance, 100);

    await _action(tester, 'cash-test', '校准余额');
    await tester.enterText(_field('实际余额'), '125.50');
    await tester.tap(find.text('确认校准'));
    await tester.pumpAndSettle();
    expect((await accounts.getById('cash-test'))!.balance, 125.50);
    final records = await DriftTransactionRepository(db).getAll();
    expect(records.single.type, TransactionType.adjustment);
    expect(records.single.amount, 25.50);
    final stats = const StatisticalAnalysisService().analyze(records);
    expect(stats.totalIncome, 0);
    expect(stats.totalExpense, 0);
    expect(tester.takeException(), isNull);
  });

  for (final category in [
    AccountFundCategory.storedValue,
    AccountFundCategory.restricted,
  ]) {
    testWidgets(
      '${category.name} editor preserves metadata and supports calibration',
      (tester) async {
        final db = await _database();
        final accounts = DriftAccountRepository(db);
        final managed = DriftAccountManagementRepository(
          db,
          accounts,
          bookId: 'book-personal',
        );
        final expected = DateTime(2027, 1, 15);
        await managed.create(
          account: _account('managed-test', 80),
          category: category,
          platform: '原平台',
          note: '原备注',
          includeInTotal: false,
          restrictedStatus: category == AccountFundCategory.restricted
              ? RestrictedFundStatus.refundable
              : null,
          expectedReturnAt: category == AccountFundCategory.restricted
              ? expected
              : null,
        );
        await _pump(
          tester,
          db,
          category == AccountFundCategory.restricted
              ? '/profile/accounts/restricted/managed-test'
              : '/profile/accounts/managed-test',
        );
        await _action(tester, 'managed-test', '编辑账户');
        await tester.enterText(_field('账户名称'), '修改后账户');
        await tester.enterText(
          _field(
            category == AccountFundCategory.restricted ? '平台 / 机构' : '平台 / 用途',
          ),
          '新平台',
        );
        await tester.tap(find.text('保存').last);
        await tester.pumpAndSettle();
        final saved = (await managed.getById('managed-test'))!;
        expect(saved.account.name, '修改后账户');
        expect(saved.account.balance, 80);
        expect(saved.category, category);
        expect(saved.platform, '新平台');
        expect(saved.note, '原备注');
        expect(saved.includeInTotal, isFalse);
        if (category == AccountFundCategory.restricted) {
          expect(saved.restrictedStatus, RestrictedFundStatus.refundable);
          expect(saved.expectedReturnAt, expected);
        }
        await _action(tester, 'managed-test', '校准余额');
        await tester.enterText(_field('实际余额'), '90');
        await tester.tap(find.text('确认校准'));
        await tester.pumpAndSettle();
        expect((await accounts.getById('managed-test'))!.balance, 90);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('debt accounts remain manageable after repayment and archive', (
    tester,
  ) async {
    final db = await _database();
    final accounts = DriftAccountRepository(db);
    await accounts.create(
      _account('zero-debt', 0, type: AccountType.liability),
    );
    await accounts.create(
      _account('overpaid', 30, type: AccountType.creditCard),
    );
    final router = await _pump(tester, db, '/profile/accounts?filter=debt');
    expect(find.text('zero-debt'), findsOneWidget);
    expect(find.text('overpaid-9876'), findsOneWidget);
    expect(find.text('已还清'), findsOneWidget);
    expect(find.text('溢缴余额'), findsOneWidget);
    await _action(tester, 'zero-debt', '校准欠款');
    await tester.enterText(_field('实际欠款（填正数）'), '60');
    await tester.tap(find.text('确认校准'));
    await tester.pumpAndSettle();
    expect((await accounts.getById('zero-debt'))!.balance, -60);
    await _action(tester, 'zero-debt', '归档账户');
    await tester.tap(find.text('归档').last);
    await tester.pumpAndSettle();
    expect(find.text('zero-debt'), findsNothing);
    router.go('/profile/accounts?filter=archived');
    await tester.pumpAndSettle();
    await _action(tester, 'zero-debt', '恢复账户');
    expect((await accounts.getById('zero-debt'))!.isArchived, isFalse);
    await tester.pumpAndSettle();
    router.go('/profile/accounts?filter=debt');
    await tester.pumpAndSettle();
    expect(find.text('zero-debt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty debt view creates a liability in the selected currency', (
    tester,
  ) async {
    final db = await _database();
    await DriftAccountRepository(db)
        .create(_account('usd-cash', 500, currency: 'USD'));
    final router = await _pump(
      tester,
      db,
      '/profile/accounts?filter=debt&currency=USD',
    );
    await tester.tap(find.text('添加负债账户').last);
    await tester.pumpAndSettle();
    expect(find.text('日常资金'), findsNothing);
    await tester.tap(find.text('负债账户').first);
    await tester.pumpAndSettle();
    await tester.enterText(_field('账户名称'), '美元借款');
    await tester.enterText(_field('当前欠款（填正数）'), '120');
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();
    final created = (await DriftAccountRepository(
      db,
    ).getAll()).singleWhere((account) => account.name == '美元借款');
    expect(created.type, AccountType.liability);
    expect(created.currency, 'USD');
    expect(created.balance, -120);
    router.go('/profile/accounts?filter=debt&currency=USD');
    await tester.pumpAndSettle();
    expect(find.text('美元借款'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('debt detail preselects debt and repays with the same currency', (
    tester,
  ) async {
    final db = await _database();
    final accounts = DriftAccountRepository(db);
    await accounts.create(_account('usd-cash', 500, currency: 'USD'));
    await accounts.create(
      _account(
        'usd-other-debt',
        -10,
        type: AccountType.liability,
        currency: 'USD',
      ),
    );
    await accounts.create(
      _account(
        'usd-target-debt',
        -200,
        type: AccountType.liability,
        currency: 'USD',
      ),
    );
    await _pump(tester, db, '/profile/accounts/usd-target-debt');
    await _action(tester, 'usd-target-debt', '还款');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quick-destination-chip')),
        matching: find.text('usd-target-debt'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quick-account-chip')),
        matching: find.text('usd-cash'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('quick-destination-chip')));
    await tester.pumpAndSettle();
    final picker = find.byType(BottomSheet).last;
    expect(
      find.descendant(of: picker, matching: find.text('usd-cash')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: picker, matching: find.text('usd-target-debt')),
    );
    await tester.pumpAndSettle();
    for (final key in ['2', '0', '0']) {
      await tester.tap(find.byKey(ValueKey('amount-key-$key')));
    }
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();
    expect((await accounts.getById('usd-cash'))!.balance, 300);
    expect((await accounts.getById('usd-target-debt'))!.balance, 0);
    expect((await accounts.getById('usd-other-debt'))!.balance, -10);
    final records = await DriftTransactionRepository(db).getAll();
    expect(records.single.type, TransactionType.repayment);
    final stats = const StatisticalAnalysisService().analyze(records);
    expect(stats.totalIncome, 0);
    expect(stats.totalExpense, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account mutations target the owning book without changing browsing book',
    (tester) async {
      final db = await _database();
      final book = await DriftBookRepository(
        db,
        LocalOnlyMembershipRepository(),
      ).create(name: '独立账本', type: BookType.family, usePrimaryAssets: false);
      final accounts = DriftAccountRepository(db, bookId: book.id);
      await accounts.create(_account('other-book-cash', 10));
      await _pump(tester, db, '/profile/accounts/other-book-cash');
      await _action(tester, 'other-book-cash', '编辑账户');
      await tester.enterText(_field('账户名称'), '独立账户已编辑');
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();
      await _action(tester, 'other-book-cash', '校准余额');
      await tester.enterText(_field('实际余额'), '20');
      await tester.tap(find.text('确认校准'));
      await tester.pumpAndSettle();
      expect((await accounts.getById('other-book-cash'))!.name, '独立账户已编辑');
      expect((await accounts.getById('other-book-cash'))!.balance, 20);
      expect(
        await DriftTransactionRepository(
          db,
          bookId: SeedIds.personalBook,
        ).getAll(),
        isEmpty,
      );
      expect(
        ProviderScope.containerOf(
          tester.element(find.byKey(const ValueKey('account-detail-title'))),
        ).read(activeBookIdProvider),
        SeedIds.personalBook,
      );
      expect(
        (await DriftTransactionRepository(
          db,
          bookId: book.id,
        ).getAll()).single.amount,
        10,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<AppDatabase> _database() async {
  final db = createMemoryDatabase();
  addTearDown(db.close);
  await DatabaseSeeder(db).seedIfNeeded();
  return db;
}

Future<GoRouter> _pump(
  WidgetTester tester,
  AppDatabase db,
  String route,
) async {
  await tester.binding.setSurfaceSize(const Size(420, 935));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  final router = container.read(appRouterProvider);
  router.go(route);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _action(WidgetTester tester, String id, String label) async {
  final menu = find.byKey(ValueKey('account-actions-$id'));
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Account _account(
  String id,
  double balance, {
  AccountType type = AccountType.cash,
  String currency = 'CNY',
}) => Account(
  id: id,
  name: id,
  type: type,
  balance: balance,
  currency: currency,
  identifierSuffix: type.requiresIdentifierSuffix ? '9876' : null,
  icon: 'wallet',
  color: 0xff73963b,
  sortOrder: 100,
  isArchived: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
