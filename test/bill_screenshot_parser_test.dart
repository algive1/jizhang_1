import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/ocr/application/bill_screenshot_parser.dart';
import 'package:jizhang_app/features/ocr/application/local_ocr_service.dart';

OcrElement e(String text, double left, double top, double right, double bottom) =>
    OcrElement(text: text, rect: OcrRect(left: left, top: top, right: right, bottom: bottom));

void main() {
  const parser = BillScreenshotParser();
  final now = DateTime(2026, 9, 19);

  test('parses WeChat rows by geometry and ignores monthly summary', () {
    final result = parser.parse(LocalOcrResult(
      text: '账单\n全部账单\n查找交易\n收支统计',
      blocks: const [],
      elements: [
        e('2026年9月', 20, 100, 150, 130),
        e('支出¥1276.06 收入¥601.54', 360, 100, 650, 130),
        e('美团', 130, 200, 220, 235), e('-19.80', 570, 200, 660, 235),
        e('9月19日 21:07', 130, 245, 300, 275),
        e('商家转账-来自拼多多', 130, 330, 390, 365), e('+0.06', 580, 330, 660, 365),
        e('9月13日 10:19', 130, 375, 300, 405),
      ],
    ), now: now)!;
    expect(result.transactions, hasLength(2));
    expect(result.transactions[0].merchant, '美团');
    expect(result.transactions[0].amount, 19.8);
    expect(result.transactions[0].type, TransactionType.expense);
    expect(result.transactions[1].type, TransactionType.income);
  });

  test('parses Alipay three-line row and income semantics', () {
    final result = parser.parse(LocalOcrResult(
      text: '搜索交易记录\n全部 支出 转账 退款 订单\n收支分析',
      blocks: const [],
      elements: [
        e('余额宝-收益发放', 120, 200, 330, 235), e('0.02', 590, 200, 650, 235),
        e('投资理财', 120, 240, 240, 270),
        e('08-08 02:35', 120, 280, 280, 310),
        e('水费-*建', 120, 390, 260, 425), e('-30.00', 570, 390, 650, 425),
        e('充值缴费', 120, 430, 240, 460), e('08-05 22:34', 120, 470, 280, 500),
      ],
    ), now: now)!;
    expect(result.transactions, hasLength(2));
    expect(result.transactions.first.type, TransactionType.income);
    expect(result.transactions.first.amount, .02);
    expect(result.transactions.last.type, TransactionType.expense);
  });

  test('repairs OCR confusions only in money candidates', () {
    final result = parser.parse(LocalOcrResult(
      text: '账单\n全部账单\n查找交易',
      blocks: const [],
      elements: [
        e('腾讯微保', 130, 200, 280, 235), e('-1O9.8O', 560, 200, 660, 235),
        e('9月13日 11:38', 130, 245, 300, 275),
      ],
    ), now: now)!;
    expect(result.transactions.single.amount, 109.8);
    expect(result.transactions.single.merchant, '腾讯微保');
  });

  test('does not create transaction when timestamp is missing', () {
    final result = parser.parse(LocalOcrResult(
      text: '账单\n全部账单\n查找交易',
      blocks: const [],
      elements: [e('美团', 130, 200, 220, 235), e('-19.80', 570, 200, 660, 235)],
    ), now: now);
    expect(result, isNull);
  });
  test('parses current Alipay ledger screenshot without monthly summary leakage', () {
    final result = parser.parse(
      LocalOcrResult(
        text: '搜索交易记录\n全部 支出 转账 退款 订单\n本月已省 0.00元\n收支分析',
        blocks: const [],
        elements: [
          e('9月', 24, 120, 110, 160),
          e('支出', 40, 175, 100, 205),
          e('¥74.62', 40, 215, 125, 245),
          e('收入', 290, 175, 350, 205),
          e('¥200.00', 290, 215, 390, 245),
          e('外卖红包', 120, 320, 300, 350),
          e('-0.10', 590, 320, 660, 350),
          e('其他', 120, 360, 220, 390),
          e('09-16 11:17', 120, 400, 300, 430),
          e('【用自己号】百度网盘极速下载...', 120, 500, 430, 535),
          e('-6.50', 580, 500, 660, 535),
          e('日用百货', 120, 540, 250, 570),
          e('自动扣款成功', 490, 540, 660, 570),
          e('09-07 15:18', 120, 580, 300, 610),
          e('&quot;【新店特惠】百度网盘超...', 120, 680, 450, 715),
          e('-0.02', 580, 680, 660, 715),
          e('日用百货', 120, 720, 250, 750),
          e('自动扣款成功', 490, 720, 660, 750),
          e('09-07 15:14', 120, 760, 300, 790),
          e('水费-*建', 120, 860, 280, 895),
          e('-8.00', 580, 860, 660, 895),
          e('充值缴费', 120, 900, 250, 930),
          e('09-05 13:43', 120, 940, 300, 970),
          e('电费', 120, 1040, 240, 1075),
          e('-50.00', 570, 1040, 660, 1075),
          e('充值缴费', 120, 1080, 250, 1110),
          e('09-01 11:21', 120, 1120, 300, 1150),
        ],
      ),
      now: now,
    )!;

    expect(result.transactions, hasLength(5));
    expect(result.transactions.map((item) => item.amount), containsAll([.1, 6.5, .02, 8, 50]));
    expect(
      result.transactions.any((item) => item.merchant!.contains('&quot;')),
      isFalse,
    );
    final shopping = result.transactions.firstWhere((item) => item.amount == 6.5);
    expect(shopping.categoryName, '购物');
    final water = result.transactions.firstWhere((item) => item.amount == 8);
    expect(water.categoryName, '生活缴费');
    expect(water.subcategoryName, '水费');
    final electricity = result.transactions.firstWhere((item) => item.amount == 50);
    expect(electricity.categoryName, '生活缴费');
    expect(electricity.subcategoryName, '电费');
  });

  test('month-day screenshots roll back a year instead of creating future rows', () {
    final result = parser.parse(
      LocalOcrResult(
        text: '搜索交易记录\n收支分析',
        blocks: const [],
        elements: [
          e('便利店', 120, 200, 260, 235),
          e('-12.00', 580, 200, 660, 235),
          e('12-31 23:10', 120, 245, 300, 275),
        ],
      ),
      now: DateTime(2026, 1, 2, 10),
    )!;

    expect(result.transactions.single.occurredAt.year, 2025);
  });

}
