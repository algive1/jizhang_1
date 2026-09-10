import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/formatters/transaction_date_formatter.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);

  test('formats relative dates and weekdays in Chinese', () {
    expect(
      TransactionDateFormatter.groupLabel(DateTime(2026, 9, 8), now: now),
      '9月8日  今天',
    );
    expect(
      TransactionDateFormatter.groupLabel(DateTime(2026, 9, 7), now: now),
      '9月7日  昨天',
    );
    expect(
      TransactionDateFormatter.groupLabel(DateTime(2026, 9, 6), now: now),
      '9月6日  前天',
    );
    expect(
      TransactionDateFormatter.groupLabel(DateTime(2026, 9, 5), now: now),
      '9月5日  星期六',
    );
  });

  test('keeps the month and year correct across boundaries', () {
    expect(
      TransactionDateFormatter.groupLabel(DateTime(2026, 8, 31), now: now),
      '8月31日  星期一',
    );
    expect(
      TransactionDateFormatter.groupLabel(DateTime(2025, 12, 31), now: now),
      '2025年12月31日  星期三',
    );
  });

  test(
    'formats transaction time and search date-time in 24-hour Chinese form',
    () {
      final occurredAt = DateTime(2026, 9, 8, 7, 5);
      expect(TransactionDateFormatter.time(occurredAt), '07:05');
      expect(TransactionDateFormatter.monthDayTime(occurredAt), '9月8日 07:05');
    },
  );
}
