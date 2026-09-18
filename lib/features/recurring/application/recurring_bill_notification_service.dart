import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/recurring_bill.dart';

/// Schedules one native system notification for the next reminder occurrence.
///
/// The native side owns the alarm/notification implementation. Keeping the
/// date calculation here means Android and iOS receive the same business
/// rule, including last-day/monthly and yearly anchors.
class RecurringBillNotificationScheduler {
  RecurringBillNotificationScheduler({
    MethodChannel? channel,
    this.background = false,
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'jizhang/recurring_notifications';
  static const _routePrefix = '/profile/recurring-bills?billId=';

  final MethodChannel _channel;
  final bool background;

  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } on MissingPluginException {
      // Desktop and test hosts do not expose native notification APIs.
    }
  }

  Future<void> syncBill(RecurringBill bill, {DateTime? now}) async {
    if (!bill.reminder || bill.status != RecurringBillStatus.active) {
      await cancel(bill.id);
      return;
    }
    final reminderAt = _nextReminderAt(bill, now ?? DateTime.now());
    if (reminderAt == null) {
      await cancel(bill.id);
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        background ? 'scheduleReminder' : 'schedule',
        {
          'id': _notificationId(bill.id),
          'title': '周期账单提醒',
          'body': '${bill.name} · ¥${MoneyFormatter.decimal(bill.amount)}',
          'timestamp': reminderAt.millisecondsSinceEpoch,
          'route': '$_routePrefix${Uri.encodeComponent(bill.id)}',
        },
      );
    } on MissingPluginException {
      // Desktop and test hosts do not expose native notification APIs.
    }
  }

  Future<void> syncBills(Iterable<RecurringBill> bills, {DateTime? now}) async {
    for (final bill in bills) {
      await syncBill(bill, now: now);
    }
  }

  Future<void> cancel(String billId) async {
    try {
      await _channel.invokeMethod<void>(
        background ? 'cancelReminder' : 'cancel',
        {'id': _notificationId(billId)},
      );
    } on MissingPluginException {
      // Desktop and test hosts do not expose native notification APIs.
    }
  }

  DateTime? _nextReminderAt(RecurringBill bill, DateTime now) {
    var occurrence = DateTime(
      bill.nextDate.year,
      bill.nextDate.month,
      bill.nextDate.day,
    );
    for (var attempt = 0; attempt < 366; attempt++) {
      if (bill.endDate != null && occurrence.isAfter(bill.endDate!)) {
        return null;
      }
      final reminderAt = DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
        9,
      ).subtract(Duration(days: bill.reminderDays));
      if (reminderAt.isAfter(now)) return reminderAt;
      occurrence = bill.nextOccurrence(occurrence);
    }
    return null;
  }

  static String _notificationId(String billId) => 'recurring-reminder-$billId';
}

final recurringBillNotificationSchedulerProvider =
    Provider<RecurringBillNotificationScheduler>(
      (ref) => RecurringBillNotificationScheduler(),
    );
