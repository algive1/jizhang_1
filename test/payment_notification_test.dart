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
    'high-confidence income/refund are typed while ambiguous amounts are rejected',
    () {
      final parser = const PaymentNotificationParser();
      final income = parser.parse(
        PaymentNotification(
          id: 'incoming',
          packageName: 'com.tencent.mm',
          title: '微信支付',
          text: '收款到账 ¥28.50，来自便利店',
          postedAt: DateTime(2026, 9, 8, 9),
        ),
      );
      expect(income, isNotNull);
      expect(income!.transactionType, 'INCOME');
      expect(income.merchant, '便利店');

      expect(
        parser.parse(
          PaymentNotification(
            id: 'refund-without-counterparty',
            packageName: 'com.eg.android.AlipayGphone',
            title: '支付宝',
            text: '退款成功 ¥28.50',
            postedAt: DateTime(2026, 9, 8, 9),
          ),
        ),
        isNull,
      );

      final refund = parser.parse(
        PaymentNotification(
          id: 'refund',
          packageName: 'com.eg.android.AlipayGphone',
          title: '支付宝',
          text: '退款成功 ¥28.50，退款方：测试餐厅',
          postedAt: DateTime(2026, 9, 8, 9),
        ),
      );
      expect(refund, isNotNull);
      expect(refund!.transactionType, 'REFUND');
      expect(refund.merchant, '测试餐厅');

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

  test('微信普通聊天里提到支付成功不会被当成支付通知', () {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'wechat-chat',
        packageName: 'com.tencent.mm',
        title: '小王',
        text: '我刚支付成功 ¥20.00，商户：便利店',
        postedAt: DateTime(2026, 9, 19, 9),
      ),
    );
    expect(parsed, isNull);
  });

  test('微信普通聊天里的收款和退款文案不会触发自动记账', () {
    final parser = const PaymentNotificationParser();
    for (final entry in <(String, String)>[
      ('收款成功 ¥88.00，来自张三', 'chat-income'),
      ('退款成功 ¥28.50，退款方：测试餐厅', 'chat-refund'),
    ]) {
      expect(
        parser.parse(
          PaymentNotification(
            id: entry.$2,
            packageName: 'com.tencent.mm',
            title: '小王',
            text: entry.$1,
            postedAt: DateTime(2026, 9, 20, 9),
          ),
        ),
        isNull,
        reason: entry.$2,
      );
    }
  });

  test('完成态通知包含优惠信息仍可识别', () {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'discounted-payment',
        packageName: 'com.sankuai.meituan',
        title: '美团',
        text: '支付成功，原价 ¥40.00，优惠券 ¥4.00，实付金额 ¥36.00，商户：测试餐厅',
        postedAt: DateTime(2026, 9, 19, 9),
      ),
    );
    expect(parsed, isNotNull);
    expect(parsed!.amount, 36.00);
    expect(parsed.merchant, '测试餐厅');
    expect(parsed.transactionType, 'EXPENSE');
    expect(parsed.originalAmount, 40.00);
    expect(parsed.discountAmount, 4.00);
  });

  test('商城待支付和支付提醒不会被解析成已发生流水', () {
    final parser = const PaymentNotificationParser();
    for (final text in <String>[
      '订单待支付 ¥36.00，请尽快完成支付',
      '支付提醒：订单金额 ¥36.00',
      '去支付 ¥36.00 可享优惠',
      '支付失败 ¥36.00，请重新支付',
    ]) {
      expect(
        parser.parse(
          PaymentNotification(
            id: text,
            packageName: 'com.sankuai.meituan',
            title: '美团',
            text: text,
            postedAt: DateTime(2026, 9, 19, 9),
          ),
        ),
        isNull,
        reason: text,
      );
    }
  });

  test('商城通知保留明确的底层支付方式', () {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'meituan-alipay',
        packageName: 'com.sankuai.meituan',
        title: '美团',
        text: '支付成功 ¥36.00，商户：测试餐厅，支付方式：支付宝',
        postedAt: DateTime(2026, 9, 20, 9),
      ),
    );
    expect(parsed, isNotNull);
    expect(parsed!.paymentMethod, '支付宝');
  });

  test('美团完成态付款通知可以进入待确认解析', () {
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

  test('商城确认队列不要求预先配置目标账户', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'meituan-no-target',
        packageName: 'com.sankuai.meituan',
        title: '美团',
        text: '订单支付成功 ¥36.00，商户：测试餐厅',
        postedAt: DateTime(2026, 9, 19, 9),
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
      resolveTarget: (_, _) async => null,
      pendingBridge: pending,
    ).processPending();

    expect(result.queued, 1);
    expect(result.waiting, 0);
    expect(pending.candidates, hasLength(1));
    expect(bridge.acknowledged, ['meituan-no-target']);
  });

  test('缺少商户的通知不会生成未知待确认流水', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'unknown-merchant',
        packageName: 'com.sankuai.meituan',
        title: '美团',
        text: '订单支付成功 ¥36.00',
        postedAt: DateTime(2026, 9, 19, 9),
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
      pendingBridge: pending,
    ).processPending();

    expect(result.unrecognized, 1);
    expect(result.queued, 0);
    expect(pending.candidates, isEmpty);
    expect(bridge.acknowledged, ['unknown-merchant']);
  });

  test('跨来源重复通知会确认清理而不是永久留在队列', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'duplicate-notification',
        packageName: 'com.sankuai.meituan',
        title: '美团',
        text: '支付成功 ¥36.00，商户：测试餐厅',
        postedAt: DateTime(2026, 9, 19, 9),
      ),
    ]);
    final pending = _FakePendingBridge(
      result: AutoBookkeepingEnqueueResult.duplicate,
    );
    final transactions = DriftTransactionRepository(database);
    final result = await PaymentNotificationAutoBookkeepingService(
      bridge: bridge,
      transactions: transactions,
      bookkeeping: QuickBookkeepingService(
        transactions,
        DriftAppSettingsRepository(database),
      ),
      pendingBridge: pending,
    ).processPending();

    expect(result.duplicates, 1);
    expect(result.waiting, 0);
    expect(bridge.acknowledged, ['duplicate-notification']);
  });

  test('income notification keeps transaction type in pending candidate', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'income-pending',
        packageName: 'com.tencent.mm',
        title: '微信支付',
        text: '收款到账 ¥88.00，来自张三',
        postedAt: DateTime(2026, 9, 19, 9),
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
      pendingBridge: pending,
    ).processPending();

    expect(result.queued, 1);
    expect(pending.candidates.single.transactionType, 'INCOME');
    expect(pending.candidates.single.scene, 'PAYMENT_NOTIFICATION_INCOME');
    expect(pending.candidates.single.merchant, '张三');
  });

  test('completed transfer notification keeps transfer scene and target account hint', () async {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'transfer-notification',
        packageName: 'com.tencent.mm',
        title: '微信支付',
        text:
            '转账成功 ¥66.00，收款人：张三，转入账户：招商银行储蓄卡 尾号7777，转出方式：微信支付',
        postedAt: DateTime(2026, 9, 20, 10),
      ),
    );
    expect(parsed, isNotNull);
    expect(parsed!.transactionType, 'TRANSFER');
    expect(parsed.amount, 66);
    expect(parsed.merchant, '张三');
    expect(parsed.targetIdentifierSuffix, '7777');
    expect(parsed.targetAccountHint, '招商银行储蓄卡 尾号7777');

    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'transfer-queued',
        packageName: 'com.tencent.mm',
        title: '微信支付',
        text:
            '转账成功 ¥66.00，收款人：张三，转入账户：招商银行储蓄卡 尾号7777，转出方式：微信支付',
        postedAt: DateTime(2026, 9, 20, 10),
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
      pendingBridge: pending,
    ).processPending();

    expect(result.queued, 1);
    expect(result.created, 0);
    expect(pending.candidates, hasLength(1));
    expect(pending.candidates.single.transactionType, 'TRANSFER');
    expect(pending.candidates.single.scene, 'PAYMENT_NOTIFICATION_TRANSFER');
    expect(pending.candidates.single.targetIdentifierSuffix, '7777');
    expect(await transactions.getAll(), isEmpty);
  });

  test('completed repayment notification queues confirmation with debt target', () async {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'repayment-notification',
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝',
        text:
            '信用卡还款成功 ¥120.00，还款信用卡：招商银行信用卡 尾号4321，扣款账户：支付宝余额',
        postedAt: DateTime(2026, 9, 20, 11),
      ),
    );
    expect(parsed, isNotNull);
    expect(parsed!.transactionType, 'REPAYMENT');
    expect(parsed.amount, 120);
    expect(parsed.paymentMethod, '支付宝余额');
    expect(parsed.targetIdentifierSuffix, '4321');
    expect(parsed.targetAccountHint, '招商银行信用卡 尾号4321');

    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'repayment-queued',
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝',
        text:
            '信用卡还款成功 ¥120.00，还款信用卡：招商银行信用卡 尾号4321，扣款账户：支付宝余额',
        postedAt: DateTime(2026, 9, 20, 11),
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
      pendingBridge: pending,
    ).processPending();

    expect(result.queued, 1);
    expect(result.created, 0);
    expect(pending.candidates, hasLength(1));
    expect(pending.candidates.single.transactionType, 'REPAYMENT');
    expect(
      pending.candidates.single.scene,
      'PAYMENT_NOTIFICATION_REPAYMENT',
    );
    expect(pending.candidates.single.targetIdentifierSuffix, '4321');
    expect(await transactions.getAll(), isEmpty);
  });

  test('repayment never direct-saves when confirmation bridge is unavailable', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'repayment-no-pending',
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝',
        text:
            '信用卡还款成功 ¥120.00，还款信用卡：招商银行信用卡 尾号4321，扣款账户：支付宝余额',
        postedAt: DateTime(2026, 9, 20, 11),
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
    ).processPending();

    expect(result.waiting, 1);
    expect(result.created, 0);
    expect(await transactions.getAll(), isEmpty);
    expect(bridge.acknowledged, isEmpty);
  });

  test('explicit reimbursement notification queues confirmation without silent save', () async {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'reimbursement-notification',
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝',
        text:
            '报销到账 ¥128.00，报销方：示例科技有限公司，到账账户：支付宝余额',
        postedAt: DateTime(2026, 9, 20, 12),
      ),
    );
    expect(parsed, isNotNull);
    expect(parsed!.transactionType, 'REIMBURSEMENT');
    expect(parsed.amount, 128);
    expect(parsed.merchant, '示例科技有限公司');

    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'reimbursement-queued',
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝',
        text:
            '报销到账 ¥128.00，报销方：示例科技有限公司，到账账户：支付宝余额',
        postedAt: DateTime(2026, 9, 20, 12),
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
      pendingBridge: pending,
    ).processPending();

    expect(result.queued, 1);
    expect(result.created, 0);
    expect(pending.candidates, hasLength(1));
    expect(pending.candidates.single.transactionType, 'REIMBURSEMENT');
    expect(
      pending.candidates.single.scene,
      'PAYMENT_NOTIFICATION_REIMBURSEMENT',
    );
    expect(await transactions.getAll(), isEmpty);
  });

  test('reimbursement never direct-saves when confirmation bridge is unavailable', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final bridge = _FakeBridge([
      PaymentNotification(
        id: 'reimbursement-no-pending',
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝',
        text:
            '报销到账 ¥128.00，报销方：示例科技有限公司，到账账户：支付宝余额',
        postedAt: DateTime(2026, 9, 20, 12),
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
    ).processPending();

    expect(result.waiting, 1);
    expect(result.created, 0);
    expect(await transactions.getAll(), isEmpty);
    expect(bridge.acknowledged, isEmpty);
  });

  test('generic collection remains income rather than reimbursement', () {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'generic-income-after-reimbursement',
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝',
        text: '收款到账 ¥128.00，付款方：示例科技有限公司',
        postedAt: DateTime(2026, 9, 20, 12),
      ),
    );
    expect(parsed?.transactionType, 'INCOME');
  });

  test('wechat chat transfer text is not accepted without payment context', () {
    final parsed = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'transfer-chat',
        packageName: 'com.tencent.mm',
        title: '小王',
        text: '转账成功 ¥66.00，收款人：张三',
        postedAt: DateTime(2026, 9, 20, 10),
      ),
    );
    expect(parsed, isNull);
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
    expect(parsed.transactionType, 'EXPENSE');
  });

  test('parser aligns native order id and bank suffix labels', () {
    final paymentOrder = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'n-payment-order',
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝',
        text: '支付成功 ¥28.50，商户：瑞幸咖啡，支付单号：PAY202609200001',
        postedAt: DateTime(2026, 9, 20, 9),
      ),
    );
    expect(paymentOrder?.orderId, 'PAY202609200001');

    final transactionOrder = const PaymentNotificationParser().parse(
      PaymentNotification(
        id: 'n-transaction-order',
        packageName: 'com.unionpay',
        title: '云闪付',
        text: '支付成功 ¥66.00，商户：测试商户，交易号：TX202609200001，储蓄卡尾号 5566',
        postedAt: DateTime(2026, 9, 20, 10),
      ),
    );
    expect(transactionOrder?.orderId, 'TX202609200001');
    expect(transactionOrder?.identifierSuffix, '5566');
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
      expect(second.unrecognized, 0);
      expect(bridge.acknowledged, ['n-2', 'n-unknown']);
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
  Future<bool> isConnected() async => true;

  @override
  Future<void> openAccessSettings() async {}

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<bool> isNotificationGranted() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<List<PaymentNotification>> getPending() async => _pending;

  @override
  Future<void> acknowledge(Iterable<String> ids) async {
    acknowledged.addAll(ids);
    _pending.removeWhere((item) => ids.contains(item.id));
  }
}

class _FakePendingBridge implements AutoBookkeepingPendingBridge {
  _FakePendingBridge({
    this.result = AutoBookkeepingEnqueueResult.accepted,
  });

  final AutoBookkeepingEnqueueResult result;
  final candidates = <PendingAutoBookkeepingCandidate>[];

  @override
  Future<AutoBookkeepingEnqueueResult> enqueue(
    PendingAutoBookkeepingCandidate candidate,
  ) async {
    candidates.add(candidate);
    return result;
  }

  @override
  Future<String?> promoteScreenshot(String path) async => path;

  @override
  Future<void> complete({bool keepScreenshot = false}) async {}

  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() async => null;
}
