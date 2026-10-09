import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/budget.dart';
import '../../../core/models/goal.dart';
import '../../../core/widgets/category_icon.dart';
import '../data/budget_preferences_repository.dart';
import '../domain/budget_period.dart';
import 'budget_visuals.dart';

class CategoryBudgetSection extends StatelessWidget {
  const CategoryBudgetSection({
    required this.rows,
    required this.onMore,
    required this.onEdit,
    required this.onRemove,
    super.key,
  });
  final List<BudgetProgress> rows;
  final VoidCallback onMore;
  final ValueChanged<BudgetProgress> onEdit;
  final ValueChanged<BudgetProgress> onRemove;
  @override
  Widget build(BuildContext context) => BudgetSection(
    title: '分类预算',
    onMore: onMore,
    child: rows.isEmpty
        ? _BudgetEmpty(text: '为餐饮、交通等分类设置预算', action: '添加分类预算', onTap: onMore)
        : Column(
            children: [
              for (var i = 0; i < rows.take(4).length; i++) ...[
                if (i > 0) const SizedBox(height: 3),
                CategoryBudgetRow(
                  progress: rows[i],
                  onTap: () => onEdit(rows[i]),
                  onLongPress: () => onRemove(rows[i]),
                ),
              ],
            ],
          ),
  );
}

class CategoryBudgetRow extends StatelessWidget {
  const CategoryBudgetRow({
    required this.progress,
    required this.onTap,
    this.onLongPress,
    super.key,
  });
  final BudgetProgress progress;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  Color get accent => switch (progress.category?.icon) {
    'food' || 'dining' || 'restaurant' => const Color(0xFFFF9245),
    'transport' || 'car' => const Color(0xFF3597FF),
    'shopping' => const Color(0xFFFF547E),
    'daily' || 'home' => const Color(0xFF0BD89A),
    _ => CategoryIcon.accentFor(
      progress.category?.name ?? '其他',
      iconKey: progress.category?.icon,
    ),
  };
  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 355 ||
        MediaQuery.textScalerOf(context).scale(12) > 16;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          progress.category?.name ?? '已隐藏分类',
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: budgetText(12.5, weight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          '¥ ${MoneyFormatter.whole(progress.budget.amount)}',
          style: budgetText(10.5, color: budgetMuted),
        ),
      ],
    );
    final spending = Text(
      '已支出 ¥ ${MoneyFormatter.whole(progress.used)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: budgetText(10.3, weight: FontWeight.w600),
    );
    final percent = Text(
      '${(progress.percentage * 100).round()}%',
      style: budgetText(10.5, weight: FontWeight.w600),
    );
    final icon = _BudgetIconTile(
      size: 35,
      color: accent,
      child:
          progress.category?.icon == 'daily' ||
              progress.category?.icon == 'home'
          ? const Icon(Icons.home_rounded, size: 21, color: Colors.white)
          : CategoryIcon(
              category: progress.category?.name ?? '其他',
              iconKey: progress.category?.icon,
              bare: true,
              size: 20,
            ),
    );
    final children = compact
        ? <Widget>[
            Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(child: title),
                _BudgetStatus(status: progress.status),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: budgetMuted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: spending),
                percent,
              ],
            ),
            const SizedBox(height: 4),
            _BudgetProgress(value: progress.percentage, color: accent),
          ]
        : <Widget>[
            Row(
              children: [
                icon,
                const SizedBox(width: 10),
                SizedBox(width: 54, child: title),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      spending,
                      const SizedBox(height: 5),
                      _BudgetProgress(
                        value: progress.percentage,
                        color: accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(width: 30, child: percent),
                const SizedBox(width: 6),
                _BudgetStatus(status: progress.status),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: budgetMuted,
                ),
              ],
            ),
          ];
    return BudgetSurface(
      frosted: false,
      radius: 12,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('budget-category-${progress.budget.categoryId}'),
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              9,
              compact ? 10 : 6.5,
              6,
              compact ? 10 : 6.5,
            ),
            child: Column(children: children),
          ),
        ),
      ),
    );
  }
}

class _BudgetIconTile extends StatelessWidget {
  const _BudgetIconTile({
    required this.child,
    required this.color,
    this.size = 37,
  });
  final Widget child;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, .26)!, color],
      ),
    ),
    child: IconTheme(
      data: const IconThemeData(color: Colors.white),
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: Center(child: child),
      ),
    ),
  );
}

class _BudgetProgress extends StatelessWidget {
  const _BudgetProgress({required this.value, required this.color});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(5),
    child: SizedBox(
      height: 8,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFE5E7E8))),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.white, .25)!],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BudgetStatus extends StatelessWidget {
  const _BudgetStatus({required this.status});
  final BudgetAlertStatus status;
  @override
  Widget build(BuildContext context) {
    final normal = status == BudgetAlertStatus.normal;
    return Container(
      width: MediaQuery.textScalerOf(context).scale(51),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: normal ? const Color(0xFFE0FBEA) : const Color(0xFFFFE4E1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        textAlign: TextAlign.center,
        maxLines: 1,
        switch (status) {
          BudgetAlertStatus.normal => '正常',
          BudgetAlertStatus.nearLimit => '接近上限',
          BudgetAlertStatus.exceeded => '已超预算',
        },
        style: budgetText(
          9.5,
          weight: FontWeight.w600,
          color: normal ? const Color(0xFF00B975) : const Color(0xFFFF3549),
        ),
      ),
    );
  }
}

class SavingsGoalsSection extends StatelessWidget {
  const SavingsGoalsSection({
    required this.goals,
    required this.onMore,
    required this.onGoal,
    required this.onCreate,
    super.key,
  });
  final List<Goal> goals;
  final VoidCallback onMore;
  final ValueChanged<Goal> onGoal;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final visible = goals
        .where((g) => g.status == GoalStatus.active)
        .take(2)
        .toList();
    final stacked =
        MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(12) > 16;
    return BudgetSection(
      title: '储蓄目标',
      onMore: onMore,
      child: visible.isEmpty
          ? _BudgetEmpty(text: '为想实现的心愿存下一笔钱', action: '新增目标', onTap: onCreate)
          : stacked
          ? Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  SavingsGoalCard(
                    goal: visible[i],
                    onTap: () => onGoal(visible[i]),
                  ),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: SavingsGoalCard(
                      goal: visible[i],
                      onTap: () => onGoal(visible[i]),
                    ),
                  ),
                ],
                if (visible.length == 1) const Expanded(child: SizedBox()),
              ],
            ),
    );
  }
}

class SavingsGoalCard extends StatelessWidget {
  const SavingsGoalCard({required this.goal, required this.onTap, super.key});
  final Goal goal;
  final VoidCallback onTap;
  Widget _cover() {
    final fallback = switch (goal.goalType) {
      GoalType.travel => 'assets/images/budgets/travel-cover.png',
      GoalType.emergencyFund => 'assets/images/budgets/emergency-cover.png',
      _ => 'assets/images/goal_car.png',
    };
    Widget defaultImage() => Image.asset(
      fallback,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
    final path = goal.coverPath;
    if (path == null) return defaultImage();
    if (path.startsWith('assets/'))
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => defaultImage(),
      );
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => defaultImage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = goal.goalType == GoalType.emergencyFund
        ? const Color(0xFF2C92FF)
        : budgetGreen;
    return BudgetSurface(
      frosted: false,
      radius: 13,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('budget-goal-${goal.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 6, 9, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(width: 55, height: 44, child: _cover()),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: budgetText(12.5, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goal.description ?? goal.goalType.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: budgetText(10, color: budgetMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      style: budgetText(11.5, color: budgetMuted),
                      children: [
                        TextSpan(
                          text: '¥ ${MoneyFormatter.whole(goal.currentAmount)}',
                          style: const TextStyle(
                            color: budgetInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' / ¥ ${MoneyFormatter.whole(goal.targetAmount)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: _BudgetProgress(
                        value: goal.progress,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 9),
                    SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(25),
                      child: Text(
                        '${goal.progressPercent}%',
                        style: budgetText(10.5, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: budgetMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${goal.targetDate.year}年${goal.targetDate.month}月',
                        style: budgetText(10.5, color: budgetMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReminderStrategySection extends StatelessWidget {
  const ReminderStrategySection({
    required this.preferences,
    required this.onChanged,
    required this.onSettings,
    required this.onReview,
    this.busy = false,
    super.key,
  });
  final BudgetPreferences preferences;
  final void Function(BudgetPreference, bool) onChanged;
  final VoidCallback onSettings;
  final VoidCallback onReview;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final stacked =
        MediaQuery.sizeOf(context).width < 355 ||
        MediaQuery.textScalerOf(context).scale(12) > 16;
    final cards = [
      for (final preference in BudgetPreference.values)
        ReminderToggleCard(
          preference: preference,
          enabled: preferences.enabled(preference),
          busy: busy,
          onChanged: (value) => onChanged(preference, value),
          onTap: preference == BudgetPreference.weeklyReview
              ? onReview
              : onSettings,
        ),
    ];
    return BudgetSection(
      title: '提醒与策略',
      moreLabel: '更多设置',
      onMore: onSettings,
      child: stacked
          ? Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  cards[i],
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
    );
  }
}

class ReminderToggleCard extends StatelessWidget {
  const ReminderToggleCard({
    required this.preference,
    required this.enabled,
    required this.onChanged,
    required this.onTap,
    this.busy = false,
    super.key,
  });
  final BudgetPreference preference;
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon, color, background) = switch (preference) {
      BudgetPreference.overspend => (
        '超支提醒',
        '接近预算时提醒',
        Icons.notifications_rounded,
        const Color(0xFFFF343B),
        const Color(0xFFFFD6D1),
      ),
      BudgetPreference.weeklyReview => (
        '每周复盘',
        '每周自动汇总',
        Icons.calendar_month_rounded,
        const Color(0xFF0786FF),
        const Color(0xFFCCE4FF),
      ),
      BudgetPreference.smartAdvice => (
        '智能建议',
        '基于消费习惯',
        Icons.lightbulb_rounded,
        const Color(0xFFA34DFF),
        const Color(0xFFE4D0FF),
      ),
    };
    return BudgetSurface(
      frosted: false,
      radius: 13,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 7, 6, 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 37,
                  height: 37,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(
                        title,
                        style: budgetText(11.5, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          style: budgetText(8.5, color: budgetMuted),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Semantics(
                        label: title,
                        excludeSemantics: true,
                        toggled: enabled,
                        enabled: !busy,
                        onTap: busy ? null : () => onChanged(!enabled),
                        child: GestureDetector(
                          key: ValueKey('budget-switch-${preference.name}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: busy ? null : () => onChanged(!enabled),
                          child: SizedBox(
                            width: 46,
                            height: 26,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 160),
                                width: 31,
                                height: 18,
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  color: enabled
                                      ? budgetGreen
                                      : const Color(0xFFC9CDD2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: AnimatedAlign(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 160),
                                  alignment: enabled
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    width: 15,
                                    height: 15,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x22000000),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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

class BudgetAdviceBanner extends StatelessWidget {
  const BudgetAdviceBanner({
    required this.data,
    required this.enabled,
    required this.onDetails,
    super.key,
  });
  final BudgetPeriodOverview data;
  final bool enabled;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) {
    final category = data.leadingCategory;
    final large =
        MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(10.5) > 14;
    final detailButton = SizedBox(
      width: large ? 120 : 75,
      child: BudgetActionButton(
        label: '查看详情',
        primary: true,
        compact: true,
        onTap: onDetails,
      ),
    );
    final name = category?.category?.name ?? '消费';
    final previous =
        data.previousCategorySpending[category?.budget.categoryId] ?? 0;
    final growth = previous > 0 && category != null
        ? (category.used / previous - 1) * 100
        : null;
    final share = data.spent > 0 && category != null
        ? category.used / data.spent * 100
        : 0;
    final elevated =
        category != null &&
        (category.status != BudgetAlertStatus.normal || (growth ?? 0) > 10);
    final title = !enabled
        ? '智能建议已关闭'
        : data.overview.total == null
        ? '设置预算，让每笔支出更有方向'
        : elevated
        ? '${data.period.noun}$name支出偏高，建议${name.contains('餐') ? '减少外卖频次' : '适度控制支出'}'
        : '${data.period.noun}消费节奏平稳，继续保持预算计划';
    final detail = !enabled
        ? '开启后，根据当前账本的消费记录提供建议。'
        : category == null
        ? '记录消费后，可在这里查看预算与支出建议。'
        : '你${data.period.noun}$name支出占总支出的 ${share.round()}%'
              '${growth == null ? '，暂无前期对比。' : '，${growth >= 0 ? '高' : '低'}于前期 ${growth.abs().round()}%。'}';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: .85)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3CE), Color(0xFFFFE7B6), Color(0xFFFFF0D7)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 6, 8, 6),
        child: Row(
          children: [
            SizedBox(
              width: 71,
              height: 54,
              child: Stack(
                children: [
                  const Positioned(
                    left: 1,
                    top: 1,
                    child: Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFD575),
                      size: 22,
                    ),
                  ),
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/budgets/advice-robot.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDA92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BudgetCrown(
                              size: 9,
                              color: Color(0xFFBA7019),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '小冰建议',
                              style: budgetText(
                                8,
                                weight: FontWeight.w600,
                                color: const Color(0xFFBA7019),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: EdgeInsets.only(right: large ? 0 : 81),
                        child: Text(
                          title,
                          style: budgetText(10.5, weight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(detail, style: budgetText(9.5, color: budgetMuted)),
                      if (large) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: detailButton,
                        ),
                      ],
                    ],
                  ),
                  if (!large) Positioned(right: 0, top: 5, child: detailButton),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetEmpty extends StatelessWidget {
  const _BudgetEmpty({
    required this.text,
    required this.action,
    required this.onTap,
  });
  final String text;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => BudgetSurface(
    frosted: false,
    radius: 12,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: budgetText(11, color: budgetMuted)),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onTap,
          child: Text(
            action,
            style: budgetText(11, weight: FontWeight.w600, color: budgetGold),
          ),
        ),
      ],
    ),
  );
}
