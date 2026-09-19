import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/models/membership.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/profile_stats.dart';
import '../../../app/theme/app_theme_tokens.dart';

const profileCream = Color(0xFFF7F7ED);
const profileSurface = Color(0xFFFFFEF9);

class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.name,
    required this.days,
    required this.onTap,
  });
  final String name;
  final String days;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
      return SizedBox(
        height: largeText ? 165 : 94,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                right: -28,
                bottom: -29,
                width: c.maxWidth * .73,
                child: IgnorePointer(
                  child: Image.asset(AppAssets.profileHeaderScene),
                ),
              ),
              Positioned(
                right: 66,
                top: 0,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: -.17,
                    child: Text(
                      '好好花钱\n  也好好生活 ♥',
                      style: TextStyle(
                        color: context.appPrimary,
                        fontSize: 12,
                        height: 1.4,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: c.maxWidth * .69,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const UserAvatar(radius: 29),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        height: 1.4,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '♧  记录生活 更好地生活',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.appSecondaryText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '▣  已记账 $days 天',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.appSecondaryText,
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
            ],
          ),
        ),
      );
    },
  );
}

class ProfileMembershipCard extends StatelessWidget {
  const ProfileMembershipCard({
    super.key,
    required this.snapshot,
    required this.onTap,
  });
  final MembershipSnapshot? snapshot;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final sub = snapshot?.subscription;
    final now = DateTime.now();
    final active = sub?.isActiveAt(now) ?? false;
    final days = sub == null
        ? 0
        : sub.expiresAt.difference(now).inDays.clamp(0, 99999);
    final duration = sub?.expiresAt.difference(sub.startedAt).inSeconds ?? 0;
    final progress = duration <= 0
        ? 0.0
        : (sub!.expiresAt.difference(now).inSeconds / duration).clamp(0.0, 1.0);
    final plan = snapshot?.membership.plan;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFEFD9A5), Color(0xFFFCF4DE)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x086F743A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA48A50), Color(0xFF67512A)],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFFF4D0),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFFFE7A2),
                  size: 31,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan == null
                                ? '会员状态加载中'
                                : plan == MembershipPlan.free
                                ? '普通会员'
                                : '${plan.label} 会员',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF67512A),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Color(0xFF67512A),
                        ),
                        TextButton(
                          onPressed: onTap,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF735C30),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            active ? '立即续费' : '查看权益',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '解锁更多高级功能，让记账更简单',
                      style: TextStyle(fontSize: 11, color: Color(0xFF77633D)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      sub == null
                          ? '本地免费方案 · 暂无付费订阅'
                          : '${DateFormat('yyyy-MM-dd').format(sub.expiresAt)} 到期 · ${active ? '还有 $days 天' : '已到期'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF77633D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(8),
                      color: context.appPrimary,
                      backgroundColor: const Color(0xFFFBF6E7),
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

class ProfileQuickStat extends StatelessWidget {
  const ProfileQuickStat({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String value, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: profileSurface,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.appPrimaryText,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$label ›',
                style: TextStyle(
                  fontSize: 11,
                  color: context.appSecondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileMonthlyCard extends StatelessWidget {
  const ProfileMonthlyCard({
    super.key,
    required this.activity,
    required this.onTap,
    this.loading = false,
  });
  final ProfileActivity activity;
  final VoidCallback onTap;
  final bool loading;
  @override
  Widget build(BuildContext context) => Material(
    color: context.appSurfaceSoft,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                AppAssets.monthlyProgressScene,
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 12,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -.15,
                child: Text(
                  '小小坚持\n  大大改变',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(17),
            child: FractionallySizedBox(
              widthFactor: .65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        '本月记账进度',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        loading
                            ? '加载中'
                            : '已记 ${activity.recordedDays} 天 / ${activity.monthDays} 天',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.appSecondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: loading
                        ? 0
                        : activity.recordedDays / activity.monthDays,
                    minHeight: 11,
                    borderRadius: BorderRadius.circular(10),
                    color: context.appPrimary,
                    backgroundColor: context.appDivider,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '坚持下去，遇见更好的自己！',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.appSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ProfileMenuItem {
  const ProfileMenuItem(this.icon, this.label, this.value, this.onTap);
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
}

class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({super.key, required this.items});
  final List<ProfileMenuItem> items;
  @override
  Widget build(BuildContext context) => Material(
    color: profileSurface,
    borderRadius: BorderRadius.circular(19),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            InkWell(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(items[i].icon, size: 23, color: context.appPrimary),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 5,
                      child: Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.appPrimaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              items[i].value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appSecondaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.chevron_right,
                            size: 21,
                            color: context.appSecondaryText,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                thickness: .5,
                indent: 41,
                color: context.appDivider,
              ),
          ],
        ],
      ),
    ),
  );
}
