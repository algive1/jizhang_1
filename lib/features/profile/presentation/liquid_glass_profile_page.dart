import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/membership.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_liquid_glass_surface.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../account/application/account_session_controller.dart';
import '../../account/domain/account_session.dart';
import '../../account/domain/account_session_status.dart';
import '../../books/presentation/book_selector.dart';
import '../../budgets/data/budget_repository.dart';
import '../../home/data/home_data.dart';
import '../../membership/data/membership_repository.dart';
import '../../messages/application/system_message_service.dart';
import '../../settings/application/theme_controller.dart';
import '../../transactions/data/transactions_repository.dart';
import '../application/profile_quick_actions_controller.dart';
import '../data/profile_stats.dart';
import 'profile_quick_actions_page.dart';

class LiquidGlassProfilePage extends ConsumerWidget {
  const LiquidGlassProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final records = transactions.value ?? const [];
    final now = DateTime.now();
    final month = monthlySummary(records, DateTime(now.year, now.month), now);
    final previous = monthlySummary(
      records,
      DateTime(now.year, now.month - 1),
      now,
    );
    final activity = ProfileActivity(records, now);
    final budget = ref.watch(budgetOverviewProvider).total;
    final membership = ref.watch(membershipProvider).value;
    final accountSession = ref.watch(accountSessionProvider).value;
    final unread = ref.watch(systemUnreadCountProvider).value ?? 0;
    final quickActionOrder =
        ref.watch(profileQuickActionsProvider).value ??
        profileQuickActionDefaults;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: _ImmersiveProfileBackground(dark: dark),
        ),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              AppScaffold.reservedBottomInset(context),
            ),
            children: [
              _Header(
                unread: unread,
                onMessages: () async {
                  await context.push<void>('/profile/messages');
                  ref.invalidate(systemUnreadCountProvider);
                },
                onSettings: () => _showSettings(context),
              ),
              const SizedBox(height: 18),
              _ProfileIdentity(
                name: _profileName(accountSession),
                membership: membership,
                bookkeepingDays: activity.bookkeepingDays,
                onTap: () => _openProfile(context, accountSession),
              ),
              const SizedBox(height: 14),
              _SummaryPanel(
                loading: transactions.isLoading,
                expense: month.expense,
                income: month.income,
                expenseDelta: _deltaText(month.expense, previous.expense),
                incomeDelta: _deltaText(month.income, previous.income),
                budgetRemaining: budget?.remaining,
                budgetRatio: budget == null
                    ? null
                    : (1 - budget.percentage).clamp(0.0, 1.0).toDouble(),
                streak: activity.streak,
              ),
              const SizedBox(height: 14),
              _MembershipPanel(
                snapshot: membership,
                onTap: () => context.push('/profile/membership'),
              ),
              const SizedBox(height: 16),
              _GlassSection(
                title: '常用功能',
                trailing: '管理',
                onTrailing: () => context.push('/profile/quick-actions'),
                child: _QuickActionGrid(
                  order: quickActionOrder,
                  onTap: (id) => _openQuickAction(context, ref, id),
                ),
              ),
              const SizedBox(height: 16),
              const _RecommendedAppsSection(),
              const SizedBox(height: 16),
              _ServicesSection(
                onHelp: () => context.push('/profile/help'),
                onSecurity: () => context.push('/profile/data'),
                onAbout: () => context.push('/profile/about'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _profileName(AccountSession? session) {
    final user = session?.user;
    if (user != null) return user.preferredName;
    return session?.status == AccountSessionStatus.initializing
        ? '正在读取账号…'
        : '本地使用中';
  }

  static void _openProfile(BuildContext context, AccountSession? session) {
    final status = session?.status ?? AccountSessionStatus.initializing;
    if (status == AccountSessionStatus.authenticated) {
      context.push('/profile/account');
      return;
    }
    if (status == AccountSessionStatus.initializing) return;
    context.push('/account/login');
  }

  static void _openQuickAction(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) {
    switch (id) {
      case 'books':
        showBookSelectorSheet(context, ref);
        return;
      case 'bill_import':
        context.push('/profile/bill-import');
        return;
      case 'categories':
        context.push('/profile/categories');
        return;
      case 'budgets':
        _showBudgetAndGoals(context);
        return;
      case 'appearance':
        context.push('/profile/appearance');
        return;
      case 'autobookkeeping':
        context.push('/profile/autobookkeeping');
        return;
      default:
        return;
    }
  }

  static Future<void> _showBudgetAndGoals(BuildContext context) =>
      AppBottomSheet.show<void>(
        context: context,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '预算与目标',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: sheetContext.appPrimary,
                ),
                title: const Text('预算管理'),
                subtitle: const Text('设置月度与分类预算'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/profile/budgets');
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.flag_outlined,
                  color: sheetContext.appPrimary,
                ),
                title: const Text('目标管理'),
                subtitle: const Text('规划储蓄与生活目标'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/goals');
                },
              ),
            ],
          ),
        ),
      );

  static String _deltaText(double current, double previous) {
    if (previous <= 0) {
      return current <= 0 ? '较上月 —' : '本月新增';
    }
    final change = (current - previous) / previous * 100;
    final arrow = change >= 0 ? '↑' : '↓';
    return '较上月 $arrow${change.abs().round()}%';
  }

  static Future<void> _showSettings(BuildContext context) =>
      AppBottomSheet.show<void>(
        context: context,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '设置',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final item in const [
                (
                  Icons.palette_outlined,
                  '主题外观',
                  '/profile/appearance',
                ),
                (
                  Icons.notifications_none_rounded,
                  '通知设置',
                  '/profile/notification-settings',
                ),
                (
                  Icons.auto_awesome_outlined,
                  '自动记账',
                  '/profile/autobookkeeping',
                ),
                (
                  Icons.cloud_outlined,
                  '数据与安全',
                  '/profile/data',
                ),
                (
                  Icons.help_outline_rounded,
                  '帮助与反馈',
                  '/profile/help',
                ),
                (
                  Icons.info_outline_rounded,
                  '关于好好记账',
                  '/profile/about',
                ),
              ])
                ListTile(
                  leading: Icon(item.$1, color: sheetContext.appPrimary),
                  title: Text(item.$2),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(item.$3);
                  },
                ),
            ],
          ),
        ),
      );
}

class _ImmersiveProfileBackground extends StatelessWidget {
  const _ImmersiveProfileBackground({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.liquidGlassProfileBackground,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [
                        const Color(0x99110D12),
                        const Color(0x66151217),
                        const Color(0xB315110F),
                      ]
                    : [
                        const Color(0x220C0A08),
                        const Color(0x0FFFFFFF),
                        const Color(0x44F5E4D0),
                      ],
                stops: const [0, .42, 1],
              ),
            ),
          ),
        ],
      );
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.unread,
    required this.onMessages,
    required this.onSettings,
  });

  final int unread;
  final VoidCallback onMessages;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark =
        (ref.watch(brightnessModeProvider).value ??
            AppBrightnessPreference.light) ==
        AppBrightnessPreference.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你好，\n生活值得好好记录',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .4,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '让每一笔收支，都通向更好的自己',
                  style: TextStyle(
                    color: Color(0xF2FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                _HeaderIconButton(
                  tooltip: '通知',
                  onTap: onMessages,
                  badge: unread,
                  icon: Icons.notifications_none_rounded,
                ),
                const SizedBox(width: 8),
                _HeaderIconButton(
                  tooltip: '设置',
                  onTap: onSettings,
                  icon: Icons.settings_outlined,
                ),
              ],
            ),
            const SizedBox(height: 9),
            _BrightnessToggle(
              dark: dark,
              onChanged: (nextDark) => ref
                  .read(brightnessModeProvider.notifier)
                  .select(
                    nextDark
                        ? AppBrightnessPreference.dark
                        : AppBrightnessPreference.light,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.onTap,
    required this.icon,
    this.badge = 0,
  });

  final String tooltip;
  final VoidCallback onTap;
  final IconData icon;
  final int badge;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 43,
          height: 43,
          child: AppLiquidGlassSurface(
            borderRadius: 22,
            themeColorAccents: false,
            glassOpacity: MediaQuery.highContrastOf(context) ? .72 : .16,
            shadow: false,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  const SizedBox.expand(),
                  Icon(icon, color: Colors.white, size: 25),
                  if (badge > 0)
                    Positioned(
                      right: 7,
                      top: 6,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF24747),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BrightnessToggle extends StatelessWidget {
  const _BrightnessToggle({
    required this.dark,
    required this.onChanged,
  });

  final bool dark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 105,
      height: 43,
      child: AppLiquidGlassSurface(
        borderRadius: 22,
        themeColorAccents: false,
        glassOpacity: MediaQuery.highContrastOf(context) ? .72 : .18,
        shadow: false,
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment:
                  dark ? Alignment.centerRight : Alignment.centerLeft,
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 48,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0x99453C54)
                      : const Color(0xDFFFF4DF),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .56),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: !dark,
                    label: '白天模式',
                    child: InkWell(
                      key: const ValueKey('profile-light-mode'),
                      onTap: () => onChanged(false),
                      borderRadius: BorderRadius.circular(19),
                      child: Icon(
                        Icons.wb_sunny_rounded,
                        color: dark
                            ? const Color(0xCCFFFFFF)
                            : const Color(0xFFFF9D24),
                        size: 21,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: dark,
                    label: '夜晚模式',
                    child: InkWell(
                      key: const ValueKey('profile-dark-mode'),
                      onTap: () => onChanged(true),
                      borderRadius: BorderRadius.circular(19),
                      child: Icon(
                        Icons.dark_mode_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({
    required this.name,
    required this.membership,
    required this.bookkeepingDays,
    required this.onTap,
  });

  final String name;
  final MembershipSnapshot? membership;
  final int bookkeepingDays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plan = membership?.membership.plan;
    final badge = switch (plan) {
      MembershipPlan.pro => 'Pro',
      MembershipPlan.family => 'Family',
      _ => '记账用户',
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .86),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const UserAvatar(radius: 31),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              color: Color(0x55000000),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xDDF6D29B),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Color(0xFF7C4B21),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    bookkeepingDays <= 0
                        ? '热爱生活，也认真记录'
                        : '已陪你记录 $bookkeepingDays 天 · 继续保持 ✨',
                    style: const TextStyle(
                      color: Color(0xEEFFFFFF),
                      fontSize: 12,
                      shadows: [
                        Shadow(
                          color: Color(0x55000000),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.loading,
    required this.expense,
    required this.income,
    required this.expenseDelta,
    required this.incomeDelta,
    required this.budgetRemaining,
    required this.budgetRatio,
    required this.streak,
  });

  final bool loading;
  final double expense;
  final double income;
  final String expenseDelta;
  final String incomeDelta;
  final double? budgetRemaining;
  final double? budgetRatio;
  final int streak;

  @override
  Widget build(BuildContext context) => _GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryItem(
                icon: Icons.south_rounded,
                iconColor: const Color(0xFFFF7181),
                label: '本月支出',
                value: loading
                    ? '—'
                    : '¥${MoneyFormatter.whole(expense)}',
                footnote: loading ? '正在读取' : expenseDelta,
              ),
            ),
            const _SummaryDivider(),
            Expanded(
              child: _SummaryItem(
                icon: Icons.north_rounded,
                iconColor: const Color(0xFF42C97A),
                label: '本月收入',
                value: loading
                    ? '—'
                    : '¥${MoneyFormatter.whole(income)}',
                footnote: loading ? '正在读取' : incomeDelta,
              ),
            ),
            const _SummaryDivider(),
            Expanded(
              child: _SummaryItem(
                icon: Icons.pie_chart_rounded,
                iconColor: const Color(0xFF479CF4),
                label: '预算剩余',
                value: budgetRemaining == null
                    ? '未设置'
                    : '¥${MoneyFormatter.whole(budgetRemaining!)}',
                footnote: budgetRatio == null
                    ? '去设置预算'
                    : '剩余 ${(budgetRatio! * 100).round()}%',
                progress: budgetRatio,
              ),
            ),
            const _SummaryDivider(),
            Expanded(
              child: _SummaryItem(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFFFA044),
                label: '连续记账',
                value: '$streak 天',
                footnote: streak > 0 ? '继续保持' : '今天记一笔',
              ),
            ),
          ],
        ),
      );
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 82,
        color: Colors.white.withValues(alpha: .28),
      );
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.footnote,
    this.progress,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String footnote;
  final double? progress;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      color: context.appPrimaryText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: context.appPrimaryText,
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              footnote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: 9.5,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0).toDouble(),
                  minHeight: 4,
                  color: const Color(0xFF479CF4),
                  backgroundColor: Colors.white.withValues(alpha: .26),
                ),
              ),
            ],
          ],
        ),
      );
}

class _MembershipPanel extends StatelessWidget {
  const _MembershipPanel({
    required this.snapshot,
    required this.onTap,
  });

  final MembershipSnapshot? snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plan = snapshot?.membership.plan;
    final tag = switch (plan) {
      MembershipPlan.pro => 'Pro',
      MembershipPlan.family => 'Family',
      _ => '基础版',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF51402E),
                Color(0xFF2A231D),
                Color(0xFF211C18),
              ],
            ),
            border: Border.all(
              color: const Color(0x55FFE0A8),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFFE2A2),
                            Color(0xFFE8AE5B),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFF63431E),
                        size: 31,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  '记账会员',
                                  style: TextStyle(
                                    color: Color(0xFFFFF3DB),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE0A4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Color(0xFF6E4920),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '解锁更多高级能力，让记账更轻松',
                            style: TextStyle(
                              color: Color(0xFFDDCBB6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDB99),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        plan == MembershipPlan.free ? '查看权益 →' : '会员中心 →',
                        style: const TextStyle(
                          color: Color(0xFF503317),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0A4).withValues(alpha: .10),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(25),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: _Benefit(
                        icon: Icons.cloud_done_outlined,
                        label: '多端同步',
                      ),
                    ),
                    Expanded(
                      child: _Benefit(
                        icon: Icons.bar_chart_rounded,
                        label: '高级图表',
                      ),
                    ),
                    Expanded(
                      child: _Benefit(
                        icon: Icons.color_lens_outlined,
                        label: '主题皮肤',
                      ),
                    ),
                    Expanded(
                      child: _Benefit(
                        icon: Icons.auto_awesome_rounded,
                        label: '智能助手',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: const Color(0xFFE6B86F), size: 19),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE1CCB1),
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      );
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({
    required this.title,
    required this.child,
    this.trailing,
    this.onTrailing,
  });

  final String title;
  final Widget child;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) => _GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: context.appPrimaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null)
                  TextButton(
                    onPressed: onTrailing,
                    style: TextButton.styleFrom(
                      foregroundColor: context.appSecondaryText,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(trailing!),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.order,
    required this.onTap,
  });

  final List<String> order;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 16) / 3;
          final scaledBody = MediaQuery.textScalerOf(context).scale(12);
          final textScale = (scaledBody / 12).clamp(1.0, 2.0);
          final itemHeight = 88 + (textScale - 1) * 30;
          return GridView.builder(
            itemCount: order.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: itemWidth / itemHeight,
            ),
            itemBuilder: (context, index) {
              final spec = profileQuickActionSpec(order[index]);
              return _QuickActionTile(
                spec: spec,
                onTap: () => onTap(spec.id),
              );
            },
          );
        },
      );
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.spec,
    required this.onTap,
  });

  final ProfileQuickActionSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .07 : .34,
        ),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 9, 7, 7),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(spec.color, Colors.white, .16)!,
                        spec.color,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: spec.color.withValues(alpha: .22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(spec.icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appPrimaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spec.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appSecondaryText,
                          fontSize: 8.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appSecondaryText.withValues(alpha: .58),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      );
}

class _RecommendedAppsSection extends StatelessWidget {
  const _RecommendedAppsSection();

  @override
  Widget build(BuildContext context) => _GlassSection(
        title: '推荐APP',
        trailing: '查看更多',
        onTrailing: () => AppBottomSheet.show<void>(
          context: context,
          builder: (context) => const Padding(
            padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '应用推荐',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '这里预留为生活方式类应用推荐位。正式接入推荐配置与应用商店跳转前，不会伪造安装状态或下载动作。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        child: const Row(
          children: [
            Expanded(
              child: _RecommendedApp(
                icon: Icons.spa_rounded,
                iconColor: Color(0xFF70C84D),
                name: '专注森林',
                subtitle: '专注更高效',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _RecommendedApp(
                icon: Icons.cloud_rounded,
                iconColor: Color(0xFF5FA0EF),
                name: '潮汐',
                subtitle: '身心更平静',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _RecommendedApp(
                icon: Icons.check_rounded,
                iconColor: Color(0xFFF25E73),
                name: '习惯打卡',
                subtitle: '小习惯改变',
              ),
            ),
          ],
        ),
      );
}

class _RecommendedApp extends StatelessWidget {
  const _RecommendedApp({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(9, 10, 9, 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? .06 : .31,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 23),
            ),
            const SizedBox(height: 7),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appPrimaryText,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: 8.5,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: context.appPrimarySoft.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '推荐',
                style: TextStyle(
                  color: context.appPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({
    required this.onHelp,
    required this.onSecurity,
    required this.onAbout,
  });

  final VoidCallback onHelp;
  final VoidCallback onSecurity;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) => _GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '更多服务',
              style: TextStyle(
                color: context.appPrimaryText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            _ServiceRow(
              icon: Icons.help_outline_rounded,
              iconColor: const Color(0xFF409CF0),
              title: '帮助与反馈',
              subtitle: '手册 / 反馈',
              onTap: onHelp,
            ),
            _ServiceRow(
              icon: Icons.lock_outline_rounded,
              iconColor: const Color(0xFF4DBE7E),
              title: '安全与隐私',
              subtitle: '备份 / 隐私',
              onTap: onSecurity,
            ),
            _ServiceRow(
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFFFF7A43),
              title: '关于我们',
              subtitle: '版本 / 联系',
              onTap: onAbout,
              divider: false,
            ),
          ],
        ),
      );
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.divider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 2),
            minTileHeight: 54,
            leading: Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: context.appPrimaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appSecondaryText,
                  size: 19,
                ),
              ],
            ),
          ),
          if (divider)
            Divider(
              height: 1,
              indent: 43,
              color: context.appDivider.withValues(alpha: .62),
            ),
        ],
      );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => AppLiquidGlassSurface(
        borderRadius: 25,
        themeColorAccents: false,
        glassOpacity: MediaQuery.highContrastOf(context)
            ? .72
            : Theme.of(context).brightness == Brightness.dark
            ? .24
            : .17,
        padding: padding,
        child: child,
      );
}
