import '../models/book.dart';
import '../models/family.dart';
import '../database/database_seeder.dart';

String formatBookTitle(LedgerBook? book) {
  if (book == null) return '我的账本';

  final name = book.name.trim();
  if (book.id == SeedIds.personalBook ||
      name.isEmpty ||
      _isDefaultBookName(book.type, name)) {
    return _defaultBookTitle(book.type);
  }

  final prefix = String.fromCharCodes(name.runes.take(2));
  return prefix.isEmpty ? _defaultBookTitle(book.type) : '$prefix的账本';
}

String _defaultBookTitle(BookType type) => switch (type) {
  BookType.personal => '我的账本',
  BookType.family => '家庭账本',
  BookType.enterprise => '公司账本',
};

bool _isDefaultBookName(BookType type, String name) => switch (type) {
  BookType.personal => name == '个人账本' || name == '我的账本',
  BookType.family => name == '家庭账本',
  BookType.enterprise => name == '企业账本' || name == '公司账本',
};
