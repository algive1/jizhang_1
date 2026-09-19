import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/notifications/application/payment_notification_service.dart';
import 'package:jizhang_app/features/notifications/domain/payment_notification.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test(
    'incoming receipt, refund, or ambiguous actual amounts are rejected',
    () {
      final parser = const PaymentNotificationParser();
      expect(
        parser.parse(
          PaymentNotification(
            id: 'incoming',
            packageName: 'com.tencent.mm',
            title: '微信支付',
            text: '收款到账 ¥28.50，来自便利店',
            postedAt: DateTime(2026, 9, 8, 9),
          ),
        ),
        isNull,
      );
      expect(
        parser.parse(
          PaymentNotification(
            id: 'refund',
            packageName: 'com.eg.android.AlipayGphone',
            title: '支付宝',
            text: '退款成功 ¥28.50',
            postedAt: DateTime(2026, 9, 8, 9),
          ),
        ),
        isNull,
      );
      expect(
        parser.parse(
          PaymentNotification(
            id: 'ambiguous',
            packageName: 'com.tencent.mm',
            title: '微信支付',
            text: '支付金额 ¥12.00，支付金额 ¥18.00',
            postedAt: DateTime(2026, 9, 8, 9),
          ),
        ),
        isNull,
      );
    },
  );

  test('美团付款通知可解析但必须通过目标账户和待确认队列', () {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'meituan-1',
        packageName: 'com.sankuai.meituan',
        title: '美团',
        text: '支付成功 ¥36.00，商户：美团外卖',
        postedAt: DateTime(2026, 9, 8, 9),
      ),
    );
    expect(parsed, isNotNull);
    expect(parsed!.channel, 'meituan');
    expect(parsed.accountId, isNull);
  });

  test('京东、拼多多、抖音付款通知均进入待确认渠道', () {
    final parser = const PaymentNotificationParser();
    final cases = <String, String>{
      'com.jingdong.app.mall': 'jd',
      'com.xunmeng.pinduoduo': 'pinduoduo',
      'com.ss.android.ugc.aweme': 'douyin',
      'com.ss.android.ugc.aweme.mobile': 'douyin',
    };
    for (final entry in cases.entries) {
      final parsed = parser.parse(
        PaymentNotification(
          id: entry.key,
          packageName: entry.key,
          title: '支付通知',
          text: '支付成功 ¥18.80，商户：测试商户',
          postedAt: DateTime(2026, 9, 19, 9),
        ),
      );
      expect(parsed, isNotNull, reason: entry.key);
      expect(parsed!.channel, entry.value);
      expect(parsed.accountId, isNull);
    }
  });

  test('Android notification path queues for confirmation instead of saving silently', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'queued-1',
        packageName: 'com.sankuai.meituan',
        title: '美团',
        text: '支付成功 ¥36.00，商户：美团外卖',
        postedAt: DateTime(2026, 9, 8, 9),
      ),
    ]);
    final pending = _FakePendingBridge();
    final transactions = DriftTransactionRepository(database);
    final result = await PaymentNotificationAutoBookkeepingService(
      bridge: bridge,
      transactions: transactions,
      bookkeeping: QuickBookkeepingService(
        transactions,
        DriftAppSettingsRepository(database),
      ),
      resolveTarget: (_, _) async =>
          (bookId: SeedIds.personalBook, accountId: SeedIds.cashAccount),
      pendingBridge: pending,
    ).processPending();
    expect(result.queued, 1);
    expect(result.created, 0);
    expect(await transactions.getAll(), isEmpty);
    expect(pending.candidates, hasLength(1));
    expect(bridge.acknowledged, ['queued-1']);
  });

  test('parser extracts a supported wallet payment notification', () {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'n-1',
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝',
        text: '支付成功 ¥28.50，商户：瑞幸咖啡，订单号：202609080001',
        postedAt: DateTime(2026, 9, 8, 9),
      ),
    );

    expect(parsed, isNotNull);
    expect(parsed!.amount, 28.50);
    expect(parsed.accountId, SeedIds.alipayAccount);
    expect(parsed.orderId, '202609080001');
  });

  test(
    'parser extracts payment account suffix and resolver receives it',
    () async {
      final parsed = const PaymentNotificationParser().parse(
        PaymentNotification(
          id: 'n-suffix',
          packageName: 'com.tencent.mm',
          title: '微信支付',
          text: '支付成功 ¥18.00，尾号 3316，商户：便利店',
          postedAt: DateTime(2026, 9, 8, 9),
        ),
      );
      expect(parsed?.identifierSuffix, '3316');

      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final bridge = _FakeBridge([
        PaymentNotification(
          id: 'n-suffix-service',
          packageName: 'com.tencent.mm',
          title: '微信支付',
          text: '支付成功 ¥18.00，尾号 3316，商户：便利店',
          postedAt: DateTime(2026, 9, 8, 9),
        ),
      ]);
      final transactions = DriftTransactionRepository(database);
      String? resolvedSuffix;
      final result = await PaymentNotificationAutoBookkeepingService(
        bridge: bridge,
        transactions: transactions,
        bookkeeping: QuickBookkeepingService(
          transactions,
          DriftAppSettingsRepository(database),
        ),
        resolveTarget: (channel, suffix) async {
          resolvedSuffix = suffix;
          return suffix == '3316'
              ? (bookId: SeedIds.personalBook, accountId: SeedIds.wechatAccount)
              : null;
        },
      ).processPending();
      expect(resolvedSuffix, '3316');
      expect(result.created, 1);
    },
  );

  test(
    'notification processing is idempotent and acknowledges only handled items',
    () async {
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final transactions = DriftTransactionRepository(database);
      final bridge = _FakeBridge([
        PaymentNotification(
          id: 'n-2',
          packageName: 'com.tencent.mm',
          title: '微信支付',
          text: '支付成功 ¥12.00，商户：便利店',
          postedAt: DateTime(2026, 9, 8, 9),
        ),
        PaymentNotification(
          id: 'n-unknown',
          packageName: 'com.tencent.mm',
          title: '微信支付',
          text: '支付成功，详情稍后查看',
          postedAt: DateTime(2026, 9, 8, 9),
        ),
      ]);
      final service = PaymentNotificationAutoBookkeepingService(
        bridge: bridge,
        transactions: transactions,
        bookkeeping: QuickBookkeepingService(
          transactions,
          DriftAppSettingsRepository(database),
        ),
      );

      final first = await service.processPending();
      final second = await service.processPending();

      expect(first.created, 1);
      expect(first.unrecognized, 1);
      expect(second.created, 0);
      expect(bridge.acknowledged, ['n-2']);
      expect(
        (await transactions.getAll())
            .where((item) => item.source == TransactionSource.auto)
            .length,
        1,
      );
    },
  );

  test('notification target stays on its configured ledger', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final family = await DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    ).create(name: '通知家庭', type: BookType.family);
    final account = (await DriftAccountRepository(
      database,
      bookId: family.id,
    ).getActive()).single;
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'family-payment',
        packageName: 'com.tencent.mm',
        title: '微信支付',
        text: '支付成功 ¥12.00，商户：家庭超市',
        postedAt: DateTime(2026, 9, 9, 9),
      ),
    ]);
    final transactions = DriftTransactionRepository(database);
    final result = await PaymentNotificationAutoBookkeepingService(
      bridge: bridge,
      transactions: transactions,
      bookkeeping: QuickBookkeepingService(
        transactions,
        DriftAppSettingsRepository(database),
      ),
      resolveTarget: (_, _) async => (bookId: family.id, accountId: account.id),
    ).processPending();
    expect(result.created, 1);
    expect(
      (await transactions.getAll()).where((item) => item.bookId == family.id),
      hasLength(1),
    );
  });
}

class _FakeBridge implements PaymentNotificationBridge {
  _FakeBridge(this._pending);

  final List<PaymentNotification> _pending;
  final acknowledged = <String>[];

  @override
  Future<bool> isAccessGranted() async => true;

  @override
  Future<void> openAccessSettings() async {}

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<bool> isNotificationGranted() async => true;

  @override
  Future<void> requestNotificationPermission() async {}

  @override
  Future<List<PaymentNotification>> getPending() async => _pending;

  @override
  Future<void> acknowledge(Iterable<String> ids) async {
    acknowledged.addAll(ids);
    _pending.removeWhere((item) => ids.contains(item.id));
  }
}

class _FakePendingBridge implements AutoBookkeepingPendingBridge {
  final candidates = <PendingAutoBookkeepingCandidate>[];

  @override
  Future<bool> enqueue(PendingAutoBookkeepingCandidate candidate) async {
    candidates.add(candidate);
    return true;
  }

  @override
  Future<void> complete() async {}

  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() async => null;
}
