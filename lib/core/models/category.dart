enum CategoryType { expense, income }

class Category {
  const Category({
    this.bookId = 'book-personal',
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.sortOrder,
    required this.isDefault,
    required this.isArchived,
    this.parentId,
  });

  final String bookId;
  final String id;
  final String? parentId;
  final String name;
  final String icon;
  final CategoryType type;
  final int sortOrder;
  final bool isDefault;
  final bool isArchived;

  int get displayPriority {
    if (name.trim().startsWith('其他') ||
        id.endsWith('expense-other') ||
        id.endsWith('income-other'))
      return 1;
    if (name.trim() == '餐饮' || id.endsWith('expense-food')) return -1;
    return 0;
  }
}

/// Shared order for grids, selectors and category management.
List<Category> orderCategories(Iterable<Category> categories) {
  final all = categories.toList();
  final roots = all.where((c) => c.parentId == null).toList()
    ..sort(_compareCategories);
  final children = <String, List<Category>>{};
  for (final category in all.where((c) => c.parentId != null)) {
    (children[category.parentId!] ??= []).add(category);
  }
  for (final siblings in children.values) {
    siblings.sort(_compareCategories);
  }
  return [
    for (final root in roots) ...[
      root,
      ...(children.remove(root.id) ?? const <Category>[]),
    ],
    for (final siblings in children.values) ...siblings,
  ];
}

int _compareCategories(Category a, Category b) {
  final type = a.type.index.compareTo(b.type.index);
  if (type != 0) return type;
  final pinned = a.displayPriority.compareTo(b.displayPriority);
  if (pinned != 0) return pinned;
  final order = a.sortOrder.compareTo(b.sortOrder);
  return order != 0 ? order : a.id.compareTo(b.id);
}
