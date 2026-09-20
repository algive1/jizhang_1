import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../insights/domain/insight_models.dart';
import '../../../app/theme/app_theme_tokens.dart';

class HomeCrownIcon extends StatelessWidget {
  const HomeCrownIcon({this.color = const Color(0xFFC49A43), super.key});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.workspace_premium_outlined, color: color, size: 22);
}

class HomeInsightCard extends StatelessWidget {
  const HomeInsightCard({
    required this.insight,
    this.amountHidden = false,
    required this.onTap,
    super.key,
  });
  final FinancialInsightItem insight;
  final bool amountHidden;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.eco_outlined,
                        color: context.appPrimary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '值得关注',
                        style: TextStyle(
                          color: context.appSecondaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE4D8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.nightlight_round,
                          color: Color(0xFFEE673A),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: TextStyle(
                                fontSize: 15,
                                color: context.appPrimaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              insight.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appSecondaryText,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.appSecondaryText,
              size: 26,
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeProCard extends StatelessWidget {
  const HomeProCard({required this.onTap, super.key});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF1F6DF),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: Stack(
          children: [
            Positioned(
              right: 8,
              top: 10,
              bottom: 8,
              width: 90,
              child: IgnorePointer(
                child: Opacity(
                  opacity: .7,
                  child: Image.asset(AppAssets.proCloud, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HomeCrownIcon(color: context.appPrimary),
                      const SizedBox(width: 5),
                      Text(
                        '升级为 Pro',
                        style: TextStyle(
                          color: context.appPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '让账本多一份安全感',
                    style: TextStyle(
                      color: context.appPrimaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pro 将提供自动云备份、多设备同步与无广告体验。',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 11,
                    ),
                  ),
                  FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.appPrimary,
                      minimumSize: const Size(84, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text('了解 Pro'),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 14,
              top: 48,
              child: Icon(
                Icons.chevron_right,
                color: context.appSecondaryText,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
