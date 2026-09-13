import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/models/account.dart';
import '../domain/asset_overview.dart';
import 'asset_dashboard_cards.dart';
import 'asset_dashboard_icons.dart';

class AssetLiabilitySection extends StatelessWidget {
  const AssetLiabilitySection({
    required this.accounts,
    required this.hidden,
    required this.onAccounts,
    super.key,
  });
  final List<Account> accounts;
  final bool hidden;
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
              const Expanded(
                child: Text(
                  '负债管理',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: assetInk,
                  ),
                ),
              ),
              InkWell(
                onTap: onAccounts,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '总负债 ',
                      style: TextStyle(fontSize: 10, color: assetMuted),
                    ),
                    AssetAmount(
                      overview.liabilities,
                      currency: overview.currency,
                      hidden: hidden,
                      size: 10,
                      color: assetMuted,
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: assetMuted,
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
                      label: hidden
                          ? '负债率已隐藏'
                          : '负债率 ${(ratio * 100).toStringAsFixed(1)}%',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: hidden ? 0 : ratio,
                          minHeight: 6,
                          color: assetCoral,
                          backgroundColor: const Color(0xfffaeae4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (debts.isEmpty)
                      const SizedBox(
                        height: 40,
                        child: Center(
                          child: Text(
                            '暂无负债账户',
                            style: TextStyle(fontSize: 11, color: assetMuted),
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
                                    color: const Color(0xfffffdfa),
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
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: assetInk,
                                                    ),
                                                  ),
                                                  AssetAmount(
                                                    debt.balance.abs(),
                                                    currency: debt.currency,
                                                    hidden: hidden,
                                                    size: 10,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 12,
                                              color: assetMuted,
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
                    gradient: const LinearGradient(
                      colors: [Color(0xfffff5f0), Color(0xffffeae3)],
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
                      const Expanded(
                        child: Text(
                          '控制负债\n让生活更轻松',
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.45,
                            color: Color(0xff9c5749),
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
