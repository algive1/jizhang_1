import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/bill_import/application/bill_import_service.dart';

void main() {
  const service = BillImportService();

  test('parses WeChat official CSV and skips refunded rows', () {
    const csv = '''
微信支付账单明细
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-09-18 12:30:00,商户消费,午餐店,套餐,支出,28.50,零钱,支付成功,wx-1,m-1,
2026-09-18 13:30:00,商户消费,退款店,商品,支出,10.00,零钱,已退款,wx-2,m-2,
''';
    final result = service.parseCsv(csv);
    expect(result.provider, BillImportProvider.wechat);
    expect(result.rows, hasLength(1));
    expect(result.skipped, 1);
    expect(result.rows.single.type, TransactionType.expense);
    expect(result.rows.single.amount, 28.5);
    expect(result.rows.single.merchant, '午餐店');
    expect(result.rows.single.externalId, 'wx-1');
  });

  test('recognizes WeChat official XLSX and ignores slash placeholders', () {
    final bytes = _xlsx([
      ['微信支付账单明细'],
      [
        '交易时间',
        '交易类型',
        '交易对方',
        '商品',
        '收/支',
        '金额(元)',
        '支付方式',
        '当前状态',
        '交易单号',
        '商户单号',
        '备注',
      ],
      [
        '2026-09-20 10:07:00',
        '商户消费',
        '周姐老面包子',
        '/',
        '支出',
        '9.00',
        '零钱',
        '支付成功',
        'wx-xlsx-1',
        'merchant-xlsx-1',
        '/',
      ],
    ]);

    final result = service.parseXlsx(bytes);

    expect(result.provider, BillImportProvider.wechat);
    expect(result.provider.needsAccountMapping, isFalse);
    expect(result.rows, hasLength(1));
    expect(result.rows.single.merchant, '周姐老面包子');
    expect(result.rows.single.note, isEmpty);
    expect(result.rows.single.externalId, 'wx-xlsx-1');
  });

  test('natural fingerprint survives official XLSX provider reclassification', () {
    final occurredAt = DateTime(2026, 9, 20, 10, 7);
    final legacy = ImportedBillRow(
      provider: BillImportProvider.generic,
      occurredAt: occurredAt,
      type: TransactionType.expense,
      amount: 9,
      merchant: '周姐老面包子',
      note: '/',
      externalId: null,
      paymentMethod: null,
      raw: const {},
    );
    final current = ImportedBillRow(
      provider: BillImportProvider.wechat,
      occurredAt: occurredAt,
      type: TransactionType.expense,
      amount: 9,
      merchant: '周姐老面包子',
      note: '',
      externalId: null,
      paymentMethod: '零钱',
      raw: const {},
    );

    expect(current.importFingerprint, isNot(legacy.importFingerprint));
    expect(current.naturalFingerprint, legacy.naturalFingerprint);
  });

  test('imported transaction title keeps merchant ahead of provider remarks', () {
    final now = DateTime(2026, 9, 20, 10, 7);
    final record = TransactionRecord(
      id: 'imported-title',
      bookId: 'book-personal',
      type: TransactionType.expense,
      amount: 9,
      accountId: 'wechat',
      merchant: '周姐老面包子',
      note: '/',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      source: TransactionSource.import,
    );

    expect(record.displayTitle, '周姐老面包子');
  });

  test('parses Alipay official CSV income and expense', () {
    const csv = '''
交易号,商家订单号,交易创建时间,付款时间,交易来源地,类型,交易对方,商品名称,金额（元）,收/支,交易状态,资金状态
ali-1,merchant-1,2026-09-17 08:00:00,2026-09-17 08:01:00,其他,即时到账交易,便利店,早餐,12.80,支出,交易成功,已支出
ali-2,merchant-2,2026-09-17 09:00:00,2026-09-17 09:01:00,其他,转账,客户,回款,88.00,收入,交易成功,已收入
''';
    final result = service.parseCsv(csv);
    expect(result.provider, BillImportProvider.alipay);
    expect(result.rows, hasLength(2));
    expect(result.rows[0].type, TransactionType.expense);
    expect(result.rows[1].type, TransactionType.income);
    expect(result.rows[1].amount, 88);
  });

  test('parses MuMu legacy XLSX format and keeps blank shared strings blank', () {
    final bytes = _xlsx([
      [
        '日期',
        '收支类型',
        '金额',
        '类别',
        '子类',
        '所属账本',
        '转出账户',
        '转入账户',
        '备注',
        '账单图片',
        '报销',
        '优惠',
        '标签',
        '成员',
      ],
      [
        '2026-09-01 08:30',
        '支出',
        '-18.50',
        '餐饮',
        '',
        '日常生活',
        '招商银行信用卡',
        '',
        '早餐',
        '',
        '',
        '',
        '工作日',
        '',
      ],
    ]);

    final result = service.parseMumuXlsx(bytes);

    expect(result.provider, BillImportProvider.mumu);
    expect(result.rows, hasLength(1));
    final row = result.rows.single;
    expect(row.type, TransactionType.expense);
    expect(row.amount, 18.5);
    expect(row.sourceCategory, '餐饮');
    expect(row.sourceSubcategory, isNull);
    expect(row.sourceAccount, '招商银行信用卡');
    expect(row.destinationAccount, isNull);
    expect(row.tags, ['工作日']);
  });

  test('parses MuMu new XLSX transfer and reimbursement semantics', () {
    final bytes = _xlsx([
      [
        '时间',
        '类型',
        '分类',
        '二级分类',
        '金额',
        '账本',
        '转出账户',
        '转入账户',
        '备注',
        '账单图片',
        '报销',
        '优惠',
        '标签',
        '成员',
      ],
      [
        '2026-09-02 10:00',
        '转账',
        '转账',
        '',
        '120.00',
        '日常生活',
        '微信小号',
        '支付宝',
        '',
        '',
        '',
        '',
        '',
        '',
      ],
      [
        '2026-09-02 12:00',
        '支出',
        '待报销',
        '',
        '-42.00',
        '日常生活',
        '微信小号',
        '',
        '打车',
        '',
        '',
        '',
        '',
        '',
      ],
      [
        '2026-09-03 09:00',
        '收入',
        '报销',
        '',
        '42.00',
        '日常生活',
        '微信小号',
        '',
        '报销到账',
        '',
        '',
        '',
        '',
        '',
      ],
      [
        '2026-09-04 09:00',
        '支出',
        '待报销',
        '',
        '-88.00',
        '日常生活',
        '支付宝',
        '',
        '键盘',
        '',
        '已报销',
        '',
        '',
        '',
      ],
    ]);

    final result = service.parseMumuXlsx(bytes);

    expect(result.rows, hasLength(4));
    expect(result.rows[0].type, TransactionType.transfer);
    expect(result.rows[0].sourceAccount, '微信小号');
    expect(result.rows[0].destinationAccount, '支付宝');
    expect(result.rows[1].type, TransactionType.expense);
    expect(
      result.rows[1].reimbursementStatus,
      ReimbursementStatus.pending,
    );
    expect(result.rows[2].type, TransactionType.reimbursement);
    expect(
      result.rows[3].reimbursementStatus,
      ReimbursementStatus.reimbursed,
    );
  });

  test('parses generic third-party CSV with semantic headers', () {
    const csv = '''
时间,类型,金额,分类,二级分类,账户,备注
2026-09-05 08:00,支出,-12.50,餐饮,早餐,招行信用卡,豆浆油条
2026-09-05 09:00,收入,88.00,兼职,,支付宝,稿费
''';

    final result = service.parseCsv(csv);

    expect(result.provider, BillImportProvider.generic);
    expect(result.rows, hasLength(2));
    expect(result.rows[0].sourceAccount, '招行信用卡');
    expect(result.rows[0].sourceCategory, '餐饮');
    expect(result.rows[0].sourceSubcategory, '早餐');
    expect(result.rows[0].amount, 12.5);
    expect(result.rows[1].type, TransactionType.income);
  });

  test('parses tab-separated TXT exports', () {
    const tsv =
        '日期\t收支类型\t金额\t分类\t账户\t备注\n'
        '2026-09-06 10:00\t支出\t-35.00\t家居日用\t现金\t清洁用品\n';

    final result = service.parseCsv(tsv);

    expect(result.provider, BillImportProvider.generic);
    expect(result.rows, hasLength(1));
    expect(result.rows.single.sourceCategory, '家居日用');
    expect(result.rows.single.sourceAccount, '现金');
    expect(result.rows.single.amount, 35);
  });

  test('parses generic XLSX instead of assuming every workbook is MuMu', () {
    final bytes = _xlsx([
      ['时间', '类型', '金额', '分类', '账户', '备注'],
      ['2026-09-07 20:00', '支出', '-68', '烟酒茶', '现金', '茶叶'],
    ]);

    final result = service.parseXlsx(bytes);

    expect(result.provider, BillImportProvider.generic);
    expect(result.rows.single.sourceCategory, '烟酒茶');
    expect(result.rows.single.note, '茶叶');
  });
}

List<int> _xlsx(List<List<String>> rows) {
  final strings = <String>[];
  final indexes = <String, int>{};

  int stringIndex(String value) {
    return indexes.putIfAbsent(value, () {
      strings.add(value);
      return strings.length - 1;
    });
  }

  final rowXml = <String>[];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final cells = <String>[];
    for (var column = 0; column < rows[rowIndex].length; column++) {
      final value = rows[rowIndex][column];
      final ref = '${_columnName(column)}${rowIndex + 1}';
      cells.add('<c r="$ref" t="s"><v>${stringIndex(value)}</v></c>');
    }
    rowXml.add('<row r="${rowIndex + 1}">${cells.join()}</row>');
  }

  final shared = strings
      .map((value) => '<si><t>${_xmlEscape(value)}</t></si>')
      .join();
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'xl/sharedStrings.xml',
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'count="${strings.length}" uniqueCount="${strings.length}">'
        '$shared'
        '</sst>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'xl/worksheets/sheet1.xml',
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>${rowXml.join()}</sheetData>'
        '</worksheet>',
      ),
    );
  return ZipEncoder().encode(archive);
}

String _columnName(int index) {
  var value = index + 1;
  final result = StringBuffer();
  while (value > 0) {
    value--;
    result.writeCharCode(65 + value % 26);
    value ~/= 26;
  }
  return result.toString().split('').reversed.join();
}

String _xmlEscape(String value) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(value);
