import 'package:intl/intl.dart';

abstract final class MoneyFormatter {
  static final NumberFormat _wholeAmount = NumberFormat.decimalPattern('zh_CN');

  static String whole(num amount) => _wholeAmount.format(amount.round());

  static String decimal(num amount) =>
      NumberFormat('#,##0.00', 'zh_CN').format(amount);

  static double? parseInput(String value, {bool signed = false}) {
    final text = value.trim();
    final pattern = signed ? r'^-?\d+(\.\d{1,2})?$' : r'^\d+(\.\d{1,2})?$';
    if (!RegExp(pattern).hasMatch(text)) return null;
    final amount = double.tryParse(text);
    if (amount == null || !amount.isFinite || amount.abs() > 1000000000000) {
      return null;
    }
    return amount;
  }
}
