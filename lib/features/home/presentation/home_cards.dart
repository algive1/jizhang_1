import 'package:flutter/material.dart';

import 'goal_flow_track.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/dashboard_snapshot.dart';
import '../../../core/models/goal.dart';
import '../../../core/models/family.dart';
import '../../../core/widgets/privacy_amount.dart';
import '../../../core/widgets/app_glass_surface.dart';
import '../../goals/domain/goal_milestone_service.dart';
import '../../../core/constants/app_assets.dart';

class HomeSurface extends StatelessWidget {
  const HomeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => AppGlassSurface(
    padding: padding,
    borderRadius: 20,
    tint: context.appSurface,
    blurSigma: 12,
    chromaticEdge: false,
    child: child,
  );
}

class HomeMonthlySummary extends StatelessWidget {
  const HomeMonthlySummary({
    super.key,
    required this.snapshot,
    required this.onTap,
    this.onYear,
    this.onMonth,
    this.onPrevious,
    this.onNext,
  });
  final MonthlyTotals snapshot;
  final VoidCallback onTap;
  final VoidCallback? onYear, onMonth, onPrevious, onNext;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current =
        snapshot.month.year == now.year && snapshot.month.month == now.month;
    return HomeSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (onPrevious != null)
                    IconButton(
                      tooltip: '上个月',
                      onPressed: onPrevious,
                      icon: Icon(Icons.chevron_left, size: 20),
                    ),
                  TextButton(
                    key: ValueKey('home-year-picker'),
                    onPressed: onYear,
                    style: TextButton.styleFrom(
                      foregroundColor: context.appPrimaryText,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size(64, 44),
                    ),
                    child: Text(
                      '${snapshot.month.year}年',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('home-month-picker'),
                    onPressed: onMonth,
                    style: TextButton.styleFrom(
                      foregroundColor: context.appPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      minimumSize: Size(44, 44),
                    ),
                    child: Text(
                      '${snapshot.month.month}月⌄',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onPrevious != null)
                    IconButton(
                      tooltip: '下个月',
                      onPressed: onNext,
                      icon: const Icon(Icons.chevron_right, size: 20),
                    ),
                ],
              ),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  minimumSize: const Size(70, 44),
                ),
                child: Text(
                  current ? '本月账单 ›' : '${snapshot.month.month}月账单 ›',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appSecondaryText,
                  ),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metric('收入', snapshot.income, context.appPrimary),
              _metric('支出', snapshot.expense, context.appPrimaryText),
              _metric('收支结余', snapshot.forecastBalance, context.appPrimaryText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, double amount, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color.withValues(alpha: .72),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '¥ ${MoneyFormatter.decimal(amount)}',
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class HomeSpendingGoalCard extends StatefulWidget {
  const HomeSpendingGoalCard({
    super.key,
    required this.snapshot,
    this.goal,
    required this.onBudget,
    required this.onGoal,
    required this.onCalculation,
    this.bookType = BookType.personal,
    this.onWeekBudget,
    this.amountHidden,
    this.onAmountHiddenChanged,
    this.todayAmountHidden,
    this.goalAmountHidden,
    this.onTodayAmountHiddenChanged,
    this.onGoalAmountHiddenChanged,
  });
  final DashboardSnapshot snapshot;
  final Goal? goal;
  final VoidCallback onBudget, onGoal, onCalculation;
  final BookType bookType;
  final VoidCallback? onWeekBudget;
  final bool? amountHidden;
  final ValueChanged<bool>? onAmountHiddenChanged;
  final bool? todayAmountHidden;
  final bool? goalAmountHidden;
  final ValueChanged<bool>? onTodayAmountHiddenChanged;
  final ValueChanged<bool>? onGoalAmountHiddenChanged;

  @override
  State<HomeSpendingGoalCard> createState() => _HomeSpendingGoalCardState();
}

class _HomeSpendingGoalCardState extends State<HomeSpendingGoalCard> {
  bool _amountHidden = false;

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 340;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
        final isAmountHidden = widget.amountHidden ?? _amountHidden;
        final todayAmountHidden = widget.todayAmountHidden ?? isAmountHidden;
        final goalAmountHidden = widget.goalAmountHidden ?? false;
        final realAmountText = widget.snapshot.hasBudget
            ? '¥${MoneyFormatter.whole(widget.snapshot.safeToSpend)}'
            : '未设置预算';
        // Keep the illustration for normal amounts. Once the amount becomes
        // long enough to compete with it, remove the decoration and give the
        // number the full line so it stays readable and cannot overlap.
        final showDecoration = !largeText && realAmountText.runes.length <= 8;
        return Container(
          key: ValueKey('home-spending-card'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.appSurface, context.appPrimarySoft.withValues(alpha: .58)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appDivider.withValues(alpha: .72)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C65713F),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                // Large accessibility text needs room for the budget controls and
                // the calculation subtitle to wrap at narrow widths.
                // Keep enough vertical room for the controls and calculation
                // line at compact widths and enlarged accessibility text.
                // The reference layout is single-column at phone widths, so
                // the extra room only applies below the 340dp breakpoint.
                height: largeText ? null : (narrow ? 134 : 118),
                child: Stack(
                  fit: largeText ? StackFit.loose : StackFit.expand,
                  children: [
                    if (showDecoration)
                      Positioned(
                        right: -4,
                        top: 0,
                        width: 142,
                        height: 112,
                        child: Opacity(
                          opacity: .88,
                          child: Image.asset(
                            AppAssets.homeLivingScene,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    if (showDecoration)
                      Positioned(
                        right: 102,
                        top: 45,
                        child: Text(
                          '好好花钱\n也好好生活',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.appPrimary,
                            fontSize: 10,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 9, 18, 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 2,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                    button: true,
                                    label:
                                        '${widget.bookType.spendingLabel}，打开预算管理',
                                    child: InkWell(
                                      key: const ValueKey('home-budget-area'),
                                      onTap: widget.onBudget,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          widget.bookType == BookType.personal
                                              ? '今日可用'
                                              : widget.bookType.spendingLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: context.appPrimaryText,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    key: const ValueKey('home-hide-amount'),
                                    tooltip: todayAmountHidden
                                        ? '显示金额'
                                        : '隐藏金额',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 26,
                                      height: 26,
                                    ),
                                    onPressed: () {
                                      final next = !todayAmountHidden;
                                      final callback =
                                          widget.onTodayAmountHiddenChanged ??
                                          widget.onAmountHiddenChanged;
                                      if (callback != null) {
                                        callback(next);
                                      } else {
                                        setState(() => _amountHidden = next);
                                      }
                                    },
                                    icon: Icon(
                                      todayAmountHidden
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: context.appSecondaryText,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _BudgetChoice(
                                      label: '本月预算',
                                      selected: true,
                                      onTap: widget.onBudget,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          SizedBox(
                            height: MediaQuery.textScalerOf(context)
                                .scale(widget.snapshot.hasBudget ? 39 : 22),
                            width: double.infinity,
                            child: Padding(
                              // The living-room illustration and its caption
                              // occupy the right side of the card. Reserve
                              // that space so long amounts never paint over
                              // the decoration.
                              padding: EdgeInsets.only(
                                right: showDecoration ? 112 : 0,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: PrivacyAmount(
                                  text: realAmountText,
                                  hidden:
                                      todayAmountHidden &&
                                      widget.snapshot.hasBudget,
                                  fit: true,
                                  alignment: Alignment.centerLeft,
                                  style: TextStyle(
                                    color: widget.snapshot.availableAmount < 0
                                        ? AppColors.expense
                                        : context.appPrimary,
                                    fontSize: widget.snapshot.hasBudget
                                        ? 39
                                        : 23,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (largeText)
                            const SizedBox(height: 12)
                          else
                            const Spacer(),
                          InkWell(
                            key: const ValueKey('home-calculation'),
                            onTap: widget.onCalculation,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: largeText
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '收支结余',
                                          style: TextStyle(
                                            color: context.appSecondaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(
                                          height: MediaQuery.textScalerOf(
                                            context,
                                          ).scale(18),
                                          width: double.infinity,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              widget.snapshot.hasBudget
                                                  ? '¥${MoneyFormatter.whole(widget.snapshot.forecastBalance)}  |  还有 ${widget.snapshot.remainingDays} 天'
                                                  : '设置本月预算后计算 ›',
                                              maxLines: 1,
                                              softWrap: false,
                                              style: TextStyle(
                                                color: context.appSecondaryText,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        Text(
                                          '收支结余',
                                          style: TextStyle(
                                            color: context.appSecondaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          widget.snapshot.hasBudget
                                              ? '¥${MoneyFormatter.whole(widget.snapshot.forecastBalance)}  |  还有 ${widget.snapshot.remainingDays} 天'
                                              : '设置本月预算后计算 ›',
                                          style: TextStyle(
                                            color: context.appSecondaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.appPrimarySoft,
                      context.appSurfaceSoft,
                      context.appSurface,
                    ],
                    stops: [0, .55, 1],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.appSurface.withValues(alpha: .8)),
                ),
                padding: const EdgeInsets.fromLTRB(15, 6, 15, 5),
                child: goal == null
                    ? InkWell(
                        key: const ValueKey('home-goal-area'),
                        onTap: widget.onGoal,
                        child: _EmptyGoalLabel(bookType: widget.bookType),
                      )
                    : Semantics(
                        button: true,
                        label: '打开目标${goal.name}',
                        child: InkWell(
                          key: const ValueKey('home-goal-area'),
                          onTap: widget.onGoal,
                          borderRadius: BorderRadius.circular(12),
                          child: _HomeGoalTimeline(
                            goal: goal,
                            amountHidden: goalAmountHidden,
                            onAmountHiddenChanged:
                                widget.onGoalAmountHiddenChanged,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BudgetChoice extends StatelessWidget {
  const _BudgetChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? context.appPrimary
            : context.appSurface.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : context.appSecondaryText,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _EmptyGoalLabel extends StatelessWidget {
  const _EmptyGoalLabel({required this.bookType});
  final BookType bookType;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.flag_outlined, color: context.appPrimary, size: 21),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          bookType == BookType.enterprise
              ? '设一个经营目标'
              : bookType == BookType.family
              ? '设一个家庭目标'
              : '设一个正在努力的目标',
          style: TextStyle(fontSize: 13, color: context.appPrimaryText),
        ),
      ),
      Icon(Icons.chevron_right, color: context.appPrimary),
    ],
  );
}

class _HomeGoalTimeline extends StatelessWidget {
  const _HomeGoalTimeline({
    required this.goal,
    required this.amountHidden,
    required this.onAmountHiddenChanged,
  });
  final Goal goal;
  final bool amountHidden;
  final ValueChanged<bool>? onAmountHiddenChanged;
  @override
  Widget build(BuildContext context) {
    final visible = const GoalMilestoneService().visibleAmounts(goal);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final currentIndex = visible.indexWhere(
      (value) => value == goal.currentAmount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _goalIconForHome(goal),
              color: context.appPrimary,
              size: 19,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appPrimaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onAmountHiddenChanged != null)
                    IconButton(
                      key: const ValueKey('home-goal-hide-amount'),
                      tooltip: amountHidden ? '显示目标金额' : '隐藏目标金额',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 26,
                        height: 26,
                      ),
                      onPressed: () {
                        onAmountHiddenChanged!(!amountHidden);
                      },
                      icon: Icon(
                        amountHidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.appSecondaryText,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.appPrimarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appDivider),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                child: Text(
                  '${goal.progressPercent}%',
                  style: TextStyle(
                    color: context.appPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 1),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(27),
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: amountHidden
                        ? '¥••••'
                        : '¥${MoneyFormatter.whole(goal.currentAmount)}',
                    style: TextStyle(
                      color: context.appPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: amountHidden
                        ? ' / ¥••••'
                        : ' / ¥${MoneyFormatter.whole(goal.targetAmount)}',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: DefaultTextStyle.of(context).style,
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: largeText ? 64 : 52,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GoalFlowTrack(
                      count: visible.length,
                      currentIndex: currentIndex,
                      enabled: goal.status == GoalStatus.active,
                    ),
                  ),
                  Row(
                    children: visible.map((amount) {
                      final done = amount < goal.currentAmount;
                      final current = amount == goal.currentAmount;
                      return Expanded(
                        child: SizedBox(
                          height: largeText ? 64 : 52,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 26,
                                height: 26,
                                child: Center(
                                  child: amount == goal.targetAmount
                                      ? SizedBox(width: 16, height: 16)
                                      : Container(
                                          width: current ? 20 : 16,
                                          height: current ? 20 : 16,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: done
                                                ? context.appPrimary
                                                : context.appSurfaceSoft,
                                            border: Border.all(
                                              color: done || current
                                                  ? context.appPrimary
                                                  : context.appDivider,
                                              width: current ? 3 : 2,
                                            ),
                                          ),
                                          child: done
                                              ? Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Colors.white,
                                                )
                                              : current
                                              ? Center(
                                                  child: Icon(
                                                    Icons.circle,
                                                    size: 7,
                                                    color: context.appPrimary,
                                                  ),
                                                )
                                              : amount == goal.targetAmount
                                              ? Icon(
                                                  _goalIconForHome(goal),
                                                  size: 12,
                                                  color:
                                                      context.appSecondaryText,
                                                )
                                              : null,
                                        ),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                amountHidden
                                    ? '¥••••\n${amount == goal.currentAmount
                                          ? '当前'
                                          : amount == goal.targetAmount
                                          ? '目标'
                                          : done
                                          ? '已完成'
                                          : '待达成'}'
                                    : amount == goal.currentAmount
                                    ? '¥${MoneyFormatter.whole(amount)}\n当前'
                                    : amount == goal.targetAmount
                                    ? '¥${MoneyFormatter.whole(amount)}\n目标'
                                    : done
                                    ? '¥${MoneyFormatter.whole(amount)}\n已完成'
                                    : '¥${MoneyFormatter.whole(amount)}\n待达成',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 8,
                                  height: 1.15,
                                  color: current
                                      ? context.appPrimaryText
                                      : context.appSecondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

IconData _goalIconForHome(Goal goal) {
  if (goal.icon == 'car') return Icons.directions_car_filled;
  if (goal.icon == 'travel') return Icons.flight_takeoff;
  if (goal.icon == 'home') return Icons.home_outlined;
  return switch (goal.goalType) {
    GoalType.car => Icons.directions_car_filled,
    GoalType.travel => Icons.flight_takeoff,
    GoalType.homeDownPayment => Icons.home_outlined,
    _ => Icons.flag_outlined,
  };
}
