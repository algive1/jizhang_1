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
}
