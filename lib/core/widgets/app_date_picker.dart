import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_bottom_sheet.dart';

abstract final class AppDatePicker {
  static Future<DateTime?> show(BuildContext context, DateTime initial) async {
    var value = DateUtils.dateOnly(initial);
    return AppBottomSheet.show<DateTime>(
      context: context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '选择日期',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(
            height: 220,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: value,
              minimumYear: 1900,
              maximumYear: 2200,
              onDateTimeChanged: (date) => value = date,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.pop(sheet, value),
              child: const Text('确认日期'),
            ),
          ),
        ],
      ),
    );
  }
}

abstract final class AppTimePicker {
  static Future<TimeOfDay?> show(BuildContext context, TimeOfDay initial) {
    var value = initial;
    return AppBottomSheet.show<TimeOfDay>(
      context: context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '选择时间',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(
            height: 220,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: DateTime(
                2000,
                1,
                1,
                initial.hour,
                initial.minute,
              ),
              onDateTimeChanged: (date) => value = TimeOfDay.fromDateTime(date),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.pop(sheet, value),
              child: const Text('确认时间'),
            ),
          ),
        ],
      ),
    );
  }
}
