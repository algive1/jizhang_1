import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/constants/app_assets.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/home/presentation/home_cards.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';

import 'support/reference_capture.dart';

void main() {
  testWidgets(
    'capture real home, scrolled home and book drawer with isolated data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadReferenceFonts(tester);
      debugPrint('QA fonts loaded');
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded(includeDemoData: true);
      debugPrint('QA database seeded');
      final books = DriftBookRepository(db, LocalOnlyMembershipRepository());
      await books.create(name: '家庭账本', type: BookType.family);
      await books.create(name: '企业账本', type: BookType.enterprise);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final router = container.read(appRouterProvider);
      const boundaryKey = ValueKey('reference-page-boundary');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerConfig: router,
              theme: AppTheme.light().copyWith(
                textTheme: AppTheme.light().textTheme.apply(
                  fontFamily: 'Reference Latin',
                  fontFamilyFallback: const ['PingFang SC'],
                ),
              ),
              locale: const Locale('zh', 'CN'),
              supportedLocales: const [Locale('zh', 'CN')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      debugPrint('QA page settled');
      await tester.runAsync(() async {
        final context = tester.element(find.byType(HomeSpendingGoalCard));
        for (final asset in [
          'assets/images/user_avatar.png',
          'assets/images/home_living_scene.png',
          'assets/images/pro_cloud_reference_v1.png',
          'assets/images/leaves_reference_v1.png',
          AppAssets.bookshelfEmpty,
        ]) {
          debugPrint('QA loading $asset');
          await precacheImage(AssetImage(asset), context);
        }
      });
      await tester.pumpAndSettle();
      debugPrint('QA images settled');
      expect(tester.takeException(), isNull);
      await captureReference(tester, find.byKey(boundaryKey), 'home-upper');
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureReference(tester, find.byKey(boundaryKey), 'home-lower');
      await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的账本').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureReference(tester, find.byKey(boundaryKey), 'bookshelf');
      debugPrint('QA captures complete');
      await tester.pumpWidget(const SizedBox.shrink());
      debugPrint('QA unmounted');
      container.dispose();
      debugPrint('QA providers disposed');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
