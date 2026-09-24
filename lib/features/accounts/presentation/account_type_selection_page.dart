import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_card.dart';
import 'account_management_visuals.dart';

class AccountTypeSelectionPage extends StatelessWidget {
  const AccountTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                '添加账户',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const AccountLeafPlaceholder(size: 92, opacity: .34),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: Text(
                '选择合适的账户类型\n让每一分钱各归其位',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.appPrimary.withValues(alpha: .62),
                  fontSize: 11,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '请选择账户类型',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '按照资金性质管理，让每一分钱都有归属。',
          style: TextStyle(color: context.appSecondaryText, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _TypeCard(
          icon: Icons.account_balance_wallet_outlined,
          title: '日常资金',
          subtitle: '用于日常收支，可随时使用的资金',
          color: const Color(0xff54A85D),
          onTap: () => context.push('/profile/accounts/add/basic/available'),
        ),
        _TypeCard(
          icon: Icons.toll_outlined,
          title: '储值资金',
          subtitle: '预先充值、存放在平台内的资金',
          color: const Color(0xffE79B3A),
          onTap: () => context.push('/profile/accounts/add/basic/storedValue'),
        ),
        _TypeCard(
          icon: Icons.lock_outline_rounded,
          title: '受限资金',
          subtitle: '在特定条件下才能使用，如保证金、押金',
          color: const Color(0xff5B8DEF),
          onTap: () => context.push('/profile/accounts/add/restricted'),
        ),
        _TypeCard(
          icon: Icons.schedule_rounded,
          title: '应收资金',
          subtitle: '预计将要收回的资金，如报销、退款、待收款',
          color: const Color(0xff8867D8),
          onTap: () => context.push('/profile/accounts/receivables/add'),
        ),
        _TypeCard(
          icon: Icons.grid_view_rounded,
          title: '自定义账户',
          subtitle: '根据个人需要，自定义账户类型',
          color: context.appPrimary,
          onTap: () => context.push('/profile/accounts/add/basic/custom'),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AccountLeafPlaceholder(size: 42, opacity: .28),
            const SizedBox(width: 8),
            Text(
              '好好管理每一份资金\n让生活更从容',
              style: TextStyle(
                color: context.appPrimary.withValues(alpha: .54),
                fontSize: 10,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.appSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.appSecondaryText),
            ],
          ),
        ),
      ),
    ),
  );
}
