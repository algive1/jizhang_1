import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../data/receivable_repository.dart';
import '../domain/account_management.dart';

class ReceivableOverviewPage extends ConsumerStatefulWidget {
  const ReceivableOverviewPage({super.key});

  @override
  ConsumerState<ReceivableOverviewPage> createState() =>
      _ReceivableOverviewPageState();
}

class _ReceivableOverviewPageState
    extends ConsumerState<ReceivableOverviewPage> {
  _ReceivableFilter _filter = _ReceivableFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receivablesProvider);
    final monthCollected = ref.watch(receivableMonthCollectedProvider).value ?? 0;
    final items = state.value ?? const <Receivable>[];
    final active = items.where(
      (item) =>
          item.status != ReceivableStatus.completed &&
          item.status != ReceivableStatus.writtenOff,
    );
    final total = active.fold<double>(
      0,
      (sum, item) => sum + item.remainingAmount,
    );
    final pendingCount = active
        .where((item) => item.effectiveStatus != ReceivableStatus.overdue)
        .length;
    final overdueCount = active
        .where((item) => item.effectiveStatus == ReceivableStatus.overdue)
        .length;
    final filtered = items.where(_matches).toList()
      ..sort((a, b) {
        final aDate = a.expectedAt ?? a.createdAt;
        final bDate = b.expectedAt ?? b.createdAt;
        return aDate.compareTo(bDate);
      });

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.appPrimarySoft.withValues(alpha: .55),
            context.appBackground,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/profile/accounts'),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    '应收资金',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('receivable-add'),
                  onPressed: () =>
                      context.push('/profile/accounts/receivables/add'),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppCard(
              borderRadius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '应收资金总额（元）',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥ ${MoneyFormatter.decimal(total)}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: '本月已回收',
                          value: '¥${MoneyFormatter.decimal(monthCollected)}',
                          color: const Color(0xff3D9B5C),
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: '待回收',
                          value: '$pendingCount 笔',
                          color: context.appPrimary,
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: '逾期',
                          value: '$overdueCount 笔',
                          color: overdueCount > 0
                              ? const Color(0xffE05C5C)
                              : context.appPrimaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in const [
                    (_ReceivableFilter.all, '全部'),
                    (_ReceivableFilter.pending, '待回收'),
                    (_ReceivableFilter.partial, '部分回收'),
                    (_ReceivableFilter.completed, '已完成'),
                    (_ReceivableFilter.overdue, '逾期'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: _filter == item.$1,
                        onSelected: (_) => setState(() => _filter = item.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (state.isLoading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.hasError)
              AppCard(
                child: Text(
                  '应收读取失败：${state.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else if (filtered.isEmpty)
              AppCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '暂无符合条件的应收',
                      style: TextStyle(color: context.appSecondaryText),
                    ),
                  ),
                ),
              )
            else
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var index = 0; index < filtered.length; index++) ...[
                      _ReceivableRow(
                        item: filtered[index],
                        onTap: () => context.push(
                          '/profile/accounts/receivables/${filtered[index].id}',
                        ),
                      ),
                      if (index != filtered.length - 1)
                        Divider(height: 1, color: context.appDivider),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => context.push('/profile/accounts/receivables/add'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text('新增应收'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matches(Receivable item) => switch (_filter) {
    _ReceivableFilter.all => true,
    _ReceivableFilter.pending =>
      item.status == ReceivableStatus.pending &&
          item.effectiveStatus != ReceivableStatus.overdue,
    _ReceivableFilter.partial =>
      item.status == ReceivableStatus.partial &&
          item.effectiveStatus != ReceivableStatus.overdue,
    _ReceivableFilter.completed =>
      item.status == ReceivableStatus.completed ||
          item.status == ReceivableStatus.writtenOff,
    _ReceivableFilter.overdue =>
      item.effectiveStatus == ReceivableStatus.overdue,
  };
}

enum _ReceivableFilter { all, pending, partial, completed, overdue }

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 11, color: context.appSecondaryText),
      ),
      const SizedBox(height: 3),
      FittedBox(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    ],
  );
}

class _ReceivableRow extends StatelessWidget {
  const _ReceivableRow({required this.item, required this.onTap});

  final Receivable item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.effectiveStatus == ReceivableStatus.overdue
        ? const Color(0xffE05C5C)
        : item.status == ReceivableStatus.completed
        ? const Color(0xff3D9B5C)
        : item.status == ReceivableStatus.partial
        ? const Color(0xff5B8DEF)
        : const Color(0xffE79B3A);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: _iconColor(item.type).withValues(alpha: .12),
              child: Icon(
                _icon(item.type),
                size: 21,
                color: _iconColor(item.type),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.counterparty,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appSecondaryText,
                    ),
                  ),
                  if (item.expectedAt != null)
                    Text(
                      '预计 ${_date(item.expectedAt!)} 到账',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.appSecondaryText,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${MoneyFormatter.decimal(item.remainingAmount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.visibleStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.appSecondaryText,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(ReceivableType type) => switch (type) {
    ReceivableType.reimbursement => Icons.flight_takeoff_outlined,
    ReceivableType.refund => Icons.shopping_cart_outlined,
    ReceivableType.lend => Icons.person_outline,
    ReceivableType.customer => Icons.receipt_long_outlined,
    ReceivableType.other => Icons.schedule_outlined,
  };

  static Color _iconColor(ReceivableType type) => switch (type) {
    ReceivableType.reimbursement => const Color(0xff5B8DEF),
    ReceivableType.refund => const Color(0xff4BA8B8),
    ReceivableType.lend => const Color(0xff54A85D),
    ReceivableType.customer => const Color(0xff8867D8),
    ReceivableType.other => const Color(0xffE79B3A),
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
