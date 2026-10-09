import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/platform/bookkeeping_refresh.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('独立连接保存后统一刷新流水、最近流水、账户流水、汇总和余额', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bookkeeping-refresh-',
    );
    final file = File('${directory.path}/ledger.sqlite');
    final reader = AppDatabase.forTesting(NativeDatabase(file));
    await DatabaseSeeder(reader).seedIfNeeded();
    final writer = AppDatabase.forTesting(NativeDatabase(file));
    final subscriptions = <StreamSubscription<dynamic>>[];
    addTearDown(() async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await writer.close();
      await reader.close();
      await directory.delete(recursive: true);
    });
    final account = (await reader.accountDao.getActive()).first;
    final repository = DriftTransactionRepository(reader);
    final now = DateTime.now();
    List<TransactionRecord>? all, recent, accountRecords;
    int? balance, expense;
    subscriptions.add(repository.watchAll().listen((value) => all = value));
    subscriptions.add(
      repository.watchRecent().listen((value) => recent = value),
    );
    subscriptions.add(
      repository
          .watchForAccount(accountId: account.id)
          .listen((value) => accountRecords = value),
    );
    subscriptions.add(
      reader.accountDao.watchAll().listen(
        (rows) => balance = rows
            .firstWhere((row) => row.id == account.id)
            .balanceInCents,
      ),
    );
    subscriptions.add(
      reader.transactionDao
          .watchLedgerMonthSummary(
            bookId: SeedIds.personalBook,
            start: DateTime(now.year, now.month),
            endExclusive: DateTime(now.year, now.month + 1),
            now: now.add(const Duration(seconds: 1)),
          )
          .listen((value) => expense = value.expenseCents),
    );
    await _until(
      () =>
          all != null &&
          recent != null &&
          accountRecords != null &&
          balance != null &&
          expense != null,
    );
    final previousCount = all!.length;
    final previousBalance = balance!;
    final previousExpense = expense!;
    await DriftTransactionRepository(writer).create(
      TransactionRecord(
        id: 'external-payment',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 12.34,
        accountId: account.id,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        source: TransactionSource.auto,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(all!.length, previousCount, reason: '另一连接写入不会主动通知当前 Drift 订阅');
    refreshExternalBookkeepingData(reader);
    await _until(
      () =>
          all!.any((row) => row.id == 'external-payment') &&
          recent!.any((row) => row.id == 'external-payment') &&
          accountRecords!.any((row) => row.id == 'external-payment') &&
          balance == previousBalance - 1234 &&
          expense == previousExpense + 1234,
    );
    expect(all!.length, previousCount + 1);
  });

  test('保存事件即时刷新，返回前台补检漏掉的事件，未变化不重复刷新', () async {
    const channel = MethodChannel('jizhang/bookkeeping_changes');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var revision = 7;
    var refreshes = 0;
    messenger.setMockMethodCallHandler(channel, (_) async => revision);
    final bridge = BookkeepingRefreshBridge(() async {
      refreshes++;
    })..start();
    addTearDown(() {
      bridge.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    });
    await bridge.check();
    await bridge.check();
    expect(refreshes, 1);
    revision = 8;
    await bridge.check();
    expect(refreshes, 2);
    final delivered = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('changed', 9),
      ),
      (_) => delivered.complete(),
    );
    await delivered.future;
    expect(refreshes, 3);
    revision = 9;
    await bridge.check();
    expect(refreshes, 3);
  });
}

Future<void> _until(bool Function() complete) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!complete()) {
    if (DateTime.now().isAfter(deadline)) fail('数据订阅没有及时刷新');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
