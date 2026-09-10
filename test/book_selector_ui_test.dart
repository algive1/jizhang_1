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

  testWidgets(
    'preview follows creation order and keeps the active book visible',
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
      final family = await repository.create(
        name: '家庭账本',
        type: BookType.family,
      );
      final personal = await repository.create(
        name: '旅行账本',
        type: BookType.personal,
      );
      final enterprise = await repository.create(
        name: '企业账本',
        type: BookType.enterprise,
      );
      final fourth = await repository.create(
        name: '第四本账本',
        type: BookType.personal,
      );
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
      await container.read(activeBookIdProvider.notifier).select(fourth.id);
      await tester.tap(find.byType(BookSelectorButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('book-shelf-row-${family.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('book-shelf-row-${personal.id}')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('book-shelf-row-${fourth.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('book-shelf-row-${enterprise.id}')),
        findsNothing,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('book-more')));
      expect(find.textContaining('查看全部账本（5）'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all books view supports search and explicit management actions',
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
      final family = await repository.create(
        name: '家庭账本',
        type: BookType.family,
      );
      final enterprise = await repository.create(
        name: '企业账本',
        type: BookType.enterprise,
      );
      await repository.create(name: '旅行账本', type: BookType.personal);
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
      await tester.ensureVisible(find.byKey(const ValueKey('book-more')));
      await tester.tap(find.byKey(const ValueKey('book-more')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('all-books-search')), findsOneWidget);
      expect(find.byKey(const ValueKey('all-books-create')), findsOneWidget);
      expect(find.byKey(ValueKey('book-all-row-${family.id}')), findsOneWidget);
      expect(find.textContaining('家庭账本 · 仅本机'), findsOneWidget);
      expect(
        find.byKey(ValueKey('book-manage-${enterprise.id}')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('all-books-search')),
        '企业',
      );
      await tester.pump();
      expect(
        find.byKey(ValueKey('book-all-row-${enterprise.id}')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('book-all-row-${family.id}')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('all-books-search')),
        '',
      );
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('book-manage-${family.id}')));
      await tester.pumpAndSettle();
      expect(find.text('重命名账本'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create form keeps name, type and preview in one sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
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
    await tester.tap(find.byKey(const ValueKey('book-create-area')));
    await tester.pumpAndSettle();

    expect(find.text('选择账本用途'), findsNothing);
    expect(find.byKey(const ValueKey('book-create-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('book-create-preview')), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('book-type-personal')))
          .selected,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey('book-create-name')),
      '旅行账本',
    );
    await tester.tap(find.byKey(const ValueKey('book-type-family')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('book-create-preview')),
        matching: find.text('家庭账本'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('book-create-preview')),
        matching: find.text('旅行账本'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('book-create-cancel')));
    await tester.pumpAndSettle();

    expect(
      (await DriftBookRepository(
        database,
        LocalOnlyMembershipRepository(),
      ).getForUser(SeedIds.localUser)),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting the create form creates and switches once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
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
    await tester.ensureVisible(find.byKey(const ValueKey('book-create-area')));
    await tester.tap(find.byKey(const ValueKey('book-create-area')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('book-create-name')),
      '旅行账本',
    );
    await tester.tap(find.byKey(const ValueKey('book-create-submit')));
    await tester.pumpAndSettle();

    final books = await DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    ).getForUser(SeedIds.localUser);
    expect(books, hasLength(2));
    final created = books.singleWhere((book) => book.name == '旅行账本');
    expect(container.read(activeBookIdProvider), created.id);
    expect(find.text('已创建并切换到「旅行账本」'), findsOneWidget);
    expect(find.text('选择账本'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create form remains reachable at narrow width and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const Scaffold(body: BookSelectorButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BookSelectorButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('book-create-area')));
    await tester.tap(find.byKey(const ValueKey('book-create-area')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('book-create-submit')),
    );

    expect(find.byKey(const ValueKey('book-create-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('book-create-preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
