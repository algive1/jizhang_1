import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme_tokens.dart';
import '../../../../core/models/category.dart';
import '../../../../core/widgets/category_icon.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selected,
    required this.selectedSubcategoryName,
    required this.onSelected,
  });

  final List<Category> categories;
  final Category? selected;
  final String? selectedSubcategoryName;
  final ValueChanged<Category> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.appUsesLiquidGlass
            ? context.appSurface.withValues(alpha: .82)
            : context.appSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.appDivider.withValues(
            alpha: context.appUsesLiquidGlass ? .72 : .42,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(14) > 19
              ? 4
              : 5;
          return SingleChildScrollView(
            key: const ValueKey('quick-category-section'),
            child: Column(
              children: [
                for (
                  var start = 0;
                  start < categories.length;
                  start += columns
                )
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final category
                          in categories.skip(start).take(columns))
                        _CategoryTile(
                          key: ValueKey('quick-category-${category.id}'),
                          width: constraints.maxWidth / columns,
                          name: category.name,
                          iconKey: category.icon,
                          selected: selected?.id == category.id,
                          selectedSubcategoryName:
                              selected?.id == category.id
                              ? selectedSubcategoryName
                              : null,
                          onTap: () => onSelected(category),
                        ),
                    ],
                  ),
                if (categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('暂无可用分类，请先在分类管理中添加'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.width,
    required this.name,
    required this.iconKey,
    required this.selected,
    required this.selectedSubcategoryName,
    required this.onTap,
  });

  final double width;
  final String name;
  final String iconKey;
  final bool selected;
  final String? selectedSubcategoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return SizedBox(
      width: width,
      child: Semantics(
        selected: selected,
        button: true,
        label: selectedSubcategoryName == null
            ? name
            : '$name，二级分类 $selectedSubcategoryName',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: duration,
            decoration: BoxDecoration(
              color: selected
                  ? context.appPrimarySoft
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            child: Column(
              children: [
                AnimatedScale(
                  scale: selected ? 1.06 : 1,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: CategoryIcon(
                    category: name,
                    iconKey: iconKey,
                    size: 42,
                    monochrome: true,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? context.appPrimary
                        : context.appPrimaryText,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (selectedSubcategoryName != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    selectedSubcategoryName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: context.appSecondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
