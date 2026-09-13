import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/formatters/book_title_formatter.dart';
import 'package:jizhang_app/core/models/book.dart';
import 'package:jizhang_app/core/models/family.dart';

void main() {
  final createdAt = DateTime(2026, 9, 11);

  LedgerBook book({required String name, required BookType type}) {
    return LedgerBook(
      id: '$type-$name',
      name: name,
      type: type,
      ownerUserId: 'user-local',
      createdAt: createdAt,
      updatedAt: createdAt,
      isArchived: false,
    );
  }

  test('uses the personal fallback when there is no active book', () {
    expect(formatBookTitle(null), '我的账本');
  });

  test('uses friendly titles for default book names', () {
    expect(
      formatBookTitle(book(name: '个人账本', type: BookType.personal)),
      '我的账本',
    );
    expect(formatBookTitle(book(name: '家庭账本', type: BookType.family)), '家庭账本');
    expect(
      formatBookTitle(book(name: '企业账本', type: BookType.enterprise)),
      '公司账本',
    );
    expect(
      formatBookTitle(book(name: '公司账本', type: BookType.enterprise)),
      '公司账本',
    );
  });

  test('recognizes the seeded personal book even after legacy renaming', () {
    expect(
      formatBookTitle(
        LedgerBook(
          id: 'book-personal',
          name: '个人',
          type: BookType.personal,
          ownerUserId: 'user-local',
          createdAt: createdAt,
          updatedAt: createdAt,
          isArchived: false,
        ),
      ),
      '我的账本',
    );
  });

  test(
    'formats custom names with at most two characters and no type suffix',
    () {
      expect(
        formatBookTitle(book(name: '旅行', type: BookType.personal)),
        '旅行的账本',
      );
      expect(
        formatBookTitle(book(name: '旅行账本', type: BookType.family)),
        '旅行的账本',
      );
      expect(
        formatBookTitle(book(name: '家', type: BookType.enterprise)),
        '家的账本',
      );
    },
  );

  test('trims custom names and falls back for blank names', () {
    expect(
      formatBookTitle(book(name: '  小米公司  ', type: BookType.enterprise)),
      '小米的账本',
    );
    expect(formatBookTitle(book(name: '   ', type: BookType.family)), '家庭账本');
  });
}
