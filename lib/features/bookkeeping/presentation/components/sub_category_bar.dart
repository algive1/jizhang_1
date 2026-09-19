import 'package:flutter/material.dart';

import '../../../../core/models/category.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../../app/theme/app_theme_tokens.dart';

class SubCategoryBar extends StatelessWidget {
  const SubCategoryBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<Category> onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 66 + (MediaQuery.textScalerOf(context).scale(10.5) - 10.5) * 1.6,
    child: ListView.separated(
      key: const ValueKey('quick-subcategory-strip'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, index) => _SubcategoryTile(
        key: ValueKey('quick-subcategory-${categories[index].id}'),
        category: categories[index],
        selected: categories[index].id == selectedId,
        onTap: () => onSelected(categories[index]),
      ),
    ),
  );
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected ? context.appPrimarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? context.appPrimary : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CategoryIcon(
                category: category.name,
                iconKey: category.icon,
                size: 28,
                monochrome: true,
              ),
              const SizedBox(height: 2),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected
                      ? context.appPrimary
                      : context.appSecondaryText,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
