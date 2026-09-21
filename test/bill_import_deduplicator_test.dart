import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/bill_import/application/bill_import_deduplicator.dart';
import 'package:jizhang_app/features/bill_import/application/bill_import_service.dart';

void main() {
  ImportedBillRow row({
    BillImportProvider provider = BillImportProvider.wechat,
    String? externalId,
    DateTime? occurredAt,
    double amount = 18.8,
    String merchant = '测试商户',
    String note = '',
    String? sourceAccount,
    String? sourceBook,
  }) {
    return ImportedBillRow(
      provider: provider,
      occurredAt: occurredAt ?? DateTime(2026, 9, 20, 12, 30),
      type: TransactionType.expense,
      amount: amount,
      merchant: merchant,
      note: note,
      externalId: externalId,
      paymentMethod: sourceAccount,
      sourceAccount: sourceAccount,
      sourceBook: sourceBook,
      raw: const {},
    );
  }

  TransactionRecord persisted(
    ImportedBillRow source, {
    BillImportProvider? storedProvider,
    String? storedExternalId,
    String? metadataOverride,
  }) {
    final now = DateTime(2026, 9, 21);
    return TransactionRecord(
      id: 'persisted-${storedExternalId ?? source.externalId ?? source.naturalFingerprint.hashCode}',
      bookId: 'book-personal',
      type: source.type,
      amount: source.amount,
      accountId: 'account-1',
      occurredAt: source.occurredAt,
      createdAt: now,
      updatedAt: now,
      merchant: source.merchant,
      note: source.note,
      source: TransactionSource.import,
      metadataJson:
          metadataOverride ??
          jsonEncode({
            'importProvider': (storedProvider ?? source.provider).name,
            'importFingerprint': source.importFingerprint,
            'importNaturalFingerprint': source.naturalFingerprint,
            if ((storedExternalId ?? source.externalId) != null)
              'externalId': storedExternalId ?? source.externalId,
            if (source.sourceAccount != null)
              'sourceAccount': source.sourceAccount,
            if (source.sourceBook != null) 'sourceBook': source.sourceBook,
          }),
    );
  }

  test('incremental re-import skips existing ids and accepts only new rows', () {
    final old = row(externalId: 'wx-001');
    final index = BillImportDeduplicator.fromTransactions([persisted(old)]);

    expect(index.isDuplicate(old), isTrue);

    final added = row(
      externalId: 'wx-002',
      occurredAt: DateTime(2026, 9, 21, 8),
      amount: 32,
      merchant: '早餐店',
    );
    expect(index.isDuplicate(added), isFalse);
    index.remember(added);

    expect(
      index.isDuplicate(added),
      isTrue,
      reason: '同一批次或再次导入时，新写入的交易也应立即参与去重',
    );
  });

  test('same external id from different official providers is not collapsed', () {
    final wechat = row(
      provider: BillImportProvider.wechat,
      externalId: 'same-001',
    );
    final alipay = row(
      provider: BillImportProvider.alipay,
      externalId: 'same-001',
    );
    final index = BillImportDeduplicator.fromTransactions([persisted(wechat)]);

    expect(index.isDuplicate(alipay), isFalse);
  });

  test('distinct provider ids win over identical weak fingerprints', () {
    final first = row(externalId: 'wx-a');
    final second = row(externalId: 'wx-b');
    expect(first.naturalFingerprint, second.naturalFingerprint);

    final index = BillImportDeduplicator.fromTransactions([persisted(first)]);
    expect(
      index.isDuplicate(second),
      isFalse,
      reason:
          '两笔真实交易即使时间、金额和商户完全相同，只要官方交易号不同就不能误判重复',
    );
  });

  test('legacy generic provider can migrate to official provider safely', () {
    final current = row(
      provider: BillImportProvider.wechat,
      externalId: 'legacy-wx-1',
      merchant: '周姐老面包子',
      amount: 9,
    );
    final legacy = persisted(
      current,
      storedProvider: BillImportProvider.generic,
      storedExternalId: 'legacy-wx-1',
    );
    final index = BillImportDeduplicator.fromTransactions([legacy]);

    expect(index.isDuplicate(current), isTrue);

    final unrelated = row(
      provider: BillImportProvider.wechat,
      externalId: 'legacy-wx-1',
      merchant: '另一家店',
      amount: 99,
    );
    final unrelatedIndex = BillImportDeduplicator.fromTransactions([legacy]);
    expect(
      unrelatedIndex.isDuplicate(unrelated),
      isFalse,
      reason: '旧 generic 兼容不能仅凭裸订单号跨来源误删流水',
    );
  });

  test('rows without external ids retain natural-fingerprint fallback', () {
    final old = row(
      provider: BillImportProvider.generic,
      externalId: null,
      sourceAccount: '现金',
      sourceBook: '个人账本',
    );
    final current = row(
      provider: BillImportProvider.wechat,
      externalId: null,
      sourceAccount: '零钱',
      sourceBook: null,
    );
    expect(old.naturalFingerprint, current.naturalFingerprint);

    final index = BillImportDeduplicator.fromTransactions([persisted(old)]);
    expect(index.isDuplicate(current), isTrue);
  });


  test('official import recognizes an existing automatic payment by order id', () {
    final candidate = row(
      provider: BillImportProvider.wechat,
      externalId: 'wx-auto-1',
      merchant: '早餐店',
    );
    final now = DateTime(2026, 9, 21);
    final automatic = TransactionRecord(
      id: 'auto-1',
      bookId: 'book-personal',
      type: TransactionType.expense,
      amount: candidate.amount,
      accountId: 'wechat',
      occurredAt: candidate.occurredAt,
      createdAt: now,
      updatedAt: now,
      merchant: candidate.merchant,
      source: TransactionSource.auto,
      metadataJson: jsonEncode({
        'notificationOrderId': 'wx-auto-1',
        'paymentPackageName': 'com.tencent.mm',
      }),
    );

    final index = BillImportDeduplicator.fromTransactions([automatic]);
    expect(index.isDuplicate(candidate), isTrue);
  });

  test('automatic payment fallback is provider scoped when there is no order id', () {
    final candidate = row(
      provider: BillImportProvider.alipay,
      externalId: null,
      merchant: '便利店',
      amount: 22.5,
    );
    final now = DateTime(2026, 9, 21);
    final automatic = TransactionRecord(
      id: 'auto-2',
      bookId: 'book-personal',
      type: TransactionType.expense,
      amount: candidate.amount,
      accountId: 'alipay',
      occurredAt: candidate.occurredAt,
      createdAt: now,
      updatedAt: now,
      merchant: candidate.merchant,
      source: TransactionSource.auto,
      metadataJson: jsonEncode({
        'autobookkeeping': {'sourceApp': 'ALIPAY'},
      }),
    );

    final index = BillImportDeduplicator.fromTransactions([automatic]);
    expect(index.isDuplicate(candidate), isTrue);

    final sameShapeWechat = row(
      provider: BillImportProvider.wechat,
      externalId: null,
      merchant: candidate.merchant,
      amount: candidate.amount,
      occurredAt: candidate.occurredAt,
    );
    expect(index.isDuplicate(sameShapeWechat), isFalse);
  });

  test('malformed historical metadata never blocks a fresh import', () {
    final candidate = row(externalId: 'wx-new');
    final broken = persisted(
      row(externalId: 'wx-old', merchant: '旧商户'),
      metadataOverride: '{bad-json',
    );
    final index = BillImportDeduplicator.fromTransactions([broken]);

    expect(index.isDuplicate(candidate), isFalse);
  });
}
