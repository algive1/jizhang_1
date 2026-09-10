import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

Future<DateTime?> showHomeMonthPicker(
  BuildContext context,
  DateTime selected, {
  bool yearFirst = false,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _MonthPicker(selected: selected, yearFirst: yearFirst),
);

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.selected, required this.yearFirst});
  final DateTime selected;
  final bool yearFirst;
  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int year = widget.selected.year;
  late bool choosingYear = widget.yearFirst;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => setState(() => choosingYear = !choosingYear),
              child: Text('$year年 ${choosingYear ? '· 选择年份' : '· 选择月份'}'),
            ),
          ),
          IconButton(
            tooltip: '关闭月份选择',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 300,
        child: choosingYear
            ? YearPicker(
                firstDate: DateTime(1900),
                lastDate: DateTime(now.year),
                selectedDate: DateTime(year),
                onChanged: (value) => setState(() {
                  year = value.year;
                  choosingYear = false;
                }),
              )
            : GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 1.35,
                children: [
                  for (var month = 1; month <= 12; month++)
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor:
                            year == widget.selected.year &&
                                month == widget.selected.month
                            ? AppColors.primarySoft
                            : null,
                      ),
                      onPressed: year == now.year && month > now.month
                          ? null
                          : () => Navigator.pop(context, DateTime(year, month)),
                      child: Text('$month月'),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, DateTime(now.year, now.month)),
          child: const Text('回到本月'),
        ),
      ],
    );
  }
}
