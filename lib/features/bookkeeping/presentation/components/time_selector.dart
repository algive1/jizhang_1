import '../../../../core/widgets/app_date_picker.dart';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_bottom_sheet.dart';

class TimeSelector {
  static Future<DateTime?> show(BuildContext context, DateTime value) async {
    final now = DateTime.now();
    String date(DateTime d) => '${d.year}年${d.month}月${d.day}日';
    final choice = await AppBottomSheet.show<int>(
      context: context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '选择时间',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          for (var i = 0; i < 3; i++)
            AppSheetOption(
              title: ['今天', '昨天', '前天'][i],
              subtitle:
                  '${date(DateTime(now.year, now.month, now.day - i))} ${TimeOfDay.fromDateTime(value).format(context)}',
              selected: DateUtils.isSameDay(
                value,
                DateTime(now.year, now.month, now.day - i),
              ),
              icon: Icons.calendar_today_outlined,
              onTap: () => Navigator.pop(sheet, i),
            ),
          AppSheetOption(
            title: '自定义日期和时间',
            subtitle: '选择具体日期与时分',
            chevron: true,
            icon: Icons.edit_calendar_outlined,
            onTap: () => Navigator.pop(sheet, 3),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (choice == null || !context.mounted) return null;
    if (choice < 3)
      return DateTime(
        now.year,
        now.month,
        now.day - choice,
        value.hour,
        value.minute,
      );
    final selected = await AppDatePicker.show(context, value);
    if (selected == null || !context.mounted) return null;
    final time = await AppTimePicker.show(
      context,
      TimeOfDay.fromDateTime(value),
    );
    if (time == null) return null;
    return DateTime(
      selected.year,
      selected.month,
      selected.day,
      time.hour,
      time.minute,
    );
  }
}
