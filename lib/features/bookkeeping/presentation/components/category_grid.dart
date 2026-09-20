import 'package:flutter/material.dart';

import '../../../../core/models/category.dart';
import '../../../../core/widgets/app_glass_surface.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../../app/theme/app_theme_tokens.dart';

typedef CategoryGridSelection = void Function(
  Category category,
  Rect anchorRect,
);

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selected,
    required this.subcategories,
    required this.selectedSubcategoryId,
    required this.onSelected,
  });

  final List<Category> categories;
  final Category? selected;
  final List<Category> subcategories;
  final String? selectedSubcategoryId;
  final CategoryGridSelection onSelected;

  @override
  Widget build(BuildContext context) {
    Category? selectedSubcategory;
    for (final category in subcategories) {
      if (category.id == selectedSubcategoryId) {
        selectedSubcategory = category;
        break;
      }
    }
    return AppGlassSurface(
      padding: const EdgeInsets.all(6),
      borderRadius: 24,
      tint: context.appSurface,
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
                ) ...[
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
                          subtitle: selected?.id == category.id
                              ? selectedSubcategory?.name
                              : null,
                          onTap: (anchorRect) =>
                              onSelected(category, anchorRect),
                        ),
                    ],
                  ),
                ],
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
    required this.onTap,
    this.subtitle,
  });

  final double width;
  final String name;
  final String iconKey;
  final bool selected;
  final String? subtitle;
  final ValueChanged<Rect> onTap;

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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final renderObject = context.findRenderObject();
            if (renderObject is! RenderBox || !renderObject.hasSize) return;
            final topLeft = renderObject.localToGlobal(Offset.zero);
            onTap(topLeft & renderObject.size);
          },
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? context.appPrimarySoft.withValues(
                      alpha: context.appUsesLiquidGlass ? .58 : 1,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
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
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
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
