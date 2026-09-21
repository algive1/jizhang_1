import 'package:flutter/material.dart';

import '../formatters/money_formatter.dart';
import '../models/goal.dart';
import 'app_card.dart';
import '../../features/goals/domain/goal_milestone_service.dart';
import '../../app/theme/app_theme_tokens.dart';

class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({required this.goal, super.key, this.onTap});
  final Goal goal;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final milestones = [...goal.milestones]
      ..sort((a, b) => a.amount.compareTo(b.amount));
    final next = milestones
        .where((m) => m.amount > goal.currentAmount)
        .firstOrNull;
    final amounts = const GoalMilestoneService().visibleAmounts(goal);
    final currentIndex = amounts.indexOf(goal.currentAmount);
    final lineProgress = amounts.length < 2
        ? 1.0
        : currentIndex / (amounts.length - 1);
    return AppCard(
      color: const Color(0xFFF2F5E4),
      border: Border.all(color: const Color(0xFFCBD8AC)),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _goalIcon(goal.goalType),
                  size: 20,
                  color: context.appPrimary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    goal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.appPrimaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${goal.progressPercent}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '¥${MoneyFormatter.whole(goal.currentAmount)} / ¥${MoneyFormatter.whole(goal.targetAmount)}',
                style: TextStyle(
                  fontSize: 21,
                  color: context.appPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final inset = constraints.maxWidth / amounts.length / 2;
                return Stack(
                  children: [
                    Positioned(
                      left: inset,
                      right: inset,
                      top: 11,
                      child: LinearProgressIndicator(
                        value: lineProgress,
                        minHeight: 3,
                        color: context.appPrimary,
                        backgroundColor: const Color(0xFFDFE7CB),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: amounts.map((amount) {
                        final current = amount == goal.currentAmount;
                        final done = amount < goal.currentAmount;
                        return Expanded(
                          child: Semantics(
                            label:
                                '${current
                                    ? '当前'
                                    : done
                                    ? '已完成'
                                    : '目标节点'}${MoneyFormatter.decimal(amount)}元',
                            child: Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: done
                                        ? context.appPrimary
                                        : context.appSurface,
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
                                          size: 17,
                                          color: Colors.white,
                                        )
                                      : current
                                      ? Center(
                                          child: Icon(
                                            Icons.circle,
                                            size: 9,
                                            color: context.appPrimary,
                                          ),
                                        )
                                      : amount == goal.targetAmount
                                      ? Icon(
                                          _goalIcon(goal.goalType),
                                          size: 13,
                                          color: context.appSecondaryText,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 3),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    amount.abs() >= 10000
                                        ? '${(amount / 10000).toStringAsFixed(1)}万'
                                        : MoneyFormatter.whole(amount),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: current
                                          ? context.appPrimaryText
                                          : context.appSecondaryText,
                                    ),
                                  ),
                                ),
                                Text(
                                  current ? '当前' : ' ',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: context.appPrimary,
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
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    next == null
                        ? '目标已达成'
                        : '下一站 ¥${MoneyFormatter.whole(next.amount)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.appPrimary,
                ),
              ],
            ),
          ],
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
