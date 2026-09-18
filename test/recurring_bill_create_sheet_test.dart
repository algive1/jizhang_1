import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/recurring_bill.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/recurring/presentation/recurring_bill_create_sheet.dart';

void main() {
  testWidgets('prototype sheet saves a real monthly recurring bill', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final accounts = await DriftAccountRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getActive();
    final categories = await DriftCategoryRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getActive();
    final start = DateTime(2026, 9, 14);
    final bill = RecurringBill(
      id: 'recurring-create-ui',
      bookId: SeedIds.personalBook,
      name: '',
      type: RecurringBillType.other,
      amount: 0,
      cycle: RecurringBillCycle.monthly,
      startDate: start,
      nextDate: start,
      createdAt: start,
      updatedAt: start,
    );
    RecurringBill? result;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        accountsProvider.overrideWithValue(AsyncData(accounts)),
        categoriesProvider.overrideWithValue(AsyncData(categories)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open-recurring-create-test'),
                onPressed: () async {
                  result = await RecurringBillCreateSheet.show(context, bill);
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-recurring-create-test')));
    await tester.pumpAndSettle();
    expect(find.text('新增周期账单'), findsOneWidget);
    expect(find.text('账单信息'), findsOneWidget);
    expect(find.text('重复规则'), findsOneWidget);
    expect(find.text('记账设置'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('recurring-create-summary')),
        matching: find.textContaining('每 1 个月'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('recurring-create-save')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('recurring-create-name')),
      '房租',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recurring-create-amount')),
      '3000',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('recurring-create-account')),
    );
    await tester.tap(find.byKey(const ValueKey('recurring-create-account')));
    await tester.pumpAndSettle();
    expect(find.text('微信-3316'), findsOneWidget);
    await tester.tap(find.text('微信-3316'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('recurring-create-category')),
    );
    await tester.tap(find.byKey(const ValueKey('recurring-create-category')));
    await tester.pumpAndSettle();
    expect(find.text('餐饮'), findsOneWidget);
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('recurring-create-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, '房租');
    expect(result!.amount, 3000);
    expect(result!.type, RecurringBillType.other);
    expect(result!.cycle, RecurringBillCycle.monthly);
    expect(result!.accountId, SeedIds.wechatAccount);
    expect(result!.categoryId, 'expense-food');
    expect(result!.reminder, isTrue);
    expect(result!.reminderDays, 1);
    expect(result!.autoRecord, isFalse);
    expect(result!.nextDate, DateTime(2026, 9, 14));
  });

  testWidgets('prototype sheet switches income and weekly schedule', (
    tester,
  ) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final accounts = await DriftAccountRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getActive();
    final categories = await DriftCategoryRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getActive();
    final date = DateTime(2026, 9, 14);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        accountsProvider.overrideWithValue(AsyncData(accounts)),
        categoriesProvider.overrideWithValue(AsyncData(categories)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open-recurring-create-test'),
                onPressed: () => RecurringBillCreateSheet.show(
                  context,
                  RecurringBill(
                    id: 'recurring-create-interaction',
                    bookId: SeedIds.personalBook,
                    name: '',
                    type: RecurringBillType.other,
                    amount: 0,
                    cycle: RecurringBillCycle.monthly,
                    startDate: date,
                    nextDate: date,
                    createdAt: date,
                    updatedAt: date,
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-recurring-create-test')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    expect(find.text('收入'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('recurring-cycle-weekly')),
    );
    await tester.tap(find.byKey(const ValueKey('recurring-cycle-weekly')));
    await tester.pumpAndSettle();
    expect(find.text('每 1 周'), findsOneWidget);
    expect(find.text('扣款日期'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('recurring-create-frequency')),
    );
    await tester.tap(find.byKey(const ValueKey('recurring-create-frequency')));
    await tester.pumpAndSettle();
    expect(find.text('每 2 周'), findsOneWidget);
    await tester.tap(find.text('每 2 周'));
    await tester.pumpAndSettle();
    expect(find.text('每 2 周'), findsOneWidget);
  });
}
