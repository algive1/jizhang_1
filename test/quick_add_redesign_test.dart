import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/quick_add_sheet.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';

/// 在真实内存数据库上打开「记一笔」，用于校验新布局的真实写入结果。
Future<void> _pumpSheet(WidgetTester tester, AppDatabase database) async {
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(database)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const QuickAddSheet(),
                ),
                child: const Text('打开记一笔'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('打开记一笔'));
  await tester.pumpAndSettle();
}

Future<AppDatabase> _openSheet(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final database = createMemoryDatabase();
  addTearDown(database.close);
  await DatabaseSeeder(database).seedIfNeeded();
  await _pumpSheet(tester, database);
  return database;
}

Future<void> _tapKeys(WidgetTester tester, List<String> keys) async {
  for (final key in keys) {
    await tester.tap(find.byKey(ValueKey('amount-key-$key')));
  }
  await tester.pumpAndSettle();
}

/// 直接读取 DAO 实体：金额以「分」存储，类型以枚举名存储。
Future<List<TransactionEntity>> _saved(AppDatabase database) =>
    database.transactionDao.getActive(bookId: SeedIds.personalBook);

void main() {
  testWidgets('记一笔默认展示四类页签、常驻键盘与各属性 chip', (tester) async {
    await _openSheet(tester);

    expect(find.byKey(const ValueKey('quick-type-expense')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-type-income')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-type-transfer')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-type-debt')), findsOneWidget);

    expect(find.byKey(const ValueKey('quick-category-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-amount-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-account-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-book-selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-date-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-attachment-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-image-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-recurring-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-ai-entry')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-voice-entry')), findsOneWidget);

    expect(find.byKey(const ValueKey('amount-key-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('amount-key-+')), findsOneWidget);
    expect(find.byKey(const ValueKey('amount-key-×')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-repeat')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-done')), findsOneWidget);

    // 默认分类没有子分类时，不渲染空的子分类条。
    expect(find.byKey(const ValueKey('quick-subcategory-strip')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('计算器表达式按求值结果入账', (tester) async {
    final database = await _openSheet(tester);

    await _tapKeys(tester, ['1', '0', '0', '×', '2']);
    expect(find.text('100*2'), findsOneWidget);
    expect(find.text('= ¥200.00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    final saved = await _saved(database);
    expect(saved, hasLength(1));
    expect(saved.single.amountInCents, 20000);
    expect(saved.single.type, TransactionType.expense.name);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未完成的表达式会被拒绝保存', (tester) async {
    final database = await _openSheet(tester);

    await _tapKeys(tester, ['1', '0', '0', '+']);
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    expect(find.text('请先完成金额计算'), findsOneWidget);
    expect(await _saved(database), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('「再记」保存后保留当前页并清空金额', (tester) async {
    final database = await _openSheet(tester);

    await _tapKeys(tester, ['1', '2']);
    await tester.tap(find.byKey(const ValueKey('quick-repeat')));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(find.text('¥ 0.00'), findsOneWidget);
    expect(find.text('已保存，继续记下一笔'), findsOneWidget);
    var saved = await _saved(database);
    expect(saved, hasLength(1));
    expect(saved.single.amountInCents, 1200);

    await _tapKeys(tester, ['5']);
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    saved = await _saved(database);
    expect(saved, hasLength(2));
    expect(
      saved.map((item) => item.amountInCents).toList()..sort(),
      <int>[500, 1200],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('债务页签的借入使用收入分类入账', (tester) async {
    final database = await _openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('quick-type-debt')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-debt-borrow')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-debt-lend')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-debt-repayment')), findsOneWidget);

    await _tapKeys(tester, ['8']);
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    final saved = await _saved(database);
    expect(saved, hasLength(1));
    expect(saved.single.type, TransactionType.borrow.name);
    expect(saved.single.categoryId, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('债务页签的还款走双账户且不带分类', (tester) async {
    final database = await _openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('quick-type-debt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-debt-repayment')));
    await tester.pumpAndSettle();

    expect(find.text('还款账户'), findsOneWidget);
    expect(find.text('债务账户'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-category-section')), findsNothing);

    await _tapKeys(tester, ['5', '0']);
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    final saved = await _saved(database);
    expect(saved, hasLength(1));
    expect(saved.single.type, TransactionType.repayment.name);
    expect(saved.single.amountInCents, 5000);
    expect(saved.single.destinationAccountId, isNotNull);
    expect(saved.single.destinationAccountId, isNot(saved.single.accountId));
    expect(saved.single.categoryId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('子分类条渲染真实子分类并写入 subcategoryId', (tester) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftCategoryRepository(database);
    final roots = await repository.getActive();
    final food = roots.firstWhere((item) => item.name == '餐饮');
    await repository.create(
      Category(
        bookId: SeedIds.personalBook,
        id: 'sub-breakfast',
        parentId: food.id,
        name: '早餐',
        icon: 'restaurant_outlined',
        type: CategoryType.expense,
        sortOrder: 0,
        isDefault: false,
        isArchived: false,
      ),
    );
    // 子分类不会作为主网格的第一级分类重复出现。
    final refreshed = await repository.getActive();
    expect(refreshed.where((item) => item.parentId == null && item.name == '早餐'), isEmpty);

    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpSheet(tester, database);

    await tester.tap(find.byKey(ValueKey('quick-category-${food.id}')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quick-subcategory-strip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('quick-subcategory-sub-breakfast')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('quick-subcategory-sub-breakfast')),
    );
    await tester.pumpAndSettle();
    await _tapKeys(tester, ['9']);
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    final saved = await _saved(database);
    expect(saved, hasLength(1));
    expect(saved.single.subcategoryId, 'sub-breakfast');
    expect(saved.single.categoryId, food.id);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets('320dp + 字号 $scale 下记一笔不溢出', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.binding.setSurfaceSize(null);
      });
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      await _pumpSheet(tester, database);

      // 长表达式 + 大结果是最容易横向溢出的组合。
      await _tapKeys(tester, ['9', '9', '9', '9', '9', '9', '9', '×', '9']);
      expect(find.byKey(const ValueKey('quick-amount-result')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 债务/转账的分账卡片同样要在窄屏成立。
      await tester.tap(find.byKey(const ValueKey('quick-type-transfer')));
      await tester.pumpAndSettle();
      expect(find.text('转出'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quick-type-debt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick-debt-repayment')));
      await tester.pumpAndSettle();
      expect(find.text('还款账户'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 窄屏下 chip 行可横向滚动，「更多」需要先滚进可视区。
      await tester.ensureVisible(find.byKey(const ValueKey('quick-more-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick-more-chip')));
      await tester.pumpAndSettle();
      expect(find.text('更多选项'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
