import 'dart:io';

import 'package:flutter/services.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/widgets/category_icon.dart';
import 'package:jizhang_app/core/widgets/app_glass_surface.dart';
import 'package:jizhang_app/core/widgets/app_liquid_glass_surface.dart';
import 'package:jizhang_app/core/widgets/app_bottom_navigation.dart';
import 'package:jizhang_app/core/widgets/payment_brand_icon.dart';
import 'package:flutter/material.dart';

import 'support/reference_capture.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'package:jizhang_app/app/theme/app_theme_tokens.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/quick_add_sheet.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/components/category_grid.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

/// 在真实内存数据库上打开「记一笔」，用于校验新布局的真实写入结果。
Future<void> _pumpSheet(
  WidgetTester tester,
  AppDatabase database, {
  ThemeData? theme,
}) async {
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
          theme: theme ?? AppTheme.light(),
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

Future<void> _openCategoryPopover(
  WidgetTester tester,
  AppDatabase database, {
  ThemeData? theme,
}) async {
  await _pumpSheet(tester, database, theme: theme);
  await _tapRootCategory(tester, 'expense-food');
  await tester.pumpAndSettle();
}

Future<void> _tapRootCategory(WidgetTester tester, String categoryId) async {
  final category = find.byKey(ValueKey('quick-category-$categoryId'));
  await tester.ensureVisible(category);
  await tester.tap(category);
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
  testWidgets('二级分类浮层保留用于聚焦的页面遮罩且外部可关闭', (tester) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    await _openCategoryPopover(tester, database);

    final barrier = tester
        .widgetList<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier))
        .firstWhere((item) => item.semanticsLabel == '关闭二级分类');
    expect(barrier.color.value?.a, greaterThanOrEqualTo(.55));
    expect(barrier.dismissible, isTrue);

    final bubble = find.byKey(const ValueKey('quick-subcategory-bubble'));
    final bubbleRect = tester.getRect(bubble);
    await tester.tapAt(Offset(1, bubbleRect.center.dy));
    await tester.pumpAndSettle();
    expect(bubble, findsNothing);
  });

  testWidgets('二级分类浮层在普通主题下使用不透明背景', (tester) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final theme = AppTheme.light(BuiltInThemes.freshGreen);
    await _openCategoryPopover(tester, database, theme: theme);

    final surface = tester.widget<AppGlassSurface>(
      find.byKey(const ValueKey('quick-subcategory-bubble')),
    );
    expect(surface.tint?.a, 1);
  });

  testWidgets('二级分类液态玻璃浮层更亮且复用导航模糊', (tester) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final theme = AppTheme.light(BuiltInThemes.liquidGlass);
    await _openCategoryPopover(tester, database, theme: theme);

    final surface = tester.widget<AppLiquidGlassSurface>(
      find.byKey(const ValueKey('quick-subcategory-bubble')),
    );
    expect(surface.blurSigma, AppBottomNavigation.capsuleBlurSigma);
    expect(surface.tint, Colors.white);
    expect(surface.glassOpacity, .94);
    expect(surface.themeColorAccents, isFalse);
    expect(surface.borderRadius, AppNavGeometry.barHeight / 2);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quick-subcategory-bubble')),
        matching: find.byType(LiquidGlassLens),
      ),
      findsWidgets,
    );
  });

  testWidgets('二级分类玻璃保持高透中性色并启用真实折射', (tester) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final theme = AppTheme.light(BuiltInThemes.liquidGlass);
    await _openCategoryPopover(tester, database, theme: theme);

    final bubble = find.byKey(const ValueKey('quick-subcategory-bubble'));
    final surface = tester.widget<AppLiquidGlassSurface>(bubble);
    expect(surface.tint, Colors.white);
    expect(surface.glassOpacity, .94);
    expect(surface.themeColorAccents, isFalse);

    final lenses = tester.widgetList<LiquidGlassLens>(
      find.descendant(of: bubble, matching: find.byType(LiquidGlassLens)),
    );
    expect(lenses, isNotEmpty);
    final lens = lenses.first;
    final tint = lens.style.appearance.color;
    expect(tint.a, closeTo(.94, .001));
    expect(tint.r, closeTo(tint.g, .001));
    expect(tint.g, closeTo(tint.b, .001));
    expect(lens.style.refraction.effectiveDistortion, greaterThan(0));
    expect(lens.style.refraction.chromaticAberration, greaterThan(0));
  });

  testWidgets('二级分类浮层和每格布局更紧凑', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    await _pumpSheet(tester, database);
    await _tapRootCategory(tester, 'expense-food');
    await tester.pumpAndSettle();

    final bubble = find.byKey(const ValueKey('quick-subcategory-bubble'));
    expect(tester.getSize(bubble).width, lessThanOrEqualTo(344));
    final grid = tester.widget<GridView>(
      find.descendant(of: bubble, matching: find.byType(GridView)),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 5);
    expect(delegate.mainAxisExtent, closeTo(58, .1));
    final icons = tester.widgetList<CategoryIcon>(
      find.descendant(of: bubble, matching: find.byType(CategoryIcon)),
    );
    expect(icons.every((icon) => icon.size == 24), isTrue);
  });

  testWidgets('一级分类其他在首位，其余按 sortOrder 倒序', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftCategoryRepository(database);
    final allCategories = await repository.getActive();

    List<String> expectedIds(CategoryType type) {
      final roots = allCategories
          .where((item) => item.parentId == null && item.type == type)
          .toList();
      roots.sort((a, b) {
        final aIsOther =
            a.name.startsWith('其他') ||
            a.id == 'expense-other' ||
            a.id == 'income-other';
        final bIsOther =
            b.name.startsWith('其他') ||
            b.id == 'expense-other' ||
            b.id == 'income-other';
        if (aIsOther != bIsOther) return aIsOther ? -1 : 1;
        return b.sortOrder.compareTo(a.sortOrder);
      });
      return roots.map((item) => item.id).toList();
    }

    await _pumpSheet(tester, database);
    for (final (type, key) in [
      (CategoryType.expense, 'quick-type-expense'),
      (CategoryType.income, 'quick-type-income'),
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      final grid = tester.widget<CategoryGrid>(find.byType(CategoryGrid));
      expect(
        grid.categories.map((item) => item.id).toList(),
        expectedIds(type),
        reason: '${type.name} 一级分类应将“其他”放首位，其余倒序',
      );
    }
  });

  testWidgets('液态玻璃子分类点击显示导航同款移动选中胶囊', (tester) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final theme = AppTheme.light(BuiltInThemes.liquidGlass);
    final categories = await DriftCategoryRepository(database).getActive();
    final child = categories.firstWhere(
      (category) => category.parentId == 'expense-food',
    );
    await _openCategoryPopover(tester, database, theme: theme);

    await tester.tap(find.byKey(ValueKey('quick-subcategory-${child.id}')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('quick-subcategory-liquid-pill')),
      findsOneWidget,
    );
    final pill = tester.widget<AnimatedPositioned>(
      find.byKey(const ValueKey('quick-subcategory-liquid-pill')),
    );
    expect(pill.duration, const Duration(milliseconds: 220));
    final movingSurface = tester.widget<AppLiquidGlassSurface>(
      find.byKey(const ValueKey('quick-subcategory-liquid-pill-surface')),
    );
    expect(movingSurface.blurSigma, AppBottomNavigation.capsuleBlurSigma);
    expect(movingSurface.themeColorAccents, isFalse);
    final movingLens = tester.widget<LiquidGlassLens>(
      find.descendant(
        of: find.byKey(
          const ValueKey('quick-subcategory-liquid-pill-surface'),
        ),
        matching: find.byType(LiquidGlassLens),
      ),
    );
    final movingTint = movingLens.style.appearance.color;
    expect(movingTint.r, closeTo(movingTint.g, .001));
    expect(movingTint.g, closeTo(movingTint.b, .001));
    expect(movingLens.style.refraction.effectiveDistortion, greaterThan(0));
    expect(movingLens.style.refraction.chromaticAberration, greaterThan(0));
    expect(
      find.byKey(const ValueKey('quick-subcategory-picker')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quick-subcategory-picker')),
      findsNothing,
    );
  });

  testWidgets(
    'many subcategories scroll without selecting and last item saves',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.binding.setSurfaceSize(null);
      });
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      final repository = DriftCategoryRepository(db);
      for (var i = 0; i < 40; i++) {
        await repository.create(
          Category(
            id: 'extra-$i',
            parentId: 'expense-food',
            name: '分类$i',
            icon: 'restaurant_outlined',
            type: CategoryType.expense,
            sortOrder: 100 + i,
            isDefault: false,
            isArchived: false,
          ),
        );
      }
      await _pumpSheet(tester, db);
      await _tapRootCategory(tester, 'expense-food');
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('quick-subcategory-extra-39'));
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('quick-subcategory-picker')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(last, 220, scrollable: scroll);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('quick-subcategory-bubble')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(last);
      await tester.pumpAndSettle();
      await _tapKeys(tester, ['8']);
      await tester.tap(find.byKey(const ValueKey('quick-done')));
      await tester.pumpAndSettle();
      expect((await _saved(db)).single.subcategoryId, 'extra-39');
    },
  );

  for (final theme in [
    BuiltInThemes.freshGreen,
    BuiltInThemes.mistBlue,
    BuiltInThemes.liquidGlass,
  ]) {
    testWidgets('category bubble follows theme ${theme.id}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        final iconFont = File(
          'E:/jizhang_1/tools/flutter_sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (await iconFont.exists()) {
          final bytes = await iconFont.readAsBytes();
          await (FontLoader(
            'MaterialIcons',
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
        final font = File('C:/Windows/Fonts/msyh.ttc');
        if (await font.exists()) {
          final bytes = await font.readAsBytes();
          await (FontLoader(
            'Category QA',
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
      });
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      final themed = AppTheme.light(theme);
      await _pumpSheet(
        tester,
        db,
        theme: themed.copyWith(
          textTheme: themed.textTheme.apply(fontFamily: 'Category QA'),
        ),
      );
      await _tapRootCategory(tester, 'expense-food');
      await tester.pumpAndSettle();
      expect(find.text('按住滑动选择，松手确认'), findsNothing);
      final icons = tester.widgetList<CategoryIcon>(
        find.descendant(
          of: find.byKey(const ValueKey('quick-subcategory-bubble')),
          matching: find.byType(CategoryIcon),
        ),
      );
      expect(
        icons.every(
          (icon) =>
              icon.monochrome &&
              icon.bare &&
              icon.size == 24 &&
              !icon.illustrated,
        ),
        isTrue,
      );
      expect(find.text('不细分'), findsNothing);
      if (theme.style == AppThemeStyle.liquidGlass) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('quick-subcategory-bubble')),
            matching: find.byType(BackdropFilter),
          ),
          findsWidgets,
        );
      }
      expect(tester.takeException(), isNull);
      final bounds = tester.getRect(
        find.byKey(const ValueKey('quick-subcategory-bubble')),
      );
      expect(bounds.right, lessThanOrEqualTo(393));
      expect(bounds.bottom, lessThanOrEqualTo(844));
      await captureReference(
        tester,
        find.byKey(const ValueKey('quick-capture')),
        '../category-compact-2026-09-23/${theme.id}',
      );
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('quick-subcategory-bubble')),
        findsNothing,
      );
    });
  }

  testWidgets('safe area, full page and dedicated child picker visual check', (
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
    expect(
      find.byKey(const ValueKey('quick-subcategory-strip')),
      findsNothing,
      reason: '二级分类不应默认内联展示',
    );
    await _tapRootCategory(tester, food.id);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quick-subcategory-picker')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('按住滑动选择，松手确认'), findsNothing);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == PaymentBrand.wechat.asset,
      ),
      findsOneWidget,
    );
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

    // 二级分类只在点击一级分类后出现，不占用默认记账页面空间。
    expect(find.byKey(const ValueKey('quick-subcategory-strip')), findsNothing);
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
    expect(ai.width, lessThan(104));
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
    expect(decoration.isDense, isTrue);
    expect(decoration.contentPadding, const EdgeInsets.symmetric(vertical: 10));
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
    final amountContext = tester.element(
      find.byKey(const ValueKey('quick-amount-display')),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('quick-amount-display')))
          .style
          ?.color,
      amountContext.appPrimary,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('quick-amount-expression')))
          .style
          ?.color,
      amountContext.appPrimaryText,
    );

    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    final saved = await _saved(database);
    expect(saved, hasLength(1));
    expect(saved.single.amountInCents, 20000);
    expect(saved.single.metadataJson, contains('"formula":"100*2"'));
    expect(saved.single.type, TransactionType.expense.name);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(
      snackBar.backgroundColor,
      tester.element(find.byType(SnackBar)).appSurface,
    );
    expect(
      snackBar.margin!.resolve(TextDirection.ltr).bottom,
      greaterThan(100),
    );
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

  testWidgets('点击一级分类后弹出二级分类窗并写入 subcategoryId', (tester) async {
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

    await _tapRootCategory(tester, food.id);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quick-subcategory-picker')),
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
    final mapped = await DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    ).getAll();
    expect(mapped.single.subcategoryName, '早餐');
    expect(mapped.single.displayCategoryPath, '餐饮 · 早餐');
    expect(tester.takeException(), isNull);
  });

  testWidgets('二级分类图标跟随手指放大并在松手时选中', (tester) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftCategoryRepository(database);
    final categories = await repository.getActive();
    final food = categories.firstWhere((item) => item.name == '餐饮');
    final children = categories
        .where((item) => item.parentId == food.id)
        .take(2)
        .toList(growable: false);
    expect(children, hasLength(2));

    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpSheet(tester, database);

    await _tapRootCategory(tester, food.id);
    await tester.pumpAndSettle();

    final first = find.byKey(
      ValueKey('quick-subcategory-${children.first.id}'),
    );
    final second = find.byKey(
      ValueKey('quick-subcategory-${children.last.id}'),
    );
    final firstFocus = find.byKey(
      ValueKey('quick-subcategory-focus-${children.first.id}'),
    );
    final secondFocus = find.byKey(
      ValueKey('quick-subcategory-focus-${children.last.id}'),
    );
    final gesture = await tester.startGesture(tester.getCenter(first));
    await tester.pump(const Duration(milliseconds: 16));
    final firstScale = tester
        .widget<Transform>(firstFocus)
        .transform
        .getMaxScaleOnAxis();
    expect(firstScale, greaterThan(1));
    await gesture.moveTo(tester.getCenter(second));
    await tester.pump(const Duration(milliseconds: 16));
    final secondScale = tester
        .widget<Transform>(secondFocus)
        .transform
        .getMaxScaleOnAxis();
    expect(secondScale, greaterThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quick-subcategory-picker')),
      findsNothing,
    );
    await _tapKeys(tester, ['1']);
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    final saved = await _saved(database);
    expect(saved.single.subcategoryId, children.last.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('记一笔转场完成，系统返回依次关闭分类浮层和记一笔', (tester) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpSheet(tester, database);
    final launchButton = find.byKey(const ValueKey('quick-capture'));
    await tester.tap(launchButton);
    await tester.pump();

    final sheet = find.byType(QuickAddSheet);
    expect(sheet, findsOneWidget);
    final route = ModalRoute.of(tester.element(sheet))!;
    await tester.pumpAndSettle();
    expect(route.animation!.status, AnimationStatus.completed);

    final food = (await DriftCategoryRepository(
      database,
    ).getActive()).firstWhere((category) => category.name == '餐饮');
    await _tapRootCategory(tester, food.id);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quick-subcategory-bubble')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quick-subcategory-bubble')),
      findsNothing,
    );
    expect(sheet, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(route.animation!.status, AnimationStatus.reverse);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(launchButton, findsOneWidget);
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
      // 二级分类弹窗需要在窄屏和大字号下保持可用。
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
        findsNothing,
      );
      await _tapRootCategory(tester, food.id);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('quick-subcategory-picker')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

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
      final finder = find.byKey(ValueKey(key));
      final chip = tester.widget<Material>(
        find.descendant(of: finder, matching: find.byType(Material)).first,
      );
      expect(
        chip.color,
        tester.element(finder).appPrimarySoft,
        reason: '$key 应默认使用当前主题的选中态颜色',
      );
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
