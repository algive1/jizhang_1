import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import 'asset_dashboard_icons.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/widgets/privacy_amount.dart';

const assetInk = Color(0xFF152018);
const assetGreen = Color(0xFF436B28);
const assetMuted = Color(0xFF888C88);
const assetCream = Color(0xFFF5F6EB);
const assetCoral = Color(0xFFF18475);

class AssetPanel extends StatelessWidget {
  const AssetPanel({
    required this.child,
    this.padding = const EdgeInsets.all(10),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xF5FFFFFC),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class AssetAmount extends StatelessWidget {
  const AssetAmount(
    this.value, {
    this.currency = 'CNY',
    this.hidden = false,
    this.size = 18,
    this.color = assetInk,
    this.signed = false,
    super.key,
  });
  final double value;
  final String currency;
  final bool hidden, signed;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => PrivacyAmount(
    text:
        '${value < 0
            ? '-'
            : signed && value > 0
            ? '+'
            : ''}'
        '${currency == 'CNY' ? '¥' : '$currency '}${MoneyFormatter.decimal(value.abs())}',
    hidden: hidden,
    fit: true,
    style: TextStyle(
      fontSize: size,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w800,
      color: color,
      height: 1.15,
    ),
  );
}

IconData assetAccountIcon(Account account) => switch (account.type) {
  AccountType.cash => Icons.account_balance_wallet_outlined,
  AccountType.debitCard => Icons.account_balance_outlined,
  AccountType.creditCard => Icons.credit_card,
  AccountType.liability => Icons.account_balance,
  AccountType.alipay || AccountType.wechat => Icons.account_balance_wallet,
  AccountType.other =>
    account.assetForm == AssetForm.investment
        ? Icons.trending_up
        : Icons.home_outlined,
};

class AssetShortcuts extends StatelessWidget {
  const AssetShortcuts({
    required this.accountCount,
    required this.onAccounts,
    required this.onInvestments,
    required this.onTransfers,
    required this.onReport,
    super.key,
  });
  final int accountCount;
  final VoidCallback onAccounts, onInvestments, onTransfers, onReport;
  @override
  Widget build(BuildContext context) {
    final items = [
      (AssetGlyph.wallet, '账户管理', '$accountCount 个账户', onAccounts),
      // Replaces the former 分类统计 entry. Same card size, radius, spacing and
      // icon container — only the label and glyph changed.
      (AssetGlyph.growth, '投资管理', '股票·基金·债券', onInvestments),
      (AssetGlyph.transfer, '转账管理', '资产互转', onTransfers),
      (AssetGlyph.pie, '资产报表', '多维分析', onReport),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        const columns = 4;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in items)
              SizedBox(
                width: (box.maxWidth - (columns - 1) * 6) / columns,
                child: Material(
                  color: const Color(0xF5FFFFFC),
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: item.$4,
                    borderRadius: BorderRadius.circular(17),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 10,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: AssetVectorIcon(item.$1, size: 19),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontSize: 12,
                              color: assetInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.$3,
                            style: const TextStyle(
                              fontSize: 11,
                              color: assetMuted,
                            ),
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
    );
  }
}

class AssetSectionHeading extends StatelessWidget {
  const AssetSectionHeading(
    this.title, {
    this.action,
    this.onTap,
    this.more = false,
    this.fontSize = 16,
    super.key,
  });
  final String title;
  final String? action;
  final VoidCallback? onTap;
  final bool more;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: assetInk,
          ),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: assetMuted,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 24),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '$action ›',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      if (more) const Icon(Icons.more_horiz, size: 20, color: assetInk),
    ],
  );
}
