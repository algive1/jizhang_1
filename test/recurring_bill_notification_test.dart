import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/core/models/recurring_bill.dart';
import 'package:jizhang_app/features/recurring/application/recurring_bill_notification_service.dart';

const _channel = MethodChannel('jizhang/recurring_notifications');

RecurringBill _bill({
  DateTime? nextDate,
  bool reminder = true,
  RecurringBillStatus status = RecurringBillStatus.active,
  int reminderDays = 3,
}) {
  final now = DateTime(2026, 10, 1, 12);
  return RecurringBill(
    id: 'rent/2026',
    bookId: 'book-personal',
    name: '房租',
    type: RecurringBillType.rent,
    amount: 2500,
    cycle: RecurringBillCycle.monthly,
    startDate: nextDate ?? DateTime(2026, 10, 20),
    nextDate: nextDate ?? DateTime(2026, 10, 20),
    accountId: 'account-cash',
    categoryId: 'category-rent',
    reminderDays: reminderDays,
    reminder: reminder,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('schedules the next reminder at 09:00 minus reminder days', () async {
    final scheduler = RecurringBillNotificationScheduler(channel: _channel);
    await scheduler.syncBill(_bill(), now: DateTime(2026, 10, 1, 12));

    expect(calls, hasLength(1));
    expect(calls.single.method, 'schedule');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments['id'], 'recurring-reminder-rent/2026');
    expect(
      arguments['timestamp'],
      DateTime(2026, 10, 17, 9).millisecondsSinceEpoch,
    );
    expect(arguments['route'], '/profile/recurring-bills?billId=rent%2F2026');
  });

  test('cancels reminders for paused or disabled bills', () async {
    final scheduler = RecurringBillNotificationScheduler(channel: _channel);
    await scheduler.syncBill(
      _bill(status: RecurringBillStatus.paused),
      now: DateTime(2026, 10, 1, 12),
    );
    await scheduler.syncBill(
      _bill(reminder: false),
      now: DateTime(2026, 10, 1, 12),
    );

    expect(calls.map((call) => call.method), ['cancel', 'cancel']);
  });

  test('background sync uses the finance scheduler bridge commands', () async {
    final scheduler = RecurringBillNotificationScheduler(
      channel: _channel,
      background: true,
    );
    await scheduler.syncBill(_bill(), now: DateTime(2026, 10, 1, 12));
    await scheduler.cancel('rent/2026');

    expect(calls.map((call) => call.method), [
      'scheduleReminder',
      'cancelReminder',
    ]);
  });
}
