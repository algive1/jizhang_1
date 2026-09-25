import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/models/account.dart';
import '../domain/asset_overview.dart';
import 'asset_dashboard_cards.dart';
import 'asset_dashboard_icons.dart';

class AssetLiabilitySection extends StatelessWidget {
  const AssetLiabilitySection({
    required this.accounts,
    required this.onAccounts,
    super.key,
  });
  final List<Account> accounts;
  final VoidCallback onAccounts;

  @override
  Widget build(BuildContext context) {
    final overview = AssetOverview(accounts.first.currency, accounts);
    final debts = accounts
        .where((account) => account.balance < 0 && !account.isArchived)
        .toList();
    final ratio = overview.assets > 0
        ? (overview.liabilities / overview.assets).clamp(0.0, 1.0)
        : overview.liabilities > 0
        ? 1.0
        : 0.0;
    return AssetPanel(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '负债管理',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.appPrimaryText,
                  ),
                ),
              ),
              InkWell(
                onTap: onAccounts,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '总负债 ',
                      style: TextStyle(fontSize: 10, color: context.appSecondaryText),
                    ),
                    AssetAmount(
                      overview.liabilities,
                      currency: overview.currency,
                      size: 10,
                      color: context.appSecondaryText,
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: context.appSecondaryText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    Semantics(
                      label: '负债率 ${(ratio * 100).toStringAsFixed(1)}%',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          color: assetCoral,
                          backgroundColor: Color.alphaBlend(
                            assetCoral.withValues(alpha: .16),
                            context.appSurfaceSoft,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (debts.isEmpty)
                      SizedBox(
                        height: 40,
                        child: Center(
                          child: Text(
                            '暂无负债账户',
                            style: TextStyle(fontSize: 11, color: context.appSecondaryText),
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, box) {
                          final cardWidth = (box.maxWidth - 6) / 2;
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final debt in debts)
                                SizedBox(
                                  width: cardWidth,
                                  height: 40,
                                  child: Material(
                                    color: context.appSurface,
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      onTap: () => context.push(
                                        '/profile/accounts/${debt.id}',
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            AssetVectorIcon(
                                              accountGlyph(debt),
                                              size: 23,
                                              tile: true,
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    debt.displayName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: context.appPrimaryText,
                                                    ),
                                                  ),
                                                  AssetAmount(
                                                    debt.balance.abs(),
                                                    currency: debt.currency,
                                                    size: 10,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              size: 12,
                                              color: context.appSecondaryText,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [
                        Color.alphaBlend(
                          assetCoral.withValues(alpha: .08),
                          context.appSurface,
                        ),
                        Color.alphaBlend(
                          assetCoral.withValues(alpha: .18),
                          context.appSurfaceSoft,
                        ),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        AppAssets.liabilityPig,
                        width: 42,
                        height: 36,
                        fit: BoxFit.contain,
                      ),
                      Expanded(
                        child: Text(
                          '控制负债\n让生活更轻松',
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.45,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Color.lerp(assetCoral, context.appPrimaryText, .28)!
                                : const Color(0xff9c5749),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
