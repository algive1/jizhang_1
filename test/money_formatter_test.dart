import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/formatters/money_formatter.dart';

void main() {
  test('whole amount uses grouping separators without a leading comma', () {
    expect(MoneyFormatter.whole(0), '0');
    expect(MoneyFormatter.whole(18), '18');
    expect(MoneyFormatter.whole(114), '114');
    expect(MoneyFormatter.whole(1132), '1,132');
    expect(MoneyFormatter.whole(68500), '68,500');
  });
}
