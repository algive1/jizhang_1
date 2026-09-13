import 'package:flutter/services.dart';

class FinanceSchedulerBridge {
  const FinanceSchedulerBridge();

  static const _channel = MethodChannel('jizhang/finance_scheduler');

  Future<void> scheduleDaily() async {
    try {
      await _channel.invokeMethod<void>('schedule');
    } on MissingPluginException {
      // Desktop, iOS and test hosts can still process schedules on resume.
    }
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // The native scheduler is optional outside Android.
    }
  }
}
