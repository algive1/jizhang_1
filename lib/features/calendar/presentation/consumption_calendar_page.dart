import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/models/family.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/book_color_dot.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../../books/data/book_repository.dart';
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
  Widget build(BuildContext context) {
    final all =
        ref.watch(allTransactionsProvider).value ?? const <TransactionRecord>[];
    final books = ref.watch(booksProvider).value ?? const <LedgerBook>[];
    final filtered = _bookFilterId == null
        ? all
        : all.where((item) => item.bookId == _bookFilterId).toList();
    final monthTransactions = filtered.where((item) {
      final date = item.occurredAt;
      return _isConsumption(item) &&
          date.year == _month.year &&
          date.month == _month.month &&
          !date.isAfter(_today);
    }).toList();
    final daily = <int, double>{};
    final dailyCents = <int, int>{};
    for (final item in monthTransactions) {
      final cents = (item.netExpenseAmount * 100).round();
      daily.update(
        item.occurredAt.day,
        (value) => value + item.netExpenseAmount,
        ifAbsent: () => item.netExpenseAmount,
      );
      dailyCents.update(
        item.occurredAt.day,
        (value) => value + cents,
        ifAbsent: () => cents,
      );
    }
    final selected = _selectedDay == null
        ? const <TransactionRecord>[]
        : monthTransactions
              .where((item) => item.occurredAt.day == _selectedDay)
              .toList();
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
    final total = monthTransactions.fold<double>(
      0,
      (sum, item) => sum + item.netExpenseAmount,
    );
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final elapsedDays = _isCurrentMonth ? _today.day : daysInMonth;
    final dailyAverage = elapsedDays == 0 ? 0.0 : total / elapsedDays;
    final highest = dailyCents.entries.isEmpty
        ? null
        : dailyCents.entries.reduce((a, b) {
            if (a.value != b.value) return a.value > b.value ? a : b;
            // Stable tie-breaking keeps the displayed date predictable.
            return a.key < b.key ? a : b;
          });

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回首页',
              ),
              Expanded(
                child: Text(
                  '消费日历',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
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
                                color: AppColors.textSecondary,
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
                  maxDaily: maxDaily,
                  selectedDay: _selectedDay,
                  onDayTap: (day) => setState(() => _selectedDay = day),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _CalendarBookFilter(
            books: books,
            selectedBookId: _bookFilterId,
            onTap: _openBookFilter,
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
            color: AppColors.primarySoft,
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
                      child: _CalendarStat(label: '日均支出', value: dailyAverage),
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
            Text(
              '${_month.month}月$_selectedDay日',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          if (_selectedDay != null) const SizedBox(height: 8),
          if (_selectedDay != null && selected.isEmpty)
            const AppCard(
              child: Text(
                '当天没有消费记录',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else if (_selectedDay != null)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: selected
                    .asMap()
                    .entries
                    .map(
                      (entry) => TransactionTile(
                        transaction: entry.value,
                        showDate: false,
                        showDivider: entry.key != selected.length - 1,
                        onTap: () =>
                            openTransactionDetail(context, entry.value),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  bool get _isCurrentMonth =>
      _month.year == _today.year && _month.month == _today.month;

  bool _isConsumption(TransactionRecord item) =>
      item.deletedAt == null &&
      (item.type == TransactionType.expense ||
          item.type == TransactionType.lend ||
          item.type == TransactionType.assetPurchase) &&
      item.netExpenseAmount > 0;

  void _moveMonth(int delta) =>
      _setMonth(DateTime(_month.year, _month.month + delta));

  void _setMonth(DateTime month) => setState(() {
    _month = DateTime(month.year, month.month);
    _selectedDay = null;
  });

  Future<void> _openBookFilter() async {
    final books = ref.read(booksProvider).value ?? const <LedgerBook>[];
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Text(
              '筛选账本',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.all_inclusive,
                color: AppColors.primary,
              ),
              title: const Text('全部账本'),
              trailing: _bookFilterId == null
                  ? const Icon(Icons.check, color: AppColors.primary)
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
                    ? const Icon(Icons.check, color: AppColors.primary)
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
      _selectedDay = null;
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
        side: BorderSide(color: AppColors.divider),
        backgroundColor: AppColors.surface,
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.daily,
    required this.maxDaily,
    required this.selectedDay,
    required this.onDayTap,
  });

  final DateTime month;
  final Map<int, double> daily;
  final double maxDaily;
  final int? selectedDay;
  final ValueChanged<int> onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstOffset = DateTime(month.year, month.month, 1).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = <Widget>[];
    for (var index = 0; index < firstOffset; index++)
      cells.add(const SizedBox());
    for (var day = 1; day <= days; day++) {
      final amount = daily[day] ?? 0;
      final intensity = maxDaily == 0
          ? 0.0
          : (amount / maxDaily).clamp(0.0, 1.0);
      cells.add(
        GestureDetector(
          onTap: () => onDayTap(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: selectedDay == day
                  ? AppColors.primary.withValues(alpha: .22)
                  : amount == 0
                  ? Colors.transparent
                  : Color.lerp(
                      AppColors.surface,
                      AppColors.primarySoft,
                      .25 + intensity * .45,
                    ),
              borderRadius: BorderRadius.circular(12),
              border: selectedDay == day
                  ? Border.all(color: AppColors.primary)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (amount > 0) ...[
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '¥${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    while (cells.length % 7 != 0) cells.add(const SizedBox());
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
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 4),
      suffix != null
          ? Text(
              suffix!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            )
          : integer
          ? Text(
              '${value.round()}天',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            )
          : MoneyText(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
    ],
  );
}
