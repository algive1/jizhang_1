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
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/profile/data/profile_stats.dart';
import 'package:jizhang_app/features/profile/presentation/profile_cards.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';

import 'support/reference_capture.dart';

void main() {
  test('month progress handles leap year and empty ledger', () {
    final stats = ProfileActivity([], DateTime(2024, 2, 10));
    expect(stats.monthDays, 29);
    expect(stats.recordedDays, 0);
    expect(stats.streak, 0);
    expect(stats.bookkeepingDays, 0);
  });

  test('profile activity counts elapsed days from the first recorded day', () {
    final stats = ProfileActivity(
      [
        _transaction('first', DateTime(2024, 2, 1)),
        _transaction('today', DateTime(2024, 2, 10, 8)),
        _transaction('future', DateTime(2024, 2, 11)),
      ],
      DateTime(2024, 2, 10, 12),
    );

    expect(stats.recordedDays, 2);
    expect(stats.bookkeepingDays, 10);
  });

  testWidgets('profile arrows use a shared trailing edge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const ProfileHero(name: '个人账本', streak: '3', onTap: _noop),
              ProfileMenuCard(
                items: const [
                  ProfileMenuItem(Icons.home, '共享账本', '家庭、情侣、企业账本', _noop),
                  ProfileMenuItem(Icons.people, '账户与资产', '4 个账户', _noop),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ProfileHero),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsNothing,
    );
    final arrows = find.byIcon(Icons.chevron_right);
    expect(arrows, findsNWidgets(2));
    expect(
      tester.getTopLeft(arrows.at(0)).dx,
      closeTo(tester.getTopLeft(arrows.at(1)).dx, .01),
    );
  });
  for (final width in [320.0, 393.0, 430.0, 360.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('profile layout $width font $scale', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 874));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await loadReferenceFonts(tester);
        final db = createMemoryDatabase();
        await DatabaseSeeder(db).seedIfNeeded(includeDemoData: true);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sessionProvider.overrideWithValue(const AsyncData(null)),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final router = container.read(appRouterProvider);
        const boundary = ValueKey('profile-capture');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 44, bottom: 34),
                ),
                child: RepaintBoundary(key: boundary, child: child!),
              ),
            ),
          ),
        );
        router.go('/profile');
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final context = tester.element(find.byKey(boundary));
          for (final path in [
            AppAssets.profileHeaderScene,
            AppAssets.monthlyProgressScene,
            AppAssets.userAvatar,
          ]) {
            await precacheImage(AssetImage(path), context);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _capture(tester, boundary, 'profile-$width-$scale');
        await tester.drag(find.byType(ListView).first, const Offset(0, -550));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('帮助与反馈'), findsOneWidget);
        await _capture(tester, boundary, 'profile-lower-$width-$scale');
        if (scale == 1.0) {
          await tester.ensureVisible(find.text('帮助与反馈'));
          await tester.tap(find.text('帮助与反馈'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

void _noop() {}

TransactionRecord _transaction(String id, DateTime occurredAt) {
  return TransactionRecord(
    id: id,
    bookId: 'book-personal',
    type: TransactionType.expense,
    amount: 1,
    accountId: 'account-cash',
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}

Future<void> _capture(WidgetTester tester, Key key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/qa/profile-reference-2026-09-12/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
