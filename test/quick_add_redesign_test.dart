import 'package:flutter/material.dart';

import 'support/reference_capture.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/app/theme/app_colors.dart';
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
      child: RepaintBoundary(
        key: const ValueKey('quick-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showQuickAddSheet(context),
                  child: const Text('打开记一笔'),
                ),
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
  testWidgets('safe area, inline children and compact keyboard visual check', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 844);
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.reset);
    await loadReferenceFonts(tester);
    final database = await _openSheet(tester);
    await _tapKeys(tester, ['1', '0', '0', '×', '2']);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('quick-type-expense'))).dy,
      greaterThan(44),
    );
    final food = (await DriftCategoryRepository(
      database,
    ).getActive()).firstWhere((item) => item.name == '餐饮');
    final parent = tester.getRect(
      find.byKey(ValueKey('quick-category-${food.id}')),
    );
    final children = tester.getRect(
      find.byKey(const ValueKey('quick-subcategory-strip')),
    );
    expect(children.top, greaterThanOrEqualTo(parent.bottom));
    expect(children.top - parent.bottom, lessThan(10));
    expect(
      tester.getBottomRight(find.byKey(const ValueKey('quick-done'))).dy,
      lessThanOrEqualTo(810),
    );
    expect(find.byTooltip('清空金额'), findsNothing);
    final sheetSurface = tester.getRect(
      find.byKey(const ValueKey('quick-sheet-surface')),
    );
    expect(
      sheetSurface.bottom,
      closeTo(844, .1),
      reason: '记一笔背景必须覆盖到底部系统手势区，不能透出底部导航',
    );
    final amountCard = tester.getRect(
      find.byKey(const ValueKey('quick-amount-input')),
    );
    final result = tester.getRect(
      find.byKey(const ValueKey('quick-amount-display')),
    );
    expect(result.right, closeTo(amountCard.right - 14, .1));
    expect(tester.takeException(), isNull);
    await captureReference(
      tester,
      find.byKey(const ValueKey('quick-capture')),
      '../quick-add-layout-2026-09-14/entry-393',
    );
    final viewport = find.byKey(const ValueKey('quick-category-section'));
    await tester.drag(viewport, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureReference(
      tester,
      find.byKey(const ValueKey('quick-capture')),
      '../quick-add-layout-2026-09-14/categories-scrolled',
    );
  });

  testWidgets('记一笔默认展示四类页签、常驻键盘与各属性 chip', (tester) async {
    await _openSheet(tester);

    expect(find.byKey(const ValueKey('quick-type-expense')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-type-income')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-type-transfer')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-type-debt')), findsOneWidget);

    expect(
      find.byKey(const ValueKey('quick-category-section')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('quick-amount-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-account-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-book-selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-date-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-attachment-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-image-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-recurring-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-ai-entry')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-voice-entry')), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);

    expect(find.byKey(const ValueKey('amount-key-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('amount-key-+')), findsOneWidget);
    expect(find.byKey(const ValueKey('amount-key-×')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-repeat')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-done')), findsOneWidget);

    // 默认餐饮分类从数据库载入可管理的二级分类。
    expect(
      find.byKey(const ValueKey('quick-subcategory-strip')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('备注输入框点按外部后可以失去焦点', (tester) async {
    await _openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('quick-note-field')));
    await tester.enterText(
      find.byKey(const ValueKey('quick-note-field')),
      '备注',
    );
    await tester.tap(find.byKey(const ValueKey('amount-key-1')));
    await tester.pumpAndSettle();

    expect(find.text('= ¥1.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('备注行保持紧凑并与输入卡片内容对齐', (tester) async {
    await _openSheet(tester);

    final note = tester.getRect(find.byKey(const ValueKey('quick-note-field')));
    final amount = tester.getRect(
      find.byKey(const ValueKey('quick-amount-input')),
    );
    final detail = tester.getRect(
      find.byKey(const ValueKey('quick-detail-card')),
    );
    final decoration = tester
        .widget<TextField>(find.byKey(const ValueKey('quick-note-field')))
        .decoration!;

    final ai = tester.getRect(find.byKey(const ValueKey('quick-ai-entry')));
    final voice = tester.getRect(
      find.byKey(const ValueKey('quick-voice-entry')),
    );

    expect(note.height, closeTo(40, .1));
    expect(ai.height, closeTo(36, .1));
    expect(ai.width, lessThan(92));
    expect(voice.width, closeTo(36, .1));
    expect(voice.height, closeTo(36, .1));
    expect(
      note.width,
      greaterThan(ai.width * 1.7),
      reason: 'AI/语音入口压缩后，备注输入区应继续占据这一行的主要宽度',
    );
    expect(note.bottom, lessThan(amount.top));
    expect(detail.top, lessThanOrEqualTo(note.top));
    expect(detail.bottom, greaterThanOrEqualTo(amount.bottom));
    expect(decoration.isCollapsed, isTrue);
    expect(decoration.constraints, const BoxConstraints.tightFor(height: 40));
    expect(decoration.enabledBorder, InputBorder.none);
    expect(decoration.focusedBorder, InputBorder.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('计算器表达式按求值结果入账', (tester) async {
    final database = await _openSheet(tester);

    await _tapKeys(tester, ['1', '0', '0', '×', '2']);
    // 输入表达式为深色，计算结果为绿色。
    expect(find.text('100*2'), findsOneWidget);
    expect(find.text('= ¥200.00'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('quick-amount-display')))
          .style
          ?.color,
      AppColors.primaryDark,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('quick-amount-expression')))
          .style
          ?.color,
      AppColors.textPrimary,
    );

    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    final saved = await _saved(database);
    expect(saved, hasLength(1));
    expect(saved.single.amountInCents, 20000);
    expect(saved.single.metadataJson, contains('"formula":"100*2"'));
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

  testWidgets('「再记」只清空输入并保留当前页，不创建流水', (tester) async {
    final database = await _openSheet(tester);

    await _tapKeys(tester, ['1', '2']);
    await tester.tap(find.byKey(const ValueKey('quick-repeat')));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(find.text('= ¥0.00'), findsOneWidget);
    var saved = await _saved(database);
    expect(saved, isEmpty);

    await _tapKeys(tester, ['5']);
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    saved = await _saved(database);
    expect(saved, hasLength(1));
    expect(saved.single.amountInCents, 500);
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
    expect(
      refreshed.where((item) => item.parentId == null && item.name == '早餐'),
      isEmpty,
    );

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
      // 子分类条固定在高度里，大字号最容易在它底部溢出。
      final repository = DriftCategoryRepository(database);
      final food = (await repository.getActive()).firstWhere(
        (item) => item.name == '餐饮',
      );
      await repository.create(
        Category(
          bookId: SeedIds.personalBook,
          id: 'sub-narrow',
          parentId: food.id,
          name: '早点',
          icon: 'restaurant_outlined',
          type: CategoryType.expense,
          sortOrder: 0,
          isDefault: false,
          isArchived: false,
        ),
      );
      await _pumpSheet(tester, database);
      expect(
        find.byKey(const ValueKey('quick-subcategory-strip')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // 长表达式 + 大结果是最容易横向溢出的组合。
      await _tapKeys(tester, ['9', '9', '9', '9', '9', '9', '9', '×', '9']);
      expect(
        find.byKey(const ValueKey('quick-amount-expression')),
        findsOneWidget,
      );
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

      expect(find.byKey(const ValueKey('quick-more-chip')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('账户/报销/账本 chip 默认呈选中态，定期付命名正确', (tester) async {
    await _openSheet(tester);

    for (final key in [
      'quick-account-chip',
      'quick-reimbursement-chip',
      'quick-book-selector',
    ]) {
      final chip = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(chip.color, AppColors.primarySoft, reason: '$key 应默认选中');
    }
    expect(find.text('定期付'), findsOneWidget);
    expect(find.text('周期付'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('定期付确认规则后创建当前流水和周期规则', (tester) async {
    final database = await _openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('quick-recurring-chip')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('recurring-create-frequency')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recurring-create-auto-record')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recurring-create-reminder')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('recurring-create-save')));
    await tester.pumpAndSettle();
    await _tapKeys(tester, ['2']);
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();
    final first = (await _saved(database)).single;
    expect(first.isRecurring, isTrue);
    expect(first.isOneTime, isFalse);
    final plans = await database.recurringBillDao.getAll(
      bookId: SeedIds.personalBook,
    );
    expect(plans, hasLength(1));
    expect(first.metadataJson, contains(plans.single.id));
  });

  testWidgets('100*200 完成即按计算结果 20000 入账', (tester) async {
    final database = await _openSheet(tester);

    await _tapKeys(tester, ['1', '0', '0', '×', '2', '0', '0']);
    expect(find.text('100*200'), findsOneWidget);
    expect(find.text('= ¥20000.00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    final saved = await _saved(database);
    expect(saved, hasLength(1));
    expect(saved.single.amountInCents, 2000000);
    expect(tester.takeException(), isNull);
  });
}
