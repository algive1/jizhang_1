import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/books/presentation/book_selector.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/core/models/membership.dart';

void main() {
  testWidgets('drawer renders real types and confirms a successful switch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftBookRepository(
      database,
      _ProMembershipRepository(),
    );
    final family = await repository.create(name: '家庭账本', type: BookType.family);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: BookSelectorButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BookSelectorButton));
    await tester.pumpAndSettle();

    expect(find.text('记录自己的精彩生活'), findsOneWidget);
    expect(find.text('和家人一起打理幸福'), findsOneWidget);
    expect(find.text('高效管理商务收支'), findsNothing);
    await tester.tap(find.text(family.name).last);
    await tester.pumpAndSettle();
    expect(find.text('已切换到「家庭账本」'), findsOneWidget);
    await tester.tap(find.byType(BookSelectorButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(family.name).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(activeBookIdProvider), family.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'more books opens every real book and keeps geometry inside shelf',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftBookRepository(
        database,
        _ProMembershipRepository(),
      );
      for (var index = 1; index <= 4; index++) {
        await repository.create(name: '账本$index', type: BookType.personal);
      }
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: BookSelectorButton()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BookSelectorButton));
      await tester.pumpAndSettle();

      final createRect = tester.getRect(
        find.byKey(const ValueKey('book-create-area')),
      );
      final rowRect = tester.getRect(
        find.byKey(const ValueKey('book-shelf-row-book-personal')),
      );
      expect(createRect.left, greaterThan(393 * .24));
      expect(createRect.top, greaterThan(rowRect.bottom));
      await tester.ensureVisible(find.byKey(const ValueKey('book-more')));
      await tester.tap(find.byKey(const ValueKey('book-more')));
      await tester.pumpAndSettle();
      expect(find.text('账本4'), findsOneWidget);
      await tester.tap(find.text('账本4'));
      await tester.pumpAndSettle();
      expect(container.read(activeBookIdProvider), isNot('book-personal'));
      expect(find.text('已切换到「账本4」'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'selecting an archived book fails without changing the active id',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      );
      final archived = await repository.create(
        name: '待归档',
        type: BookType.family,
      );
      await repository.archive(archived.id);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      final before = container.read(activeBookIdProvider);
      await expectLater(
        container.read(activeBookIdProvider.notifier).select(archived.id),
        throwsA(isA<StateError>()),
      );
      expect(container.read(activeBookIdProvider), before);
    },
  );
}

class _ProMembershipRepository implements MembershipRepository {
  MembershipSnapshot get _value => MembershipSnapshot(
    membership: Membership(
      userId: SeedIds.localUser,
      plan: MembershipPlan.pro,
      status: MembershipStatus.active,
      updatedAt: DateTime(2026),
    ),
    entitlements: const [],
    quotas: const [],
  );

  @override
  Future<MembershipSnapshot> getCurrent() async => _value;

  @override
  Stream<MembershipSnapshot> watchCurrent() => Stream.value(_value);
}
