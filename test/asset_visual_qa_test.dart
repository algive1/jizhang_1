import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/constants/app_assets.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/accounts/presentation/asset_overview_page.dart';

import 'support/reference_capture.dart';

void main() {
  testWidgets('asset overview visual qa at prototype scale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);
    final accountRepository = DriftAccountRepository(database);
    await accountRepository.create(
      _fixtureAccount(
        id: 'fixture-bank-3827',
        name: '工商银行',
        type: AccountType.debitCard,
        suffix: '3827',
        balance: 28630,
      ),
    );
    await accountRepository.create(
      _fixtureAccount(
        id: 'fixture-credit-2356',
        name: '信用卡',
        type: AccountType.creditCard,
        suffix: '2356',
        balance: -5320,
      ),
    );
    await accountRepository.create(
      _fixtureAccount(
        id: 'fixture-loan',
        name: '其他负债',
        type: AccountType.liability,
        balance: -2934,
      ),
    );
    // Keep the visual fixture aligned with the prototype's four asset cards.
    await accountRepository.archive(SeedIds.cashAccount);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    final router = container.read(appRouterProvider);
    await loadReferenceFonts(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 24)),
            child: RepaintBoundary(
              key: const ValueKey('qa-boundary'),
              child: child!,
            ),
          ),
        ),
      ),
    );
    router.go('/profile/assets');
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(AppAssets.homeAssetScene),
        tester.element(find.byType(AssetOverviewPage)),
      );
      await precacheImage(
        const AssetImage(AppAssets.liabilityPig),
        tester.element(find.byType(AssetOverviewPage)),
      );
    });
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('qa-boundary')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/qa/asset-overview-fidelity-2026-09-12/round3.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}

Account _fixtureAccount({
  required String id,
  required String name,
  required AccountType type,
  String? suffix,
  required double balance,
}) {
  final now = DateTime(2026, 9, 12);
  return Account(
    id: id,
    name: name,
    type: type,
    balance: balance,
    currency: 'CNY',
    icon: 'account_balance_wallet_outlined',
    color: 0xff73963b,
    sortOrder: 9,
    isArchived: false,
    identifierSuffix: suffix,
    createdAt: now,
    updatedAt: now,
  );
}
