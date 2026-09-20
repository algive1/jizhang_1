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

  test('parses the supplied Alipay transaction-list screenshot structure', () {
    final result = parser.parse(LocalOcrResult(
      text: '搜索交易记录\n全部 支出 转账 退款 订单\n筛选\n9月\n支出 ¥74.62 收入 ¥200.00\n本月已省 0.00元\n收支分析',
      blocks: const [],
      elements: [
        e('9月', 58, 300, 120, 350),
        e('支出 ¥74.62 收入 ¥200.00', 60, 410, 430, 455),
        e('本月已省 0.00元', 60, 520, 270, 560),
        e('外卖红包', 145, 655, 290, 695), e('-0.10', 690, 655, 780, 695),
        e('其他', 145, 720, 230, 755), e('09-16 11:17', 145, 780, 310, 815),
        e('【用自己号】百度网盘极速下载...', 145, 890, 520, 930), e('-6.50', 690, 890, 780, 930),
        e('日用百货', 145, 950, 270, 985), e('自动扣款成功', 620, 950, 780, 985),
        e('09-07 15:18', 145, 1010, 310, 1045),
        e('&quot;【新店特惠】百度网盘超...', 145, 1120, 520, 1160), e('-0.02', 690, 1120, 780, 1160),
        e('日用百货', 145, 1180, 270, 1215), e('自动扣款成功', 620, 1180, 780, 1215),
        e('09-07 15:14', 145, 1240, 310, 1275),
        e('水费-*建', 145, 1350, 300, 1390), e('-8.00', 690, 1350, 780, 1390),
        e('充值缴费', 145, 1410, 270, 1445), e('09-05 13:43', 145, 1470, 310, 1505),
        e('电费', 145, 1580, 240, 1620), e('-50.00', 680, 1580, 780, 1620),
        e('充值缴费', 145, 1640, 270, 1675), e('09-01 11:21', 145, 1700, 310, 1735),
      ],
    ), now: DateTime(2026, 9, 20))!;

    expect(result.transactions, hasLength(5));
    expect(
      result.transactions.map((item) => item.amount),
      orderedEquals([.10, 6.50, .02, 8.00, 50.00]),
    );
    expect(result.transactions.first.merchant, '外卖红包');
    expect(result.transactions[1].merchant, contains('百度网盘极速下载'));
    expect(result.transactions[3].merchant, '水费-*建');
    expect(result.transactions.last.merchant, '电费');
    expect(
      result.transactions.every((item) => item.type == TransactionType.expense),
      isTrue,
    );
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
}
