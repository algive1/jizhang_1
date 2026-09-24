import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/widgets/transaction_tile.dart';
import 'package:jizhang_app/features/calendar/presentation/consumption_calendar_page.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  testWidgets(
    'calendar uses net expense amounts, excludes transfers, and shows daily average',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repository = DriftTransactionRepository(database);
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
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final secondDay = DateTime(now.year, now.month, now.day == 1 ? 1 : 2);

      await repository.create(
        _record(
          id: 'calendar-refunded',
          type: TransactionType.expense,
          amount: 100,
          occurredAt: firstDay,
          refundAmount: 40,
          refundStatus: RefundStatus.partial,
        ),
      );
      await repository.create(
        _record(
          id: 'calendar-expense',
          type: TransactionType.expense,
          amount: 20,
          occurredAt: secondDay,
        ),
      );
      await repository.create(
        _record(
          id: 'calendar-transfer',
          type: TransactionType.transfer,
          amount: 999,
          occurredAt: secondDay,
          destinationAccountId: SeedIds.cashAccount,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ConsumptionCalendarPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('本月概览'), findsOneWidget);
      expect(find.text('月支出'), findsOneWidget);
      expect(find.text('月收入'), findsOneWidget);
      expect(find.text('有消费'), findsOneWidget);
      expect(find.text('¥80.00'), findsOneWidget);
      expect(find.text(now.day == 1 ? '1天' : '2天'), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('monthly overview stays visible while calendar body scrolls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    await DriftTransactionRepository(database).create(
      _record(
        id: 'calendar-bottom-record',
        type: TransactionType.expense,
        amount: 12,
        occurredAt: DateTime.now(),
        note: '底部消费记录',
      ),
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.8),
            ),
            child: const ConsumptionCalendarPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final body = find.descendant(
      of: find.byType(ConsumptionCalendarPage),
      matching: find.byType(ListView),
    );
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: body, matching: find.byType(Scrollable)).first,
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('本月概览'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Scaffold && widget.bottomNavigationBar != null,
        ),
      ),
      findsOneWidget,
    );
    final overviewRect = tester.getRect(find.text('本月概览'));
    final bodyRect = tester.getRect(body);
    expect(bodyRect.bottom, lessThanOrEqualTo(overviewRect.top));
    expect(overviewRect.top, greaterThanOrEqualTo(0));
    expect(overviewRect.bottom, lessThanOrEqualTo(640));
    expect(find.text('本月概览').hitTestable(), findsOneWidget);
    expect(find.text('底部消费记录').hitTestable(), findsOneWidget);
    expect(find.text('记一笔').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar transaction long press opens the action sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(database);
    final now = DateTime.now();
    await repository.create(
      _record(
        id: 'calendar-long-press',
        type: TransactionType.expense,
        amount: 20,
        occurredAt: now,
        note: '长按测试流水',
      ),
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ConsumptionCalendarPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('长按测试流水'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.longPress(find.byType(TransactionTile).first);
    await tester.pumpAndSettle();

    expect(find.text('编辑流水'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar includes imported expenses in the current month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(database);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      await tester.pump();
    });
    final now = DateTime.now();

    await repository.create(
      _record(
        id: 'calendar-imported-expense',
        type: TransactionType.expense,
        amount: 27.30,
        occurredAt: DateTime(now.year, now.month, now.day),
        source: TransactionSource.import,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ConsumptionCalendarPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¥27.30'), findsWidgets);
    expect(find.text('全部账本'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar defaults to all ledgers and can filter one ledger', (
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
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      await tester.pump();
    });
    final now = DateTime.now();
    final family = await container
        .read(bookRepositoryProvider)
        .create(name: '测试家庭账本', type: BookType.family);
    final familyDay = now.day == 1 ? 1 : 2;
    final repository = DriftTransactionRepository(database);
    await repository.create(
      _record(
        id: 'calendar-personal-expense',
        type: TransactionType.expense,
        amount: 80,
        occurredAt: DateTime(now.year, now.month, 1, 12),
      ),
    );
    await repository.create(
      _record(
        id: 'calendar-family-expense',
        bookId: family.id,
        accountId: scopedSeedId(family.id, SeedIds.cashAccount),
        type: TransactionType.expense,
        amount: 35,
        occurredAt: DateTime(now.year, now.month, familyDay),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ConsumptionCalendarPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('全部账本'), findsOneWidget);
    expect(find.text('¥115.00'), findsOneWidget);
    expect(find.text(now.day == 1 ? '1天' : '2天'), findsOneWidget);

    await tester.tap(find.text('全部账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试家庭账本'));
    await tester.pumpAndSettle();
    expect(find.text('测试家庭账本'), findsOneWidget);
    expect(find.text('¥35.00'), findsNWidgets(2));
  });

  testWidgets('liquid glass keeps the ledger filter sheet readable', (
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
          theme: AppTheme.light(BuiltInThemes.liquidGlass),
          home: const Scaffold(body: ConsumptionCalendarPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('全部账本'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, isNot(Colors.transparent));
    expect(sheet.backgroundColor?.a, greaterThan(.9));
    expect(find.text('统计范围'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('个人账本'),
      ),
      findsAtLeastNWidgets(1),
      reason: 'The sheet should expose a readable personal-ledger option.',
    );
    expect(tester.takeException(), isNull);
  });
}

TransactionRecord _record({
  required String id,
  required TransactionType type,
  String bookId = SeedIds.personalBook,
  String accountId = SeedIds.bankAccount,
  required double amount,
  required DateTime occurredAt,
  String? destinationAccountId,
  RefundStatus refundStatus = RefundStatus.none,
  double? refundAmount,
  TransactionSource source = TransactionSource.manual,
  String? note,
}) {
  return TransactionRecord(
    id: id,
    bookId: bookId,
    type: type,
    amount: amount,
    accountId: accountId,
    destinationAccountId: destinationAccountId,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
    refundStatus: refundStatus,
    refundAmount: refundAmount,
    source: source,
    note: note,
  );
}
