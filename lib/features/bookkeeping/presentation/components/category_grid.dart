import 'sub_category_bar.dart';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/category.dart';
import '../../../../core/widgets/category_icon.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selected,
    required this.subcategories,
    required this.selectedSubcategoryId,
    required this.onSelected,
    required this.onSubcategorySelected,
  });

  final List<Category> categories;
  final Category? selected;
  final List<Category> subcategories;
  final String? selectedSubcategoryId;
  final ValueChanged<Category> onSelected;
  final ValueChanged<Category> onSubcategorySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                          onTap: () => onSelected(category),
                        ),
                    ],
                  ),
                  if (subcategories.isNotEmpty &&
                      categories
                          .skip(start)
                          .take(columns)
                          .any((item) => item.id == selected?.id))
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: SubCategoryBar(
                        categories: subcategories,
                        selectedId: selectedSubcategoryId,
                        onSelected: onSubcategorySelected,
                      ),
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
  });

  final double width;
  final String name;
  final String iconKey;
  final bool selected;
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                AnimatedScale(
                  scale: selected ? 1.06 : 1,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: duration,
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CategoryIcon(
                      category: name,
                      iconKey: iconKey,
                      size: 42,
                      monochrome: true,
                    ),
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
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
