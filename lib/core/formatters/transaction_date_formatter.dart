/// Formats transaction dates consistently for the Chinese UI.
///
/// This formatter intentionally uses calendar arithmetic and Chinese labels
/// instead of relying on the process locale. That keeps widgets deterministic
/// in tests and avoids showing English before intl date data is initialized.
final class TransactionDateFormatter {
  const TransactionDateFormatter._();

  static const _weekdays = <String>[
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  static String groupLabel(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = _dateOnly(reference);
    final transactionDate = _dateOnly(date);
    final difference = today.difference(transactionDate).inDays;
    final relative = switch (difference) {
      0 => '今天',
      1 => '昨天',
      2 => '前天',
      _ => _weekdays[date.weekday - 1],
    };
    final dateText = date.year == today.year
        ? '${date.month}月${date.day}日'
        : '${date.year}年${date.month}月${date.day}日';
    return '$dateText  $relative';
  }

  static String time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String monthDayTime(DateTime value) {
    final local = value.toLocal();
    return '${local.month}月${local.day}日 ${time(local)}';
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
