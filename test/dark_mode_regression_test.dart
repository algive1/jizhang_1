import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/components/number_keyboard.dart';
import 'package:jizhang_app/features/books/presentation/book_selector.dart';
import 'package:jizhang_app/features/investments/data/investment_repository.dart';
import 'package:jizhang_app/features/investments/domain/investment_portfolio.dart';
import 'package:jizhang_app/features/investments/presentation/investment_overview_page.dart';
import 'package:jizhang_app/features/legal/presentation/legal_document_page.dart';
import 'package:jizhang_app/features/membership/data/membership_catalog.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/membership/presentation/membership_page.dart';

ThemeData _darkTheme() => AppTheme.dark(BuiltInThemes.liquidGlass);

void main() {
  testWidgets('membership page follows the global dark palette', (tester) async {
    final membership = await LocalOnlyMembershipRepository().getCurrent();
    final catalog = await ConfiguredMembershipCatalogRepository().load();
    final theme = _darkTheme();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membershipProvider.overrideWithValue(AsyncData(membership)),
          membershipCatalogProvider.overrideWithValue(AsyncData(catalog)),
        ],
        child: MaterialApp(
          theme: theme,
          home: const MembershipPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, theme.scaffoldBackgroundColor);

    final heroTitle = tester.widget<Text>(find.text('成为会员'));
    expect(heroTitle.style?.color, const Color(0xFFA8CF7B));

    final overlays = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(
      overlays.any(
        (region) =>
            region.value.systemNavigationBarColor ==
                theme.scaffoldBackgroundColor &&
            region.value.systemNavigationBarIconBrightness == Brightness.light,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('legal pages use semantic dark surfaces and text', (tester) async {
    final theme = _darkTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const LegalDocumentsPage(),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, theme.scaffoldBackgroundColor);

    final userAgreement = find.text('用户协议');
    final materials = tester.widgetList<Material>(
      find.ancestor(of: userAgreement, matching: find.byType(Material)),
    );
    expect(
      materials.any((material) => material.color == theme.colorScheme.surface),
      isTrue,
    );

    await tester.tap(userAgreement);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final intro = tester.widget<Text>(
      find.textContaining('使用好好记账前').first,
    );
    expect(intro.style?.color, theme.colorScheme.onSurface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('investment overview does not force a light page in dark mode',
      (tester) async {
    final theme = _darkTheme();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          investmentPortfolioProvider.overrideWith(
            (ref) => Stream.value(InvestmentPortfolio.empty),
          ),
        ],
        child: MaterialApp(
          theme: theme,
          home: const InvestmentOverviewPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, theme.scaffoldBackgroundColor);
    expect(find.text('投资管理'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookkeeping keypad keeps dark semantic surfaces and contrast',
      (tester) async {
    final theme = _darkTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: NumberKeyboard(
            canRepeat: false,
            isSaving: false,
            onKey: (_) {},
            onBackspace: () {},
            onDone: () {},
            onRepeat: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plusMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('amount-key-+')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(plusMaterial.color, theme.colorScheme.surfaceContainerLow);

    final done = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('quick-done')),
        matching: find.text('完成'),
      ),
    );
    expect(done.style?.color, theme.colorScheme.onPrimary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('book shelf chrome follows dark theme outside illustrated shelf',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final theme = _darkTheme();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: theme,
          home: const Scaffold(body: BookSelectorButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BookSelectorButton));
    await tester.pumpAndSettle();

    final shelfMaterials = tester.widgetList<Material>(
      find.ancestor(
        of: find.text('记录生活  更好地生活'),
        matching: find.byType(Material),
      ),
    );
    expect(
      shelfMaterials.any((material) => material.color == theme.colorScheme.surface),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
