import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/models/family.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/book_color_dot.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../../books/data/book_repository.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../../../core/models/book.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/transaction_actions.dart';

class ConsumptionCalendarPage extends ConsumerStatefulWidget {
  const ConsumptionCalendarPage({super.key});

  @override
  ConsumerState<ConsumptionCalendarPage> createState() =>
      _ConsumptionCalendarPageState();
}

class _ConsumptionCalendarPageState
    extends ConsumerState<ConsumptionCalendarPage> {
  final _today = DateTime.now();
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;
  String? _bookFilterId;

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
    final books = ref.watch(booksProvider).value ?? const <LedgerBook>[];
    final filtered = _bookFilterId == null
        ? all
        : all.where((item) => item.bookId == _bookFilterId).toList();
    final monthTransactions = filtered.where((item) {
      final date = item.occurredAt;
      return item.deletedAt == null &&
          date.year == _month.year &&
          date.month == _month.month &&
          !date.isAfter(_today);
    }).toList();
    final daily = <int, double>{};
    final dailyIncome = <int, double>{};
    final dailyCents = <int, int>{};
    for (final item in monthTransactions) {
      if (_isConsumption(item)) {
        final cents = (item.netExpenseAmount * 100).round();
        daily.update(item.occurredAt.day, (v) => v + item.netExpenseAmount,
            ifAbsent: () => item.netExpenseAmount);
        dailyCents.update(item.occurredAt.day, (v) => v + cents,
            ifAbsent: () => cents);
      } else if (item.isIncome) {
        dailyIncome.update(item.occurredAt.day, (v) => v + item.amount,
            ifAbsent: () => item.amount);
      }
    }
    final selected = _selectedDay == null
        ? const <TransactionRecord>[]
        : monthTransactions
              .where((item) => item.occurredAt.day == _selectedDay)
              .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final maxDaily = daily.values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final recordMonths =
        filtered
            .where(
              (item) =>
                  _isConsumption(item) && !item.occurredAt.isAfter(_today),
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
    final total = monthTransactions
        .where(_isConsumption)
        .fold<double>(0, (sum, item) => sum + item.netExpenseAmount);
    final totalIncome = monthTransactions
        .where((item) => item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final balance = totalIncome - total;
    final highest = dailyCents.entries.isEmpty
        ? null
        : dailyCents.entries.reduce((a, b) {
            if (a.value != b.value) return a.value > b.value ? a : b;
            // Stable tie-breaking keeps the displayed date predictable.
            return a.key < b.key ? a : b;
          });

    return Scaffold(
      backgroundColor: context.appBackground,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _CalendarHeroHeader(
            onBack: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _month.year == 2000
                          ? null
                          : () => _moveMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '上个月',
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${_month.year}年${_month.month}月',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isCurrentMonth ? null : () => _moveMonth(1),
                      icon: const Icon(Icons.chevron_right),
                      tooltip: '下个月',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: const ['一', '二', '三', '四', '五', '六', '日']
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appSecondaryText,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 6),
                _CalendarGrid(
                  month: _month,
                  daily: daily,
                  dailyIncome: dailyIncome,
                  maxDaily: maxDaily,
                  selectedDay: _selectedDay,
                  today: _today,
                  onDateTap: (date) => setState(() {
                    _month = DateTime(date.year, date.month);
                    _selectedDay = date.day;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _CalendarLegend(),
              const Spacer(),
              _CalendarBookFilter(
                books: books,
                selectedBookId: _bookFilterId,
                onTap: _openBookFilter,
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _goToday,
                child: const Text('回到今天'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (previousRecorded != null)
                TextButton.icon(
                  onPressed: () => _setMonth(previousRecorded),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('上个有记录月份'),
                ),
              const Spacer(),
              if (nextRecorded != null)
                TextButton.icon(
                  onPressed: () => _setMonth(nextRecorded),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('下个有记录月份'),
                ),
            ],
          ),
          AppCard(
            color: context.appPrimarySoft,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 430 ? 2 : 4;
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _CalendarStat(label: '本月支出', value: total),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _CalendarStat(label: '月收入', value: totalIncome),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _CalendarStat(label: '结余', value: balance),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _CalendarStat(
                        label: '消费天数',
                        value: dailyCents.length.toDouble(),
                        integer: true,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _CalendarStat(
                        label: '最高消费日',
                        value: highest?.value.toDouble() ?? 0,
                        suffix: highest == null ? '暂无' : '${highest.key}日',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedDay != null)
            _SelectedDayHeader(
              date: DateTime(_month.year, _month.month, _selectedDay!),
              transactions: selected,
            ),
          if (_selectedDay != null) const SizedBox(height: 8),
          if (_selectedDay != null)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  if (selected.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('当天没有流水记录', style: TextStyle(color: context.appSecondaryText)),
                    )
                  else
                    ...selected.asMap().entries.map(
                      (entry) => TransactionTile(
                        transaction: entry.value,
                        showDate: false,
                        showDivider: entry.key != selected.length - 1,
                        onTap: () => openTransactionDetail(context, entry.value),
                      ),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addForSelectedDate,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('记一笔'),
                    ),
                  ),
                ],
              ),
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

  /// The calendar is a consumption view. Lending and asset conversions move
  /// money without spending it, so they stay off the daily consumption totals.
  bool _isConsumption(TransactionRecord item) =>
      item.deletedAt == null &&
      item.isConsumptionExpense &&
      item.netExpenseAmount > 0;

  void _moveMonth(int delta) =>
      _setMonth(DateTime(_month.year, _month.month + delta));

  void _setMonth(DateTime month) => setState(() {
    _month = DateTime(month.year, month.month);
    _selectedDay = _isCurrentMonth ? _today.day : null;
  });

  void _goToday() => setState(() {
    _month = DateTime(_today.year, _today.month);
    _selectedDay = _today.day;
  });

  Future<void> _addForSelectedDate() async {
    final day = _selectedDay ?? (_isCurrentMonth ? _today.day : 1);
    final selectedDate = DateTime(_month.year, _month.month, day);
    final initialBookId = _bookFilterId ?? ref.read(activeBookIdProvider);
    await showQuickAddSheet(
      context,
      initialOccurredAt: selectedDate,
      initialBookId: initialBookId,
    );
  }

  Future<void> _openBookFilter() async {
    final books = ref.read(booksProvider).value ?? const <LedgerBook>[];
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
              leading: const Icon(
                Icons.all_inclusive,
                color: context.appPrimary,
              ),
              title: const Text('全部账本'),
              subtitle: const Text('汇总当前账号可访问的账本'),
              trailing: _bookFilterId == null
                  ? const Icon(Icons.check, color: context.appPrimary)
                  : null,
              onTap: () => Navigator.pop(context, _allBooksFilterValue),
            ),
            ...books.map(
              (book) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: BookColorDot(book: book, size: 12),
                title: Text(book.name),
                subtitle: Text(book.type.label),
                trailing: _bookFilterId == book.id
                    ? const Icon(Icons.check, color: context.appPrimary)
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

class _CalendarBookFilter extends StatelessWidget {
  const _CalendarBookFilter({
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
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: selected == null
            ? const Icon(Icons.all_inclusive, size: 17)
            : BookColorDot(book: selected, size: 10),
        label: Text(selected?.name ?? '全部账本'),
        onPressed: onTap,
        side: BorderSide(color: context.appDivider),
        backgroundColor: context.appSurface,
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.daily,
    required this.dailyIncome,
    required this.maxDaily,
    required this.selectedDay,
    required this.today,
    required this.onDateTap,
  });

  final DateTime month;
  final Map<int, double> daily;
  final Map<int, double> dailyIncome;
  final double maxDaily;
  final int? selectedDay;
  final DateTime today;
  final ValueChanged<DateTime> onDateTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final selectedDate = selectedDay == null
        ? null
        : DateTime(month.year, month.month, selectedDay!);
    final cells = List<Widget>.generate(42, (index) {
      final date = gridStart.add(Duration(days: index));
      final inMonth = date.year == month.year && date.month == month.month;
      final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
      final amount = inMonth ? (daily[date.day] ?? 0) : 0.0;
      final income = inMonth ? (dailyIncome[date.day] ?? 0) : 0.0;
      final intensity = maxDaily == 0 ? 0.0 : (amount / maxDaily).clamp(0.0, 1.0);
      final selected = selectedDate != null && DateUtils.isSameDay(date, selectedDate);
      return GestureDetector(
        onTap: isFuture ? null : () => onDateTap(date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected
                ? context.appPrimary.withValues(alpha: .22)
                : !inMonth
                ? context.appBackground.withValues(alpha: .55)
                : amount == 0
                ? Colors.transparent
                : Color.lerp(context.appSurface, context.appPrimarySoft, .25 + intensity * .45),
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: context.appPrimary) : null,
          ),
          child: Opacity(
            opacity: inMonth ? 1 : .38,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${date.day}', style: TextStyle(fontWeight: FontWeight.w600, color: isFuture ? context.appSecondaryText : null)),
                if (amount > 0 || income > 0) ...[
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amount > 0 ? '¥${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}' : '+¥${income.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 10, color: amount > 0 ? context.appPrimary : context.appPrimary),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (amount > 0) const _CalendarDot(color: Color(0xFFFF7A45)),
                    if (amount > 0 && income > 0) const SizedBox(width: 3),
                    if (income > 0) const _CalendarDot(color: Color(0xFF5BAE61)),
                  ]),
                ],
              ],
            ),
          ),
        ),
      );
    });
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: .65,
      children: cells,
    );
  }
}

class _CalendarStat extends StatelessWidget {
  const _CalendarStat({
    required this.label,
    required this.value,
    this.integer = false,
    this.suffix,
  });

  final String label;
  final double value;
  final bool integer;
  final String? suffix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: context.appSecondaryText),
      ),
      const SizedBox(height: 4),
      suffix != null
          ? Text(
              suffix!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appPrimary,
              ),
            )
          : integer
          ? Text(
              '${value.round()}天',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.appPrimary,
              ),
            )
          : MoneyText(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appPrimary,
              ),
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


class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _CalendarDot(color: Color(0xFFFF7A45)),
      SizedBox(width: 5),
      Text('支出', style: TextStyle(fontSize: 12, color: context.appSecondaryText)),
      SizedBox(width: 10),
      _CalendarDot(color: Color(0xFF5BAE61)),
      SizedBox(width: 5),
      Text('收入', style: TextStyle(fontSize: 12, color: context.appSecondaryText)),
    ],
  );
}


class _SelectedDayHeader extends StatelessWidget {
  const _SelectedDayHeader({required this.date, required this.transactions});
  final DateTime date;
  final List<TransactionRecord> transactions;
  @override
  Widget build(BuildContext context) {
    final expense = transactions.where((t) => t.isConsumptionExpense).fold<double>(0, (s, t) => s + t.netExpenseAmount);
    final income = transactions.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    const weekdays = ['一','二','三','四','五','六','日'];
    return Row(children: [
      Text('${date.month}月${date.day}日', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(width: 8),
      Text('周${weekdays[date.weekday - 1]}', style: const TextStyle(color: context.appSecondaryText)),
      const Spacer(),
      Text('共 ${transactions.length} 笔', style: const TextStyle(color: context.appSecondaryText)),
      const SizedBox(width: 12),
      Text('支出 ¥${expense.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w600)),
      const SizedBox(width: 10),
      Text('收入 ¥${income.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF4F984F), fontWeight: FontWeight.w600)),
    ]);
  }
}


class _CalendarHeroHeader extends StatelessWidget {
  const _CalendarHeroHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 248,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            '微信图片_20260919140237_156_240.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x18F4F6EC), Color(0xFFF4F6EC)],
                stops: [0, .72, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
                child: Material(
                  color: Colors.white70,
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    tooltip: '返回',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
