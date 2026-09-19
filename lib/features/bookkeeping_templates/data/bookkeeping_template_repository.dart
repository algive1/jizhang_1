import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/utils/entity_id.dart';
import '../../books/data/book_repository.dart';

class BookkeepingTemplate {
  const BookkeepingTemplate({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.accountId,
    required this.categoryId,
    required this.sortOrder,
    this.amount,
    this.subcategoryId,
    this.destinationAccountId,
    this.merchant,
    this.note,
  });

  final String id;
  final String bookId;
  final String name;
  final TransactionType type;
  final double? amount;
  final String accountId;
  final String? destinationAccountId;
  final String categoryId;
  final String? subcategoryId;
  final String? merchant;
  final String? note;
  final int sortOrder;

  BookkeepingTemplate copyWith({
    String? name,
    TransactionType? type,
    double? amount,
    bool clearAmount = false,
    String? accountId,
    String? destinationAccountId,
    String? categoryId,
    String? subcategoryId,
    String? merchant,
    String? note,
    int? sortOrder,
  }) => BookkeepingTemplate(
    id: id,
    bookId: bookId,
    name: name ?? this.name,
    type: type ?? this.type,
    amount: clearAmount ? null : amount ?? this.amount,
    accountId: accountId ?? this.accountId,
    destinationAccountId: destinationAccountId ?? this.destinationAccountId,
    categoryId: categoryId ?? this.categoryId,
    subcategoryId: subcategoryId ?? this.subcategoryId,
    merchant: merchant ?? this.merchant,
    note: note ?? this.note,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

abstract interface class BookkeepingTemplateRepository {
  Future<List<BookkeepingTemplate>> list();
  Future<void> save(BookkeepingTemplate template);
  Future<void> delete(String id);
  Future<void> reorder(List<String> ids);
}

class DriftBookkeepingTemplateRepository
    implements BookkeepingTemplateRepository {
  DriftBookkeepingTemplateRepository(this._db, {required this.bookId});

  final AppDatabase _db;
  final String bookId;
  bool _ready = false;

  Future<void> _ensureSchema() async {
    if (_ready) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS bookkeeping_templates(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL,
        account_id TEXT NOT NULL,
        destination_account_id TEXT,
        category_id TEXT NOT NULL,
        subcategory_id TEXT,
        merchant TEXT,
        note TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_bookkeeping_templates_book_sort '
      'ON bookkeeping_templates(book_id, sort_order, updated_at DESC)',
    );
    _ready = true;
  }

  @override
  Future<List<BookkeepingTemplate>> list() async {
    await _ensureSchema();
    final rows = await _db.customSelect(
      'SELECT * FROM bookkeeping_templates WHERE book_id=? '
      'ORDER BY sort_order, updated_at DESC',
      variables: [Variable(bookId)],
    ).get();
    return rows.map((row) => BookkeepingTemplate(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      name: row.read<String>('name'),
      type: TransactionType.values.byName(row.read<String>('type')),
      amount: row.readNullable<double>('amount'),
      accountId: row.read<String>('account_id'),
      destinationAccountId: row.readNullable<String>('destination_account_id'),
      categoryId: row.read<String>('category_id'),
      subcategoryId: row.readNullable<String>('subcategory_id'),
      merchant: row.readNullable<String>('merchant'),
      note: row.readNullable<String>('note'),
      sortOrder: row.read<int>('sort_order'),
    )).toList(growable: false);
  }

  @override
  Future<void> save(BookkeepingTemplate template) async {
    await _ensureSchema();
    if (template.bookId != bookId ||
        template.name.trim().isEmpty ||
        template.accountId.trim().isEmpty ||
        template.categoryId.trim().isEmpty ||
        (template.amount != null && template.amount! <= 0)) {
      throw ArgumentError('记账模板数据无效');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement('''
      INSERT INTO bookkeeping_templates(
        id,book_id,name,type,amount,account_id,destination_account_id,
        category_id,subcategory_id,merchant,note,sort_order,created_at,updated_at
      ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET
        name=excluded.name,
        type=excluded.type,
        amount=excluded.amount,
        account_id=excluded.account_id,
        destination_account_id=excluded.destination_account_id,
        category_id=excluded.category_id,
        subcategory_id=excluded.subcategory_id,
        merchant=excluded.merchant,
        note=excluded.note,
        sort_order=excluded.sort_order,
        updated_at=excluded.updated_at
    ''', [
      template.id,
      template.bookId,
      template.name.trim(),
      template.type.name,
      template.amount,
      template.accountId,
      template.destinationAccountId,
      template.categoryId,
      template.subcategoryId,
      template.merchant?.trim(),
      template.note?.trim(),
      template.sortOrder,
      now,
      now,
    ]);
  }

  @override
  Future<void> delete(String id) async {
    await _ensureSchema();
    await _db.customStatement(
      'DELETE FROM bookkeeping_templates WHERE id=? AND book_id=?',
      [id, bookId],
    );
  }

  @override
  Future<void> reorder(List<String> ids) async {
    await _ensureSchema();
    await _db.transaction(() async {
      for (var index = 0; index < ids.length; index++) {
        await _db.customStatement(
          'UPDATE bookkeeping_templates SET sort_order=?,updated_at=? '
          'WHERE id=? AND book_id=?',
          [index, DateTime.now().millisecondsSinceEpoch, ids[index], bookId],
        );
      }
    });
  }
}

BookkeepingTemplate newBookkeepingTemplate({
  required String bookId,
  required String accountId,
  required String categoryId,
  required int sortOrder,
}) => BookkeepingTemplate(
  id: 'template-${newEntityId()}',
  bookId: bookId,
  name: '常用记账',
  type: TransactionType.expense,
  accountId: accountId,
  categoryId: categoryId,
  sortOrder: sortOrder,
);

final bookkeepingTemplateRepositoryProvider =
    Provider<BookkeepingTemplateRepository>((ref) {
  return DriftBookkeepingTemplateRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});

final bookkeepingTemplatesProvider =
    FutureProvider.autoDispose<List<BookkeepingTemplate>>((ref) {
  return ref.watch(bookkeepingTemplateRepositoryProvider).list();
});
