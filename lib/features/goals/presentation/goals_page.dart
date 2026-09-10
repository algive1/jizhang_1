import '../../../core/utils/entity_id.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/goal.dart';
import '../../../core/models/placement.dart';
import '../../../core/widgets/goal_progress_card.dart';
import '../../books/data/book_repository.dart';
import '../data/goal_repository.dart';
import '../../ads/presentation/placement_slot.dart';
import 'goal_creation_sheet.dart';
import 'goal_planning_sheet.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final goals = goalsAsync.value ?? const <Goal>[];
    final active = goals
        .where((goal) => goal.status == GoalStatus.active)
        .toList();
    final paused = goals
        .where((goal) => goal.status == GoalStatus.paused)
        .toList();
    final completed = goals
        .where((goal) => goal.status == GoalStatus.completed)
        .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '目标',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _createGoal(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('新建目标'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const PlacementSlot(surface: PlacementSurface.goalPromo),
          if (goalsAsync.isLoading && goals.isEmpty)
            const Center(child: CircularProgressIndicator())
          else ...[
            Row(
              children: [
                Expanded(
                  child: _SectionTitle(title: '进行中', count: active.length),
                ),
                if (active.length > 1)
                  TextButton.icon(
                    onPressed: () => showGoalOrderSheet(context, active),
                    icon: const Icon(Icons.sort),
                    label: const Text('排序'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (active.isEmpty)
              _EmptyGoal(onCreate: () => _createGoal(context, ref))
            else
              ...active.map((goal) => _GoalItem(goal: goal)),
            if (paused.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionTitle(title: '已暂停', count: paused.length),
              const SizedBox(height: 10),
              ...paused.map((goal) => _GoalItem(goal: goal)),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionTitle(title: '已完成', count: completed.length),
              const SizedBox(height: 10),
              ...completed.map((goal) => _GoalItem(goal: goal)),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _createGoal(BuildContext context, WidgetRef ref) async {
    final draft = await showGoalCreationSheet(context);
    if (draft == null || !context.mounted) return;
    final now = DateTime.now();
    try {
      final goal = await ref
          .read(goalRepositoryProvider)
          .create(
            goal: Goal(
              id: 'goal-${newEntityId()}',
              name: draft.name,
              goalType: draft.type,
              icon: draft.type.name,
              targetAmount: draft.targetAmount,
              currentAmount: draft.currentAmount,
              targetDate: draft.targetDate,
              status: GoalStatus.active,
              createdAt: now,
              milestones: const [],
              description: draft.description,
              coverPath: draft.coverPath,
              bookId: ref.read(activeBookIdProvider),
            ),
            milestoneAmounts: draft.milestones,
            initialAmount: draft.currentAmount,
          );
      if (context.mounted) context.go('/goals/${goal.id}');
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('目标创建失败，请检查金额和节点')));
    }
  }
}

class _GoalItem extends StatelessWidget {
  const _GoalItem({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GoalProgressCard(
        goal: goal,
        onTap: () => context.go('/goals/${goal.id}'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 8),
        Text('$count', style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _EmptyGoal extends StatelessWidget {
  const _EmptyGoal({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.flag_outlined, size: 42, color: AppColors.primary),
          const SizedBox(height: 8),
          const Text('从一个真正在意的目标开始'),
          TextButton(onPressed: onCreate, child: const Text('创建第一个目标')),
        ],
      ),
    );
  }
}
