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
}
