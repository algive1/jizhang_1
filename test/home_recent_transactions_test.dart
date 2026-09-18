import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/formatters/transaction_date_formatter.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/home/presentation/home_page.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test('recent query is limited, ordered, and scoped to one book', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final now = DateTime(2026, 9, 10, 12);
    final personal = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    await personal.createAll([
      for (var index = 0; index < 12; index++)
        TransactionRecord(
          id: 'recent-$index',
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: index + 1,
          accountId: scopedSeedId(SeedIds.personalBook, SeedIds.cashAccount),
          occurredAt: now.subtract(Duration(days: index)),
          createdAt: now.subtract(Duration(days: index)),
          updatedAt: now.subtract(Duration(days: index)),
        ),
    ]);

    final family = await DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    ).create(name: '家庭账本', type: BookType.family);
    await DriftTransactionRepository(database, bookId: family.id).create(
      TransactionRecord(
        id: 'family-recent',
        bookId: family.id,
        type: TransactionType.expense,
        amount: 99,
        accountId: scopedSeedId(family.id, SeedIds.cashAccount),
        occurredAt: now.subtract(const Duration(hours: 1)),
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
    );

    expect((await personal.getRecent()).map((item) => item.id), [
      'recent-0',
      'recent-1',
      'recent-2',
      'recent-3',
      'recent-4',
      'recent-5',
      'recent-6',
      'recent-7',
      'recent-8',
      'recent-9',
    ]);
    expect((await personal.watchRecent().first).map((item) => item.id), [
      'recent-0',
      'recent-1',
      'recent-2',
      'recent-3',
      'recent-4',
      'recent-5',
      'recent-6',
      'recent-7',
      'recent-8',
      'recent-9',
    ]);
    expect(await personal.getAll(), hasLength(12));
    expect(
      (await DriftTransactionRepository(
        database,
        bookId: family.id,
      ).getRecent()).map((item) => item.id),
      ['family-recent'],
    );
    await expectLater(personal.getRecent(limit: 0), throwsArgumentError);
  });

  test(
    'recent query excludes future transactions before applying its limit',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final now = DateTime.now();
      final repository = DriftTransactionRepository(
        database,
        bookId: SeedIds.personalBook,
      );
      TransactionRecord transaction(String id, DateTime occurredAt) {
        return TransactionRecord(
          id: id,
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 12,
          accountId: scopedSeedId(SeedIds.personalBook, SeedIds.cashAccount),
          occurredAt: occurredAt,
          createdAt: occurredAt,
          updatedAt: occurredAt,
        );
      }

      await repository.createAll([
        transaction('未来计划', now.add(const Duration(days: 1))),
        for (var index = 0; index < 10; index++)
          transaction('已发生-$index', now.subtract(Duration(days: index + 1))),
      ]);

      final recent = await repository.getRecent();
      expect(recent, hasLength(10));
      expect(recent.map((item) => item.id), isNot(contains('未来计划')));
      expect(await repository.getAll(), hasLength(11));
    },
  );

  test(
    'active recent subscription includes transactions saved after opening home',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftTransactionRepository(
        database,
        bookId: SeedIds.personalBook,
      );
      final events = StreamIterator(repository.watchRecent());
      addTearDown(events.cancel);
      expect(await events.moveNext(), isTrue);
      expect(events.current, isEmpty);
      // Drift stores whole seconds; cross a second boundary after subscription.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final now = DateTime.now();
      await repository.create(
        TransactionRecord(
          id: 'saved-after-home-opened',
          bookId: SeedIds.personalBook,
          type: TransactionType.expense,
          amount: 200,
          accountId: scopedSeedId(SeedIds.personalBook, SeedIds.cashAccount),
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(
        await events.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(
        events.current.map((item) => item.id),
        contains('saved-after-home-opened'),
      );
    },
  );

  testWidgets('home recent transactions are grouped by local calendar date', (
    tester,
  ) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final now = DateTime.now();
    final repository = DriftTransactionRepository(
      database,
      bookId: SeedIds.personalBook,
    );
    TransactionRecord transaction(String id, DateTime occurredAt) {
      return TransactionRecord(
        id: id,
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 12,
        accountId: scopedSeedId(SeedIds.personalBook, SeedIds.cashAccount),
        merchant: id,
        occurredAt: occurredAt,
        createdAt: occurredAt,
        updatedAt: occurredAt,
      );
    }

    await repository.createAll([
      transaction('今天交易', now),
      transaction('昨天交易', DateTime(now.year, now.month, now.day - 1, 12)),
    ]);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('最近交易'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('最近交易'), findsOneWidget);
    expect(
      find.text(TransactionDateFormatter.groupLabel(now, now: now)),
      findsOneWidget,
    );
    expect(
      find.text(
        TransactionDateFormatter.groupLabel(
          now.subtract(const Duration(days: 1)),
          now: now,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('今天交易'), findsOneWidget);
    expect(find.text('昨天交易'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
