import '../../../core/widgets/app_action_sheet.dart';

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/goal.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/goal_progress_card.dart';
import '../../../core/widgets/money_text.dart';
import '../data/goal_repository.dart';
import 'goal_planning_sheet.dart';

class GoalDetailPage extends ConsumerStatefulWidget {
  const GoalDetailPage({required this.goalId, super.key});

  final String goalId;

  @override
  ConsumerState<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends ConsumerState<GoalDetailPage> {
  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);
    Goal? goal;
    for (final item in goalsAsync.value ?? const <Goal>[]) {
      if (item.id == widget.goalId) {
        goal = item;
        break;
      }
    }
    if (goal == null) {
      return SafeArea(
        child: Center(
          child: goalsAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('目标不存在或已被移除'),
        ),
      );
    }
    final forecasts = ref.watch(goalForecastServiceProvider).allWindows(goal);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _DetailHeader(
                  onBack: () => Navigator.maybePop(context),
                  onEdit: () => _editGoal(goal!),
                  onMilestones: () => _manageMilestones(goal!),
                  onArchive: goal.status == GoalStatus.archived
                      ? null
                      : () => _archiveGoal(goal!),
                  onRestore: goal.status == GoalStatus.archived
                      ? () => _restoreGoal(goal!)
                      : null,
                ),
                const SizedBox(height: 18),
                _GoalIntro(goal: goal),
                const SizedBox(height: 18),
                if (goal.status == GoalStatus.completed) ...[
                  const _CompletedBanner(),
                  const SizedBox(height: 12),
                ],
                GoalProgressCard(goal: goal),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.all(6),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(
                        Icons.savings_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('每月目标预留'),
                      subtitle: Text(
                        goal.monthlyReservation > 0
                            ? '¥${MoneyFormatter.decimal(goal.monthlyReservation)} / 月 · ${goal.status == GoalStatus.active ? "已计入安心可花" : "当前状态不计入"}'
                            : '暂未计入安心可花',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showGoalReservationSheet(context, goal!),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _GoalStats(goal: goal, forecasts: forecasts),
                const SizedBox(height: 16),
                _NextMilestoneCard(goal: goal),
                const SizedBox(height: 16),
                _ForecastCard(forecasts: forecasts),
                const SizedBox(height: 18),
                _RecentContributions(goal: goal),
                const SizedBox(height: 16),
                _GoalActions(
                  onDeposit: () =>
                      _showContribution(goal!, GoalContributionType.deposit),
                  onWithdraw: () =>
                      _showContribution(goal!, GoalContributionType.withdraw),
                  onAdjust: () =>
                      _showContribution(goal!, GoalContributionType.adjustment),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showContribution(Goal goal, GoalContributionType type) async {
    final request = await showModalBottomSheet<(double, String?)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContributionSheet(
        type: type,
        initialAmount: type == GoalContributionType.adjustment
            ? goal.currentAmount
            : null,
      ),
    );
    if (request == null || !mounted) return;
    try {
      final repository = ref.read(goalRepositoryProvider);
      final result = type == GoalContributionType.adjustment
          ? await repository.adjustCurrentAmount(
              goalId: goal.id,
              newAmount: request.$1,
              note: request.$2,
            )
          : await repository.contribute(
              goalId: goal.id,
              amount: request.$1,
              type: type,
              note: request.$2,
            );
      if (result.newlyCompletedMilestoneIds.isNotEmpty ||
          result.goalJustCompleted) {
        await _celebrate(result);
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('操作失败，请检查金额')));
    }
  }

  Future<void> _celebrate(GoalContributionResult result) async {
    unawaited(HapticFeedback.lightImpact());
    if (!mounted) return;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1050), () {
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }),
    );
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      pageBuilder: (_, _, _) => _CelebrationOverlay(
        goalCompleted: result.goalJustCompleted,
        milestoneCount: result.newlyCompletedMilestoneIds.length,
      ),
    );
    await ref
        .read(goalRepositoryProvider)
        .markCelebrationsShown(
          goalId: result.goal.id,
          milestoneIds: result.newlyCompletedMilestoneIds,
          goalCompletion: result.goalJustCompleted,
        );
  }

  Future<void> _editGoal(Goal goal) => editGoal(context, ref, goal);

  Future<void> _archiveGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档这个目标？'),
        content: const Text(
          '归档后目标会从默认列表和首页移除，不再计入今日可用的目标预留；目标金额、阶段节点和存入记录都会保留，可在“已归档”中恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(goalRepositoryProvider).archive(goal.id);
      if (mounted) context.go('/goals');
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('目标归档失败，请稍后重试')));
    }
  }

  Future<void> _restoreGoal(Goal goal) async {
    try {
      await ref.read(goalRepositoryProvider).restore(goal.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('目标已恢复')));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('目标恢复失败，请稍后重试')));
    }
  }

  Future<void> _manageMilestones(Goal goal) async {
    final result = await showDialog<List<double>>(
      context: context,
      builder: (_) => _MilestoneListDialog(
        milestones: goal.milestones
            .where((item) => item.amount < goal.targetAmount)
            .map((item) => item.amount)
            .toList(growable: false),
        targetAmount: goal.targetAmount,
      ),
    );
    if (result != null) {
      await ref.read(goalRepositoryProvider).replaceMilestones(goal.id, result);
    }
  }
}

class _ContributionSheet extends StatefulWidget {
  const _ContributionSheet({required this.type, this.initialAmount});

  final GoalContributionType type;
  final double? initialAmount;

  @override
  State<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends State<_ContributionSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.initialAmount?.toStringAsFixed(2) ?? '',
  );
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.type) {
      GoalContributionType.deposit => '向目标存入',
      GoalContributionType.withdraw => '从目标取出',
      GoalContributionType.adjustment => '调整当前金额',
    };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Material(
          color: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    color: AppColors.divider,
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    prefixText: '¥ ',
                    labelText: widget.type == GoalContributionType.adjustment
                        ? '调整后的总金额'
                        : '金额',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final amount = double.tryParse(_amountController.text);
                      if (amount == null || amount < 0) return;
                      Navigator.pop(context, (
                        amount,
                        _noteController.text.trim().isEmpty
                            ? null
                            : _noteController.text.trim(),
                      ));
                    },
                    child: const Text('确认'),
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

class _GoalEditDialog extends StatefulWidget {
  const _GoalEditDialog({required this.name, required this.targetAmount});

  final String name;
  final double targetAmount;

  @override
  State<_GoalEditDialog> createState() => _GoalEditDialogState();
}

class _GoalEditDialogState extends State<_GoalEditDialog> {
  late final _nameController = TextEditingController(text: widget.name);
  late final _targetController = TextEditingController(
    text: widget.targetAmount.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('编辑目标'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '目标名称'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _targetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '目标金额',
            prefixText: '¥ ',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final amount = double.tryParse(_targetController.text);
          final name = _nameController.text.trim();
          if (name.isEmpty || amount == null || amount <= 0) return;
          Navigator.pop(context, (name, amount));
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _MilestoneListDialog extends StatefulWidget {
  const _MilestoneListDialog({
    required this.milestones,
    required this.targetAmount,
  });

  final List<double> milestones;
  final double targetAmount;

  @override
  State<_MilestoneListDialog> createState() => _MilestoneListDialogState();
}

class _MilestoneListDialogState extends State<_MilestoneListDialog> {
  late final _controller = TextEditingController(
    text: widget.milestones
        .map((amount) => amount.toStringAsFixed(2))
        .join(', '),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('调整阶段节点'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('用逗号分隔中间节点；最终目标节点会始终保留。'),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '20000, 40000, 60000'),
        ),
        const SizedBox(height: 8),
        Text(
          '最终节点 ¥${widget.targetAmount.toStringAsFixed(2)}（不可删除）',
          style: const TextStyle(color: AppColors.primaryDark),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final amounts =
              _controller.text
                  .split(RegExp(r'[,，]'))
                  .map((item) => double.tryParse(item.trim()))
                  .whereType<double>()
                  .where((amount) => amount > 0 && amount < widget.targetAmount)
                  .toSet()
                  .toList()
                ..sort()
                ..add(widget.targetAmount);
          Navigator.pop(context, amounts);
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.onBack,
    required this.onEdit,
    required this.onMilestones,
    required this.onArchive,
    required this.onRestore,
  });

  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onMilestones;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const Expanded(
          child: Text(
            '目标详情',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        AppActionMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'milestones':
                onMilestones();
              case 'archive':
                onArchive?.call();
              case 'restore':
                onRestore?.call();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑目标')),
            const PopupMenuItem(value: 'milestones', child: Text('调整节点')),
            if (onArchive != null)
              const PopupMenuItem(value: 'archive', child: Text('归档目标')),
            if (onRestore != null)
              const PopupMenuItem(value: 'restore', child: Text('恢复目标')),
          ],
        ),
      ],
    );
  }
}

class _GoalIntro extends StatelessWidget {
  const _GoalIntro({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 92,
          height: 92,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Color(0xFFF0EBDD),
            shape: BoxShape.circle,
          ),
          child: goal.coverPath != null && File(goal.coverPath!).existsSync()
              ? Image.file(File(goal.coverPath!), fit: BoxFit.cover)
              : goal.goalType == GoalType.car
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(AppAssets.goalCar, fit: BoxFit.contain),
                )
              : Icon(
                  _goalIcon(goal.goalType),
                  color: AppColors.primaryDark,
                  size: 42,
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              Text(
                goal.goalType.label,
                style: const TextStyle(color: AppColors.primaryDark),
              ),
              if (goal.description != null) ...[
                const SizedBox(height: 5),
                Text(
                  goal.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalStats extends StatelessWidget {
  const _GoalStats({required this.goal, required this.forecasts});

  final Goal goal;
  final List<GoalForecast> forecasts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthDeposits = goal.contributions
        .where(
          (item) =>
              item.type == GoalContributionType.deposit &&
              item.createdAt.year == now.year &&
              item.createdAt.month == now.month,
        )
        .fold<double>(0, (sum, item) => sum + item.amount);
    final forecast = forecasts.firstWhere(
      (item) => item.estimatedCompletionDate != null,
      orElse: () => forecasts.first,
    );
    final forecastLabel = forecast.estimatedCompletionDate == null
        ? '待积累数据'
        : '${forecast.estimatedCompletionDate!.year}年'
              '${forecast.estimatedCompletionDate!.month}月';
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_month_outlined,
            label: '目标日期',
            value: '${goal.targetDate.year}年${goal.targetDate.month}月',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.schedule,
            label: '预计达成',
            value: forecastLabel,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.account_balance_wallet_outlined,
            label: '本月已存入',
            value: '¥${MoneyFormatter.whole(monthDeposits)}',
            emphasize: true,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(9, 13, 9, 13),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 19),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: emphasize ? AppColors.primary : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextMilestoneCard extends StatelessWidget {
  const _NextMilestoneCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final next = goal.milestones
        .where((item) => item.amount > goal.currentAmount)
        .firstOrNull;
    return AppCard(
      color: const Color(0xFFF2F5E4),
      child: Row(
        children: [
          Icon(
            next == null ? Icons.celebration_outlined : Icons.spa_outlined,
            size: 40,
            color: AppColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next == null
                      ? '目标已经完成！'
                      : '下一站 ¥${MoneyFormatter.whole(next.amount)}',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next == null
                      ? '成果会一直保留在已完成目标中。'
                      : '还差 ¥${MoneyFormatter.whole(next.amount - goal.currentAmount)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecasts});

  final List<GoalForecast> forecasts;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('存入速度预测', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          const Text(
            '仅根据所选窗口内已发生的存入和取出记录计算；初始金额、调整和未来日期不会影响速度。',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: forecasts.map((forecast) {
              final date = forecast.estimatedCompletionDate;
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '${forecast.windowDays}天',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      child: Text(
                        date == null ? '数据不足' : '${date.year}.${date.month}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RecentContributions extends StatelessWidget {
  const _RecentContributions({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final contributions = goal.contributions.take(5).toList();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 7),
      child: Column(
        children: [
          Row(
            children: [
              Text('最近存入', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text(
                '${goal.contributions.length} 笔',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (contributions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Text('还没有资金操作'),
            )
          else
            ...contributions.map((contribution) {
              final positive = switch (contribution.type) {
                GoalContributionType.deposit => true,
                GoalContributionType.withdraw => false,
                GoalContributionType.adjustment => contribution.amount >= 0,
              };
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(
                    positive ? Icons.south_west : Icons.north_east,
                    color: AppColors.primaryDark,
                  ),
                ),
                title: Text(switch (contribution.type) {
                  GoalContributionType.deposit => '存入',
                  GoalContributionType.withdraw => '取出',
                  GoalContributionType.adjustment => '金额调整',
                }),
                subtitle: Text(
                  '${contribution.contributorUserId == null
                      ? ''
                      : contribution.contributorUserId == 'user-local'
                      ? '你的贡献 · '
                      : '家庭成员贡献 · '}'
                  '${contribution.createdAt.month}-${contribution.createdAt.day} '
                  '${contribution.createdAt.hour.toString().padLeft(2, '0')}:'
                  '${contribution.createdAt.minute.toString().padLeft(2, '0')}',
                ),
                trailing: MoneyText(
                  contribution.amount.abs(),
                  positive: positive,
                  showSign: true,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _GoalActions extends StatelessWidget {
  const _GoalActions({
    required this.onDeposit,
    required this.onWithdraw,
    required this.onAdjust,
  });

  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(icon: Icons.add, title: '存入', onTap: onDeposit),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.remove,
            title: '取出',
            onTap: onWithdraw,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(icon: Icons.tune, title: '调整', onTap: onAdjust),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      label: Text(title),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      color: Color(0xFFE9EFD8),
      child: Row(
        children: [
          Text('🎉', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '目标完成！这份成果会继续为你保留。',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationOverlay extends StatefulWidget {
  const _CelebrationOverlay({
    required this.goalCompleted,
    required this.milestoneCount,
  });

  final bool goalCompleted;
  final int milestoneCount;

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: .7, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Color(0x4473963B), blurRadius: 32),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(width: 100, height: 100),
                      ...List.generate(8, (index) {
                        final angle = index * .785;
                        return Transform.translate(
                          offset: Offset(
                            43 * math.cos(angle),
                            43 * math.sin(angle),
                          ),
                          child: const CircleAvatar(
                            radius: 3,
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }),
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(
                          widget.goalCompleted
                              ? Icons.celebration
                              : Icons.check,
                          size: 38,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.goalCompleted
                        ? '目标完成 🎉'
                        : '解锁 ${widget.milestoneCount} 个新节点',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _goalIcon(GoalType type) => switch (type) {
  GoalType.car => Icons.directions_car_filled,
  GoalType.travel => Icons.flight_takeoff,
  GoalType.homeDownPayment => Icons.home_outlined,
  GoalType.emergencyFund => Icons.health_and_safety_outlined,
  GoalType.wedding => Icons.favorite_outline,
  GoalType.renovation => Icons.handyman_outlined,
  GoalType.digitalProduct => Icons.devices_outlined,
  GoalType.education => Icons.school_outlined,
  GoalType.childrenFamily => Icons.child_care_outlined,
  GoalType.healthcare => Icons.medical_services_outlined,
  GoalType.retirement => Icons.beach_access_outlined,
  GoalType.debtRepayment => Icons.receipt_long_outlined,
  GoalType.business => Icons.storefront_outlined,
  GoalType.caregiving => Icons.volunteer_activism_outlined,
  GoalType.giftCharity => Icons.redeem_outlined,
  GoalType.majorPurchase => Icons.shopping_bag_outlined,
  GoalType.custom => Icons.flag_outlined,
};

Future<void> editGoal(BuildContext context, WidgetRef ref, Goal goal) async {
  final result = await showDialog<(String, double)>(
    context: context,
    builder: (_) =>
        _GoalEditDialog(name: goal.name, targetAmount: goal.targetAmount),
  );
  if (result == null || !context.mounted) return;
  final updated = Goal(
    id: goal.id,
    name: result.$1,
    goalType: goal.goalType,
    icon: goal.icon,
    targetAmount: result.$2,
    currentAmount: goal.currentAmount,
    targetDate: goal.targetDate,
    status: goal.status,
    createdAt: goal.createdAt,
    updatedAt: DateTime.now(),
    milestones: goal.milestones,
    description: goal.description,
    coverPath: goal.coverPath,
    completionCelebrationShown: goal.completionCelebrationShown,
    contributions: goal.contributions,
    bookId: goal.bookId,
    sortOrder: goal.sortOrder,
    monthlyReservation: goal.monthlyReservation,
    version: goal.version,
    createdBy: goal.createdBy,
    updatedBy: goal.updatedBy,
  );
  final milestoneAmounts =
      goal.milestones
          .map((item) => item.amount)
          .where((amount) => amount < result.$2)
          .toList()
        ..add(result.$2);
  await ref
      .read(goalRepositoryProvider)
      .update(updated, milestoneAmounts: milestoneAmounts);
}
