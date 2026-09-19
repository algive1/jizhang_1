import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/models/book.dart';
import '../../../core/models/family.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/book_color_dot.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../../books/data/book_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/transaction_actions.dart';

class ConsumptionCalendarPage extends ConsumerStatefulWidget {
  const ConsumptionCalendarPage({super.key});

  @override
  ConsumerState<ConsumptionCalendarPage> createState() =>
      _ConsumptionCalendarPageState();
}

enum _CalendarViewMode { month, week, stats }

enum _CalendarHeaderAction {
  bookFilter,
  today,
  previousRecordedMonth,
  nextRecordedMonth,
}

class _ConsumptionCalendarPageState
    extends ConsumerState<ConsumptionCalendarPage> {
  DateTime get _today => DateTime.now();
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;
  String? _bookFilterId;
  _CalendarViewMode _viewMode = _CalendarViewMode.month;

  @override
  void initState() {
    super.initState();
    // Calendar scope starts from the app's active ledger, but remains local to
    // this page. Changing it must never switch the global active ledger.
    _bookFilterId = ref.read(activeBookIdProvider);
    _selectedDay = _today.day;
  }

  @override
  Widget build(BuildContext context) {
    final all =
        ref.watch(allTransactionsProvider).value ?? const <TransactionRecord>[];
    final booksValue = ref.watch(booksProvider).value;
    final books = booksValue ?? const <LedgerBook>[];
    final effectiveBookFilterId = _effectiveBookFilterId(booksValue);
    final filtered = effectiveBookFilterId == null
        ? all
        : all.where((item) => item.bookId == effectiveBookFilterId).toList();
    final monthTransactions = filtered.where((item) {
      final date = item.occurredAt;
      return item.deletedAt == null &&
          date.year == _month.year &&
          date.month == _month.month &&
          !_isFutureDate(date);
    }).toList();

    final dailyExpense = <int, double>{};
    final dailyIncome = <int, double>{};
    final dailyExpenseCents = <int, int>{};
    final dailyOther = <int>{};
    for (final item in monthTransactions) {
      final day = item.occurredAt.day;
      if (_isConsumption(item)) {
        final cents = (item.netExpenseAmount * 100).round();
        dailyExpense.update(
          day,
          (value) => value + item.netExpenseAmount,
          ifAbsent: () => item.netExpenseAmount,
        );
        dailyExpenseCents.update(
          day,
          (value) => value + cents,
          ifAbsent: () => cents,
        );
      } else if (item.isIncome) {
        dailyIncome.update(
          day,
          (value) => value + item.amount,
          ifAbsent: () => item.amount,
        );
      } else {
        dailyOther.add(day);
      }
    }

    final selected = _selectedDay == null
        ? const <TransactionRecord>[]
        : (monthTransactions
              .where((item) => item.occurredAt.day == _selectedDay)
              .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt)));

    final recordMonths =
        filtered
            .where(
              (item) =>
                  item.deletedAt == null && !_isFutureDate(item.occurredAt),
            )
            .map(
              (item) => DateTime(item.occurredAt.year, item.occurredAt.month),
            )
            .toSet()
            .toList()
          ..sort();
    final previousRecorded = recordMonths
        .where((item) => item.isBefore(_month))
        .lastOrNull;
    final nextRecorded = recordMonths
        .where((item) => item.isAfter(_month))
        .firstOrNull;

    final totalExpense = monthTransactions
        .where(_isConsumption)
        .fold<double>(0, (sum, item) => sum + item.netExpenseAmount);
    final totalIncome = monthTransactions
        .where((item) => item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final balance = totalIncome - totalExpense;
    final highest = dailyExpenseCents.entries.isEmpty
        ? null
        : dailyExpenseCents.entries.reduce((a, b) {
            if (a.value != b.value) return a.value > b.value ? a : b;
            return a.key < b.key ? a : b;
          });

    final selectedDate = _selectedDay == null
        ? null
        : DateTime(_month.year, _month.month, _selectedDay!);
    final calendarDates = _viewMode == _CalendarViewMode.week
        ? _weekDates(selectedDate)
        : _monthDates(_month);
    var calendarExpense = dailyExpense;
    var calendarIncome = dailyIncome;
    var calendarOther = dailyOther;
    if (_viewMode == _CalendarViewMode.week) {
      final visibleDateKeys = calendarDates.map(_dateKey).toSet();
      calendarExpense = <int, double>{};
      calendarIncome = <int, double>{};
      calendarOther = <int>{};
      for (final item in filtered) {
        if (item.deletedAt != null ||
            _isFutureDate(item.occurredAt) ||
            !visibleDateKeys.contains(_dateKey(item.occurredAt))) {
          continue;
        }
        final day = item.occurredAt.day;
        if (_isConsumption(item)) {
          calendarExpense.update(
            day,
            (value) => value + item.netExpenseAmount,
            ifAbsent: () => item.netExpenseAmount,
          );
        } else if (item.isIncome) {
          calendarIncome.update(
            day,
            (value) => value + item.amount,
            ifAbsent: () => item.amount,
          );
        } else {
          calendarOther.add(day);
        }
      }
    }
    final calendarMaxDailyExpense = calendarExpense.values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    return Scaffold(
      backgroundColor: context.appBackground,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _CalendarHeroHeader(
            previousRecordedMonth: previousRecorded,
            nextRecordedMonth: nextRecorded,
            onBack: () => context.canPop() ? context.pop() : context.go('/'),
            onAnalytics: _openAnalysis,
            onAction: (action) {
              switch (action) {
                case _CalendarHeaderAction.bookFilter:
                  _openBookFilter();
                case _CalendarHeaderAction.today:
                  _goToday();
                case _CalendarHeaderAction.previousRecordedMonth:
                  if (previousRecorded != null) _setMonth(previousRecorded);
                case _CalendarHeaderAction.nextRecordedMonth:
                  if (nextRecorded != null) _setMonth(nextRecorded);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              children: [
                AppCard(
                  borderRadius: 28,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    children: [
                      _CalendarToolbar(
                        month: _month,
                        mode: _viewMode,
                        canGoNext: !_isCurrentMonth,
                        onPrevious: () => _moveMonth(-1),
                        onNext: () => _moveMonth(1),
                        onModeChanged: (mode) =>
                            setState(() => _viewMode = mode),
                      ),
                      const SizedBox(height: 6),
                      if (_viewMode != _CalendarViewMode.stats) ...[
                        const _WeekdayHeader(),
                        const SizedBox(height: 6),
                        _CalendarGrid(
                          month: _month,
                          dates: calendarDates,
                          dailyExpense: calendarExpense,
                          dailyIncome: calendarIncome,
                          dailyOther: calendarOther,
                          maxDailyExpense: calendarMaxDailyExpense,
                          showDataOutsideMonth:
                              _viewMode == _CalendarViewMode.week,
                          selectedDay: _selectedDay,
                          today: _today,
                          onDateTap: (date) => setState(() {
                            _month = DateTime(date.year, date.month);
                            _selectedDay = date.day;
                          }),
                        ),
                      ] else
                        _CalendarInlineStats(
                          totalExpense: totalExpense,
                          totalIncome: totalIncome,
                          balance: balance,
                          consumptionDays: dailyExpenseCents.length,
                          highestExpenseDay: highest?.key,
                          highestExpenseCents: highest?.value,
                        ),
                      const SizedBox(height: 8),
                      _CalendarFooter(
                        books: books,
                        selectedBookId: effectiveBookFilterId,
                        onBookTap: _openBookFilter,
                        onToday: _goToday,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedDate != null)
                  _SelectedDayCard(
                    date: selectedDate,
                    transactions: selected,
                    onAdd: _addForSelectedDate,
                  ),
                if (selectedDate != null) const SizedBox(height: 12),
                _MonthlyOverviewCard(
                  month: _month,
                  totalExpense: totalExpense,
                  totalIncome: totalIncome,
                  balance: balance,
                  consumptionDays: dailyExpenseCents.length,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isCurrentMonth =>
      _month.year == _today.year && _month.month == _today.month;

  int _dateKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  bool _isFutureDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final today = _today;
    return day.isAfter(DateTime(today.year, today.month, today.day));
  }

  /// Keep the calendar aligned with the app's consumption-expense flag while
  /// excluding fully offset or refunded records whose net expense is not positive.
  bool _isConsumption(TransactionRecord item) =>
      item.deletedAt == null &&
      item.isConsumptionExpense &&
      item.netExpenseAmount > 0;

  List<DateTime> _monthDates(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final end = last.add(Duration(days: 7 - last.weekday));
    final count = end.difference(start).inDays + 1;
    return List.generate(count, (index) => start.add(Duration(days: index)));
  }

  List<DateTime> _weekDates(DateTime? selectedDate) {
    final anchor = selectedDate ??
        (_isCurrentMonth ? _today : DateTime(_month.year, _month.month, 1));
    final start = anchor.subtract(Duration(days: anchor.weekday - 1));
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  void _moveMonth(int delta) {
    if (delta > 0 && _isCurrentMonth) return;
    final candidate = DateTime(_month.year, _month.month + delta);
    if (candidate.year < 2000) return;
    _setMonth(candidate);
  }

  void _setMonth(DateTime month) => setState(() {
    _month = DateTime(month.year, month.month);
    _selectedDay = _isCurrentMonth ? _today.day : null;
    if (_viewMode == _CalendarViewMode.week) {
      _viewMode = _CalendarViewMode.month;
    }
  });

  void _goToday() => setState(() {
    _month = DateTime(_today.year, _today.month);
    _selectedDay = _today.day;
  });

  void _openAnalysis() {
    final month = _month.month.toString().padLeft(2, '0');
    context.push('/analysis?month=${_month.year}-$month');
  }

  Future<void> _addForSelectedDate() async {
    final day = _selectedDay ?? (_isCurrentMonth ? _today.day : 1);
    final selectedDate = DateTime(_month.year, _month.month, day);
    final scopedBookId = _effectiveBookFilterId(ref.read(booksProvider).value);
    final initialBookId = scopedBookId ?? ref.read(activeBookIdProvider);
    await showQuickAddSheet(
      context,
      initialOccurredAt: selectedDate,
      initialBookId: initialBookId,
    );
  }

  String? _effectiveBookFilterId(List<LedgerBook>? books) {
    final selectedBookId = _bookFilterId;
    if (selectedBookId == null || books == null) return selectedBookId;
    return books.any((book) => book.id == selectedBookId)
        ? selectedBookId
        : null;
  }

  Future<void> _openBookFilter() async {
    final books = ref.read(booksProvider).value ?? const <LedgerBook>[];
    final effectiveBookFilterId = _effectiveBookFilterId(books);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appBackground,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Text(
              '统计范围',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.all_inclusive, color: context.appPrimary),
              title: const Text('全部账本'),
              subtitle: const Text('汇总当前账号可访问的账本'),
              trailing: effectiveBookFilterId == null
                  ? Icon(Icons.check, color: context.appPrimary)
                  : null,
              onTap: () => Navigator.pop(context, _allBooksFilterValue),
            ),
            ...books.map(
              (book) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: BookColorDot(book: book, size: 12),
                title: Text(book.name),
                subtitle: Text(book.type.label),
                trailing: effectiveBookFilterId == book.id
                    ? Icon(Icons.check, color: context.appPrimary)
                    : null,
                onTap: () => Navigator.pop(context, book.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _bookFilterId = selected == _allBooksFilterValue ? null : selected;
      // Keep month/day stable so users can compare the same date across books.
    });
  }

  static const _allBooksFilterValue = '__all_books__';
}

class _CalendarHeroHeader extends StatelessWidget {
  const _CalendarHeroHeader({
    required this.previousRecordedMonth,
    required this.nextRecordedMonth,
    required this.onBack,
    required this.onAnalytics,
    required this.onAction,
  });

  final DateTime? previousRecordedMonth;
  final DateTime? nextRecordedMonth;
  final VoidCallback onBack;
  final VoidCallback onAnalytics;
  final ValueChanged<_CalendarHeaderAction> onAction;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = (screenHeight * .215).clamp(190.0, 220.0).toDouble();

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            '微信图片_20260919140237_156_240.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  context.appBackground.withValues(alpha: .08),
                  context.appBackground,
                ],
                stops: const [0, .78, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  children: [
                    _HeroIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: '返回',
                      onPressed: onBack,
                    ),
                    const Spacer(),
                    _HeroIconButton(
                      icon: Icons.bar_chart_rounded,
                      tooltip: '收支分析',
                      onPressed: onAnalytics,
                    ),
                    const SizedBox(width: 2),
                    PopupMenuButton<_CalendarHeaderAction>(
                      tooltip: '更多',
                      onSelected: onAction,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _CalendarHeaderAction.bookFilter,
                          child: Text('选择账本'),
                        ),
                        const PopupMenuItem(
                          value: _CalendarHeaderAction.today,
                          child: Text('回到今天'),
                        ),
                        PopupMenuItem(
                          value: _CalendarHeaderAction.previousRecordedMonth,
                          enabled: previousRecordedMonth != null,
                          child: const Text('上个有记录月份'),
                        ),
                        PopupMenuItem(
                          value: _CalendarHeaderAction.nextRecordedMonth,
                          enabled: nextRecordedMonth != null,
                          child: const Text('下个有记录月份'),
                        ),
                      ],
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.more_horiz_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: context.appSurface.withValues(alpha: .72),
          foregroundColor: context.appPrimaryText,
        ),
      );
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.month,
    required this.mode,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onModeChanged,
  });

  final DateTime month;
  final _CalendarViewMode mode;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<_CalendarViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        if (compact) {
          return Column(
            children: [
              _MonthNavigator(
                month: month,
                canGoNext: canGoNext,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
              const SizedBox(height: 8),
              _ViewModeSegment(
                mode: mode,
                onChanged: onModeChanged,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _MonthNavigator(
                month: month,
                canGoNext: canGoNext,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 156,
              child: _ViewModeSegment(
                mode: mode,
                onChanged: onModeChanged,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: '上个月',
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${month.year}年${month.month}月',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: '下个月',
          ),
        ],
      );
}

class _ViewModeSegment extends StatelessWidget {
  const _ViewModeSegment({required this.mode, required this.onChanged});

  final _CalendarViewMode mode;
  final ValueChanged<_CalendarViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appSurfaceSoft,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          _SegmentItem(
            label: '月',
            selected: mode == _CalendarViewMode.month,
            onTap: () => onChanged(_CalendarViewMode.month),
          ),
          _SegmentItem(
            label: '周',
            selected: mode == _CalendarViewMode.week,
            onTap: () => onChanged(_CalendarViewMode.week),
          ),
          _SegmentItem(
            label: '统计',
            selected: mode == _CalendarViewMode.stats,
            onTap: () => onChanged(_CalendarViewMode.stats),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? context.appPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: context.appPrimary.withValues(alpha: .18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : context.appPrimaryText,
              ),
            ),
          ),
        ),
      );
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) => Row(
        children: const ['一', '二', '三', '四', '五', '六', '日']
            .map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            )
            .toList(),
      );
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.dates,
    required this.dailyExpense,
    required this.dailyIncome,
    required this.dailyOther,
    required this.maxDailyExpense,
    required this.showDataOutsideMonth,
    required this.selectedDay,
    required this.today,
    required this.onDateTap,
  });

  final DateTime month;
  final List<DateTime> dates;
  final Map<int, double> dailyExpense;
  final Map<int, double> dailyIncome;
  final Set<int> dailyOther;
  final double maxDailyExpense;
  final bool showDataOutsideMonth;
  final int? selectedDay;
  final DateTime today;
  final ValueChanged<DateTime> onDateTap;

  @override
  Widget build(BuildContext context) {
    final selectedDate = selectedDay == null
        ? null
        : DateTime(month.year, month.month, selectedDay!);

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseCellHeight =
            (constraints.maxWidth / 7 * 1.04).clamp(48.0, 56.0).toDouble();
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final scaleExtra = (textScale - 1).clamp(0.0, 0.6).toDouble();
        final cellHeight = baseCellHeight + scaleExtra * 24;
        final rowCount = (dates.length / 7).ceil();

        return SizedBox(
          height: rowCount * cellHeight,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dates.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: cellHeight,
            ),
            itemBuilder: (context, index) {
              final date = dates[index];
              final inMonth =
                  date.year == month.year && date.month == month.month;
              final isFuture =
                  date.isAfter(DateTime(today.year, today.month, today.day));
              final showData = inMonth || showDataOutsideMonth;
              final amount =
                  showData ? (dailyExpense[date.day] ?? 0) : 0.0;
              final income =
                  showData ? (dailyIncome[date.day] ?? 0) : 0.0;
              final hasOther =
                  showData && dailyOther.contains(date.day);
              final intensity = maxDailyExpense == 0
                  ? 0.0
                  : (amount / maxDailyExpense).clamp(0.0, 1.0);
              final selected = selectedDate != null &&
                  DateUtils.isSameDay(date, selectedDate);

              return _CalendarDateCell(
                date: date,
                inMonth: inMonth,
                isFuture: isFuture,
                selected: selected,
                expense: amount,
                income: income,
                hasOther: hasOther,
                intensity: intensity,
                onTap: isFuture ? null : () => onDateTap(date),
              );
            },
          ),
        );
      },
    );
  }
}

class _CalendarDateCell extends StatelessWidget {
  const _CalendarDateCell({
    required this.date,
    required this.inMonth,
    required this.isFuture,
    required this.selected,
    required this.expense,
    required this.income,
    required this.hasOther,
    required this.intensity,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool isFuture;
  final bool selected;
  final double expense;
  final double income;
  final bool hasOther;
  final double intensity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasRecords = expense > 0 || income > 0 || hasOther;
    final selectedText = Theme.of(context).colorScheme.onPrimary;
    final amountLabel = expense > 0
        ? '¥${expense.toStringAsFixed(2)}'
        : income > 0
            ? '+¥${income.toStringAsFixed(2)}'
            : null;

    Color background;
    if (selected) {
      background = context.appPrimary;
    } else if (!inMonth) {
      background = context.appSurfaceSoft.withValues(alpha: .35);
    } else if (hasRecords) {
      background = Color.lerp(
            context.appSurface,
            context.appPrimarySoft,
            .12 + intensity * .18,
          ) ??
          context.appSurface;
    } else {
      background = context.appSurfaceSoft.withValues(alpha: .22);
    }

    return Semantics(
      button: onTap != null,
      label: '${date.month}月${date.day}日'
          '${expense > 0 ? '，支出${expense.toStringAsFixed(2)}元' : ''}'
          '${income > 0 ? '，收入${income.toStringAsFixed(2)}元' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(11),
            border: selected
                ? null
                : Border.all(
                    color: context.appDivider.withValues(alpha: .22),
                  ),
          ),
          child: Opacity(
            opacity: isFuture
                ? .34
                : inMonth
                    ? 1
                    : .42,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? selectedText : context.appPrimaryText,
                  ),
                ),
                if (amountLabel != null) ...[
                  const SizedBox(height: 3),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          amountLabel,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                selected ? selectedText : context.appPrimaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (hasRecords)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (expense > 0)
                          const _CalendarDot(color: Color(0xFFFF7A45)),
                        if (expense > 0 && (income > 0 || hasOther))
                          const SizedBox(width: 3),
                        if (income > 0)
                          const _CalendarDot(color: Color(0xFF5BAE61)),
                        if (income > 0 && hasOther) const SizedBox(width: 3),
                        if (hasOther)
                          const _CalendarDot(color: Color(0xFF3FA7E8)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarInlineStats extends StatelessWidget {
  const _CalendarInlineStats({
    required this.totalExpense,
    required this.totalIncome,
    required this.balance,
    required this.consumptionDays,
    required this.highestExpenseDay,
    required this.highestExpenseCents,
  });

  final double totalExpense;
  final double totalIncome;
  final double balance;
  final int consumptionDays;
  final int? highestExpenseDay;
  final int? highestExpenseCents;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: context.appSurfaceSoft.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 14,
            children: [
              SizedBox(
                width: itemWidth,
                child: _InlineStat(
                  label: '月支出',
                  value: _formatMoneyLabel(totalExpense),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _InlineStat(
                  label: '月收入',
                  value: _formatMoneyLabel(totalIncome),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _InlineStat(
                  label: '结余',
                  value: _formatMoneyLabel(balance),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _InlineStat(
                  label: '消费天数',
                  value: '$consumptionDays天',
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _InlineStat(
                  label: '最高消费日',
                  value: highestExpenseDay == null
                      ? '暂无'
                      : '$highestExpenseDay日',
                  helper: highestExpenseCents == null
                      ? null
                      : '¥${(highestExpenseCents! / 100).toStringAsFixed(2)}',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.label,
    required this.value,
    this.helper,
  });

  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.appSecondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(
              helper!,
              style: TextStyle(
                fontSize: 11,
                color: context.appSecondaryText,
              ),
            ),
          ],
        ],
      );
}

class _CalendarFooter extends StatelessWidget {
  const _CalendarFooter({
    required this.books,
    required this.selectedBookId,
    required this.onBookTap,
    required this.onToday,
  });

  final List<LedgerBook> books;
  final String? selectedBookId;
  final VoidCallback onBookTap;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompactBookFilter(
              books: books,
              selectedBookId: selectedBookId,
              onTap: onBookTap,
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: onToday,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(86, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                '回到今天',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );

        final textScale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth < 330 || textScale > 1.2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CalendarLegend(),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }

        return Row(
          children: [
            const Expanded(child: _CalendarLegend()),
            actions,
          ],
        );
      },
    );
  }
}

class _CompactBookFilter extends StatelessWidget {
  const _CompactBookFilter({
    required this.books,
    required this.selectedBookId,
    required this.onTap,
  });

  final List<LedgerBook> books;
  final String? selectedBookId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectedBookId == null
        ? null
        : books.where((book) => book.id == selectedBookId).firstOrNull;

    return Material(
      color: context.appSurfaceSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 92),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected == null)
                Icon(
                  Icons.all_inclusive,
                  size: 14,
                  color: context.appPrimary,
                )
              else
                BookColorDot(book: selected, size: 8),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  selected?.name ?? '全部账本',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.expand_more_rounded, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: const [
          _CalendarLegendItem(
            color: Color(0xFFFF7A45),
            label: '支出',
          ),
          _CalendarLegendItem(
            color: Color(0xFF5BAE61),
            label: '收入',
          ),
          _CalendarLegendItem(
            color: Color(0xFF3FA7E8),
            label: '有记账',
          ),
        ],
      );
}

class _CalendarLegendItem extends StatelessWidget {
  const _CalendarLegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CalendarDot(color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.appSecondaryText),
          ),
        ],
      );
}

class _CalendarDot extends StatelessWidget {
  const _CalendarDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.date,
    required this.transactions,
    required this.onAdd,
  });

  final DateTime date;
  final List<TransactionRecord> transactions;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final expense = transactions
        .where(
          (item) =>
              item.isConsumptionExpense && item.netExpenseAmount > 0,
        )
        .fold<double>(0, (sum, item) => sum + item.netExpenseAmount);
    final income = transactions
        .where((item) => item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return AppCard(
      borderRadius: 26,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${date.month}月${date.day}日',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '周${weekdays[date.weekday - 1]}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appSecondaryText,
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Text(
                        '共 ${transactions.length} 笔',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appSecondaryText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '支出 ¥${expense.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '收入 ¥${income.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4F984F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '当天没有流水记录',
                style: TextStyle(color: context.appSecondaryText),
              ),
            )
          else
            ...transactions.asMap().entries.map(
              (entry) => TransactionTile(
                transaction: entry.value,
                showDate: false,
                showDivider: entry.key != transactions.length - 1,
                onTap: () => openTransactionDetail(context, entry.value),
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
              label: const Text('记一笔'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                foregroundColor: context.appPrimary,
                side: BorderSide(color: context.appDivider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyOverviewCard extends StatelessWidget {
  const _MonthlyOverviewCard({
    required this.month,
    required this.totalExpense,
    required this.totalIncome,
    required this.balance,
    required this.consumptionDays,
  });

  final DateTime month;
  final double totalExpense;
  final double totalIncome;
  final double balance;
  final int consumptionDays;

  @override
  Widget build(BuildContext context) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final scale = [
      totalExpense.abs(),
      totalIncome.abs(),
      balance.abs(),
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return AppCard(
      borderRadius: 26,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final range = Text(
                '${month.year}.${month.month.toString().padLeft(2, '0')}.01'
                ' - ${month.month.toString().padLeft(2, '0')}.${lastDay.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11,
                  color: context.appSecondaryText,
                ),
              );
              const title = Text(
                '本月概览',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              );

              if (textScale > 1.2 || constraints.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 4),
                    range,
                  ],
                );
              }

              return Row(
                children: [
                  title,
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: range,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MonthlyMetric(
                  value: _formatMoneyLabel(totalExpense),
                  label: '月支出',
                  progress: totalExpense.abs() / scale,
                  color: const Color(0xFFFF7A45),
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _MonthlyMetric(
                  value: _formatMoneyLabel(totalIncome),
                  label: '月收入',
                  progress: totalIncome.abs() / scale,
                  color: const Color(0xFF5BAE61),
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _MonthlyMetric(
                  value: _formatMoneyLabel(balance),
                  label: '结余',
                  progress: balance.abs() / scale,
                  color: context.appPrimary,
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _MonthlyMetric(
                  value: '$consumptionDays天',
                  label: '有消费',
                  progress: consumptionDays / lastDay,
                  color: context.appPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyMetric extends StatelessWidget {
  const _MonthlyMetric({
    required this.value,
    required this.label,
    required this.progress,
    required this.color,
  });

  final String value;
  final String label;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.appSecondaryText,
              ),
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: context.appSurfaceSoft),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0).toDouble(),
                      child: ColoredBox(color: color),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

String _formatMoneyLabel(double value) {
  final normalized = value.abs() < 0.005 ? 0.0 : value;
  final amount = normalized.abs().toStringAsFixed(2);
  return normalized < 0 ? '-¥$amount' : '¥$amount';
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 54,
        color: context.appDivider,
      );
}
