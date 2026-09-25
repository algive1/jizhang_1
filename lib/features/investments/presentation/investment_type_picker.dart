import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';

import '../../../core/widgets/app_bottom_sheet.dart';
import '../domain/investment_asset.dart';

/// Lets the user pick which asset class they are about to add.
///
/// Shared by the 投资管理 header action, the empty state and every 分类持仓页
/// so “+ 添加” always asks the same question the same way.
Future<InvestmentAssetType?> showInvestmentTypePicker(
  BuildContext context, {
  InvestmentAssetType? initial,
}) {
  return AppBottomSheet.show<InvestmentAssetType>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '选择投资类型',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: sheetContext.appPrimaryText,
              ),
            ),
          ),
        ),
        for (final type in InvestmentAssetType.values)
          AppSheetOption(
            key: ValueKey('investment-type-pick-${type.name}'),
            title: type.label,
            subtitle: type == initial ? '当前分类' : '添加一笔${type.label}',
            icon: type.icon,
            selected: type == initial,
            chevron: true,
            onTap: () => Navigator.of(sheetContext).pop(type),
          ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

/// Resolves an `?type=` query value, defaulting to 股票.
InvestmentAssetType assetTypeFromQuery(String? value) {
  if (value == null) return InvestmentAssetType.stock;
  return InvestmentAssetType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => InvestmentAssetType.stock,
  );
}
