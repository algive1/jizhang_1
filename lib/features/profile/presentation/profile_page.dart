import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/membership.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../accounts/data/account_repository.dart';
import '../../budgets/data/budget_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../membership/data/membership_repository.dart';
import '../../transactions/data/transactions_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(allAccountsProvider).value ?? const [];
    final categoriesState = ref.watch(categoriesProvider);
    final categories = categoriesState.value ?? const [];
    final transactionsState = ref.watch(transactionsProvider);
    final transactions = transactionsState.value ?? const [];
    final budget = ref.watch(budgetOverviewProvider).total;
    final membership = ref.watch(membershipProvider).value;
    final plan = membership?.membership.plan ?? MembershipPlan.free;
    final cloudEnabled = membership?.has(EntitlementKey.cloudSync) ?? false;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          const _ProfileHeader(),
          if (categoriesState.hasError || transactionsState.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '本地数据读取失败：${categoriesState.error ?? transactionsState.error}',
                style: const TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
          _ProfileHero(streakDays: _streakDays(transactions, DateTime.now())),
          const SizedBox(height: 16),
          _MembershipCard(
            plan: plan,
            cloudEnabled: cloudEnabled,
            onTap: () => context.push('/profile/membership'),
          ),
          const SizedBox(height: 18),
          _MenuCard(
            items: [
              _MenuItem(
                Icons.home_outlined,
                '共享账本',
                '家庭和企业 · 登录后可用',
                route: '/profile/family',
              ),
              _MenuItem(
                Icons.verified_user_outlined,
                '数据与安全',
                '可导出流水 CSV 与完整备份',
                route: '/profile/data',
              ),
              _MenuItem(
                Icons.notifications_active_outlined,
                '支付通知记账',
                'Android 可选开启',
                route: '/profile/payment-notifications',
              ),
              _MenuItem(
                Icons.account_balance_wallet_outlined,
                '账户与资产',
                '${accounts.length} 个账户',
                route: '/profile/assets',
              ),
              _MenuItem(
                Icons.sell_outlined,
                '分类管理',
                '${categories.length}个分类',
                route: '/profile/categories',
              ),
              _MenuItem(
                Icons.savings_outlined,
                '预算管理',
                budget == null
                    ? '未设置'
                    : '还剩 ¥${MoneyFormatter.whole(budget.remaining)}',
                route: '/profile/budgets',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuCard(
            items: [
              _MenuItem(Icons.notifications_none, '提醒设置', '暂未开启'),
              _MenuItem(
                Icons.help_outline,
                '帮助与反馈',
                '',
                onTap: () => _showHelp(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              '—  ♥  用心记录每一笔，让生活更从容  ♥  —',
              style: TextStyle(color: AppColors.primaryDark, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  static int _streakDays(List<TransactionRecord> transactions, DateTime now) {
    final dates = transactions
        .where((item) => item.deletedAt == null)
        .map(
          (item) => DateTime(
            item.occurredAt.year,
            item.occurredAt.month,
            item.occurredAt.day,
          ),
        )
        .toSet();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!dates.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (dates.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('帮助与反馈'),
        content: Text(
          '你可以在首页记账，在流水中编辑或删除记录，在账户、分类和预算页管理本地数据。\n\n'
          '当前版本没有联网客服入口；如需反馈，请保留发生问题的时间和页面。',
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Text('我的', style: Theme.of(context).textTheme.headlineLarge)],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 18, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, Color(0xFFF2F2DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFE7DDBD)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 300;
          return Stack(
            children: [
              if (!compact)
                Positioned(
                  right: -70,
                  top: -36,
                  bottom: -30,
                  width: 230,
                  child: Opacity(
                    opacity: .42,
                    child: Image.asset(
                      AppAssets.homeLivingScene,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ),
              Row(
                children: [
                  UserAvatar(radius: compact ? 39 : 46),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本地用户',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Icon(
                              Icons.eco_outlined,
                              size: 21,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '已连续记账 ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              '$streakDays 天',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.plan,
    required this.cloudEnabled,
    required this.onTap,
  });

  final MembershipPlan plan;
  final bool cloudEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AppCard(
        color: const Color(0xFFF7F7E9),
        padding: const EdgeInsets.fromLTRB(18, 17, 13, 17),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: AppColors.primary,
                size: 33,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plan.label} 方案',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    cloudEnabled ? '云同步权益已授权' : '本地记账 · 可导出流水',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              cloudEnabled
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              color: cloudEnabled ? AppColors.primary : AppColors.textSecondary,
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.value, {this.route, this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final String? route;
  final VoidCallback? onTap;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final item = entry.value;
          return Column(
            children: [
              InkWell(
                onTap:
                    item.onTap ??
                    (item.route == null
                        ? null
                        : () => context.push(item.route!)),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Icon(item.icon, color: AppColors.primary, size: 29),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      if (item.value.isNotEmpty)
                        Flexible(
                          child: Text(
                            item.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      const SizedBox(width: 5),
                      if (item.onTap != null || item.route != null)
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ),
              ),
              if (entry.key != items.length - 1) const Divider(indent: 47),
            ],
          );
        }).toList(),
      ),
    );
  }
}
