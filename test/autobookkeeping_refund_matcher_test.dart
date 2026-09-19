import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_refund_matcher.dart';
import 'package:jizhang_app/features/transactions/data/refund_service.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test('refund matcher links only unique order id expense', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final now = DateTime(2026, 9, 20, 12);
    final original = TransactionRecord(
      id: 'auto-original-order',
      bookId: SeedIds.personalBook,
      userId: SeedIds.localUser,
      type: TransactionType.expense,
      amount: 88,
      accountId: SeedIds.alipayAccount,
      merchant: '测试餐厅',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      source: TransactionSource.auto,
      metadataJson: jsonEncode({
        'orderId': 'ORDER_123456',
        'autobookkeeping': {
          'orderId': 'ORDER_123456',
          'sourceApp': 'ALIPAY',
        },
      }),
    );
    await transactions.create(original);

    final candidate = PendingAutoBookkeepingCandidate(
      fingerprint: 'refund-order',
      amountInCents: 2800,
      merchant: '测试餐厅',
      paymentMethod: '支付宝',
      timestamp: now.add(const Duration(hours: 1)),
      sourceApp: 'ALIPAY',
      scene: 'PAYMENT_NOTIFICATION_REFUND',
      transactionType: 'REFUND',
      orderId: 'ORDER_123456',
    );
    final matcher = AutoBookkeepingRefundMatcher(transactions);
    final matched = await matcher.findOriginal(
      candidate: candidate,
      bookId: SeedIds.personalBook,
    );
    expect(matched?.id, original.id);
  });

  test('refund matcher refuses ambiguous or over-refunded order matches', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final now = DateTime(2026, 9, 20, 12);

    for (final id in ['duplicate-order-a', 'duplicate-order-b']) {
      await transactions.create(
        TransactionRecord(
          id: id,
          bookId: SeedIds.personalBook,
          userId: SeedIds.localUser,
          type: TransactionType.expense,
          amount: 88,
          accountId: SeedIds.alipayAccount,
          merchant: '测试餐厅',
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
          source: TransactionSource.auto,
          metadataJson: jsonEncode({'orderId': 'AMBIGUOUS_ORDER'}),
        ),
      );
    }

    final matcher = AutoBookkeepingRefundMatcher(transactions);
    final ambiguous = await matcher.findOriginal(
      candidate: PendingAutoBookkeepingCandidate(
        fingerprint: 'refund-ambiguous',
        amountInCents: 2800,
        merchant: '测试餐厅',
        paymentMethod: '支付宝',
        timestamp: now,
        sourceApp: 'ALIPAY',
        scene: 'PAYMENT_NOTIFICATION_REFUND',
        transactionType: 'REFUND',
        orderId: 'AMBIGUOUS_ORDER',
      ),
      bookId: SeedIds.personalBook,
    );
    expect(ambiguous, isNull);

    await transactions.create(
      TransactionRecord(
        id: 'small-original',
        bookId: SeedIds.personalBook,
        userId: SeedIds.localUser,
        type: TransactionType.expense,
        amount: 10,
        accountId: SeedIds.alipayAccount,
        merchant: '小额订单',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        source: TransactionSource.auto,
        metadataJson: jsonEncode({'orderId': 'SMALL_ORDER'}),
      ),
    );
    final overRefund = await matcher.findOriginal(
      candidate: PendingAutoBookkeepingCandidate(
        fingerprint: 'refund-too-large',
        amountInCents: 1200,
        merchant: '小额订单',
        paymentMethod: '支付宝',
        timestamp: now,
        sourceApp: 'ALIPAY',
        scene: 'PAYMENT_NOTIFICATION_REFUND',
        transactionType: 'REFUND',
        orderId: 'SMALL_ORDER',
      ),
      bookId: SeedIds.personalBook,
    );
    expect(overRefund, isNull);
  });

  test('matched automatic refund updates original net expense atomically', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final now = DateTime(2026, 9, 20, 12);
    final original = TransactionRecord(
      id: 'auto-refund-source',
      bookId: SeedIds.personalBook,
      userId: SeedIds.localUser,
      type: TransactionType.expense,
      amount: 50,
      accountId: SeedIds.alipayAccount,
      merchant: '测试餐厅',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      source: TransactionSource.auto,
      metadataJson: jsonEncode({'orderId': 'REFUND_LINK_ORDER'}),
    );
    await transactions.create(original);

    final incomeCategories = (await database.categoryDao.getActive()).where(
      (item) =>
          item.bookId == SeedIds.personalBook && item.type == 'income',
    );
    final categoryEntity = incomeCategories.firstWhere(
      (item) => item.name.contains('退款'),
      orElse: () => incomeCategories.first,
    );
    final category = Category(
      id: categoryEntity.id,
      bookId: categoryEntity.bookId,
      name: categoryEntity.name,
      icon: categoryEntity.icon,
      type: CategoryType.income,
      sortOrder: categoryEntity.sortOrder,
      isDefault: categoryEntity.isDefault,
      isArchived: categoryEntity.isArchived,
      parentId: categoryEntity.parentId,
    );

    final service = RefundService(database, bookId: SeedIds.personalBook);
    final refund = await service.register(
      original: original,
      amount: 20,
      category: category,
      occurredAt: now.add(const Duration(hours: 1)),
      transactionId: 'auto-refund-linked',
      metadataJson: jsonEncode({
        'orderId': 'REFUND_LINK_ORDER',
        'autobookkeeping': {'fingerprint': 'refund-linked'},
      }),
      source: TransactionSource.auto,
    );
    expect(refund.source, TransactionSource.auto);
    expect(refund.relatedTransactionId, original.id);

    final updated = await transactions.getById(original.id);
    expect(updated?.refundStatus, RefundStatus.partial);
    expect(updated?.refundAmount, 20);
    expect(updated?.netExpenseAmount, 30);

    final retry = await service.register(
      original: updated!,
      amount: 20,
      category: category,
      occurredAt: now.add(const Duration(hours: 1)),
      transactionId: 'auto-refund-linked',
      source: TransactionSource.auto,
    );
    expect(retry.id, refund.id);
    final afterRetry = await transactions.getById(original.id);
    expect(afterRetry?.refundAmount, 20);
  });
}
