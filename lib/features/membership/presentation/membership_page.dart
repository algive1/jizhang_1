import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/membership.dart';
import '../../../core/widgets/app_card.dart';
import '../data/membership_repository.dart';

class MembershipPage extends ConsumerWidget {
  const MembershipPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(membershipProvider).value;
    final currentPlan = snapshot?.membership.plan ?? MembershipPlan.free;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    IconButton(
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '会员与数据安全',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppCard(
                  color: AppColors.primarySoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${currentPlan.label} 方案',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '当前数据保存在本机，可导出流水 CSV 和完整备份；完整备份恢复需重启应用。云同步暂未开放。',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '功能开放情况',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  title: 'Free',
                  subtitle: '安心完成日常记录',
                  features: const ['本地记账', '流水 CSV 导出', '资产与收支分析'],
                  current: currentPlan == MembershipPlan.free,
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  title: 'Pro',
                  subtitle: '数据安全与效率能力',
                  features: const ['自动云备份与多设备同步', 'AI 分析与语音额度', '无广告'],
                  current: currentPlan == MembershipPlan.pro,
                  unavailable: true,
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  title: 'Family',
                  subtitle: '共同管理家庭生活目标',
                  features: const ['包含 Pro 权益', '扩展家庭管理能力（筹备中）'],
                  current: currentPlan == MembershipPlan.family,
                  unavailable: true,
                ),
                const SizedBox(height: 16),
                const AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pro 和 Family 仍在筹备，暂不支持购买。基础家庭和企业共享只需登录，不依赖会员。已记录的本地数据可继续查看与导出。',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.current,
    this.unavailable = false,
  });

  final String title;
  final String subtitle;
  final List<String> features;
  final bool current;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      border: Border.all(
        color: current ? AppColors.primary : AppColors.divider,
        width: current ? 1.5 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (current)
                const Chip(
                  label: Text('当前方案'),
                  backgroundColor: AppColors.primarySoft,
                  side: BorderSide.none,
                )
              else if (unavailable)
                const Text(
                  '暂未开放购买',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  const Icon(Icons.check, color: AppColors.primary, size: 19),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
