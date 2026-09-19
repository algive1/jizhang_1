import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/goal.dart';
import '../data/goal_repository.dart';

Future<void> showGoalReservationSheet(BuildContext context, Goal goal) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReservationSheet(goal: goal),
  );
}

class _ReservationSheet extends ConsumerStatefulWidget {
  const _ReservationSheet({required this.goal});
  final Goal goal;
  @override
  ConsumerState<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends ConsumerState<_ReservationSheet> {
  late final _amount = TextEditingController(
    text: widget.goal.monthlyReservation.toStringAsFixed(2),
  );
  late bool _enabled = widget.goal.monthlyReservation > 0;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('每月目标预留', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.goal.name),
            const SizedBox(height: 8),
            const Text(
              '开启后，每月从支出预算中预留这笔额度，降低今日安心可花。仅用于预算计算，不扣款、不转移账户资金。目标完成或暂停后不再计入。',
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('计入安心可花'),
              value: _enabled,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            if (_enabled)
              TextField(
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '每月预留金额',
                  prefixText: '¥ ',
                  errorText: _error,
                ),
              ),
            if (!_enabled && _error != null) Text(_error!),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存设置'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = _enabled ? MoneyFormatter.parseInput(_amount.text) : 0.0;
    if (amount == null || (_enabled && amount <= 0)) {
      setState(() => _error = '请输入大于 0 的金额，最多两位小数');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(goalRepositoryProvider)
          .setMonthlyReservation(widget.goal.id, amount);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }
}

Future<void> showGoalOrderSheet(BuildContext context, List<Goal> goals) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GoalOrderSheet(goals: goals),
  );
}

class _GoalOrderSheet extends ConsumerStatefulWidget {
  const _GoalOrderSheet({required this.goals});
  final List<Goal> goals;
  @override
  ConsumerState<_GoalOrderSheet> createState() => _GoalOrderSheetState();
}

class _GoalOrderSheetState extends ConsumerState<_GoalOrderSheet> {
  late final _goals = [...widget.goals];
  bool _saving = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              Text('目标排序', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('拖动调整顺序，首页展示排在最前的进行中目标'),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: _goals.length,
                  onReorderItem: (oldIndex, newIndex) {
                    if (_saving) return;
                    setState(() {
                      _goals.insert(newIndex, _goals.removeAt(oldIndex));
                    });
                  },
                  itemBuilder: (_, index) => ListTile(
                    key: ValueKey(_goals[index].id),
                    title: Text(
                      _goals[index].name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: Text('${index + 1}'),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      enabled: !_saving,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null) Text(_error!),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await ref
                              .read(goalRepositoryProvider)
                              .reorder(_goals.map((g) => g.id).toList());
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              _saving = false;
                              _error = '排序保存失败，请重试';
                            });
                          }
                        }
                      },
                child: Text(_saving ? '保存中…' : '保存排序'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
