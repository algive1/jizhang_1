import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_liquid_glass_surface.dart';

class ProfileServicesPage extends StatelessWidget {
  const ProfileServicesPage({super.key});

  static const _groups = <_ServiceGroup>[
    _ServiceGroup(
      '通知与自动化',
      [
        _ServiceItem(Icons.notifications_none_rounded, '通知设置', '系统提醒与消息偏好', '/profile/notification-settings'),
        _ServiceItem(Icons.notifications_active_outlined, '支付通知记账', 'Android 支付通知识别', '/profile/payment-notifications'),
        _ServiceItem(Icons.auto_awesome_outlined, '自动记账', '自动识别与确认规则', '/profile/autobookkeeping'),
      ],
    ),
    _ServiceGroup(
      '数据与隐私',
      [
        _ServiceItem(Icons.cloud_outlined, '数据与安全', '备份、恢复与数据导出', '/profile/data'),
        _ServiceItem(Icons.shield_outlined, '隐私政策', '查看隐私与数据处理说明', '/profile/privacy'),
        _ServiceItem(Icons.description_outlined, '服务协议', '用户、隐私与会员协议', '/profile/legal'),
      ],
    ),
    _ServiceGroup(
      '帮助与支持',
      [
        _ServiceItem(Icons.help_outline_rounded, '使用手册', '常见问题与使用说明', '/profile/help'),
        _ServiceItem(Icons.feedback_outlined, '反馈建议', '提交问题或产品建议', '/profile/feedback'),
        _ServiceItem(Icons.support_agent_rounded, '我的工单', '查看在线支持进度', '/profile/support-tickets'),
      ],
    ),
    _ServiceGroup(
      '关于',
      [
        _ServiceItem(Icons.info_outline_rounded, '关于好好记账', '版本信息、更新与联系我们', '/profile/about'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('更多服务')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          children: [
            for (final group in _groups) ...[
              Text(
                group.title,
                style: TextStyle(
                  color: context.appSecondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              AppLiquidGlassSurface(
                borderRadius: 22,
                themeColorAccents: false,
                glassOpacity: MediaQuery.highContrastOf(context)
                    ? .78
                    : Theme.of(context).brightness == Brightness.dark
                    ? .62
                    : .56,
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  children: [
                    for (var i = 0; i < group.items.length; i++) ...[
                      ListTile(
                        minTileHeight: 52,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: Icon(
                          group.items[i].icon,
                          color: context.appPrimary,
                        ),
                        title: Text(
                          group.items[i].title,
                          style: TextStyle(
                            color: context.appPrimaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          group.items[i].subtitle,
                          style: TextStyle(
                            color: context.appSecondaryText,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: context.appSecondaryText,
                        ),
                        onTap: () => context.push(group.items[i].route),
                      ),
                      if (i != group.items.length - 1)
                        Divider(
                          height: 1,
                          indent: 50,
                          color: context.appDivider.withValues(alpha: .56),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      );
}

class _ServiceGroup {
  const _ServiceGroup(this.title, this.items);

  final String title;
  final List<_ServiceItem> items;
}

class _ServiceItem {
  const _ServiceItem(this.icon, this.title, this.subtitle, this.route);

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
