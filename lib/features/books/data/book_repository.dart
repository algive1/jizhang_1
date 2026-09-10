import '../../../core/utils/entity_id.dart';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/database_seeder.dart';
import '../../../core/models/book.dart';
import '../../../core/models/family.dart';
import '../../../core/models/membership.dart';
import '../../membership/data/membership_repository.dart';
import '../../settings/data/app_settings_repository.dart';

abstract final class BookLimitPolicy {
  static const free = 3;
  static const pro = 20;
  static const family = 50;

  static int forPlan(MembershipPlan plan) => switch (plan) {
    MembershipPlan.free => free,
    MembershipPlan.pro => pro,
    MembershipPlan.family => family,
  };
}

abstract interface class BookRepository {
  Stream<List<LedgerBook>> watchForUser(String userId);
  Future<List<LedgerBook>> getForUser(String userId);
  Future<LedgerBook> create({required String name, required BookType type});
  Future<void> rename(String id, String name);
  Future<void> changeType(String id, BookType type);
  Future<void> archive(String id);
}

class DriftBookRepository implements BookRepository {
  DriftBookRepository(this._database, this._membership);

  final AppDatabase _database;
  final MembershipRepository _membership;

  Selectable<QueryRow> _visible(String userId) => _database.customSelect(
    "SELECT b.*,s.role AS shared_role,s.remote_id AS shared_id,s.phase AS shared_phase FROM books b LEFT JOIN sync_books s ON s.book_id=b.id WHERE b.is_archived=0 AND ((b.family_id IS NULL AND b.owner_user_id=?) OR (s.user_id=(SELECT actor_id FROM sync_control WHERE id=1) AND s.access=1)) ORDER BY b.created_at",
    variables: [Variable(userId)],
    readsFrom: {_database.bookEntries},
  );
  LedgerBook _fromRow(QueryRow row) {
    final book = _database.bookEntries.map(row.data);
    return _fromEntity(
      book,
      role: row.readNullable<String>('shared_role'),
      phase: row.readNullable<String>('shared_phase'),
    );
  }

  @override
  Stream<List<LedgerBook>> watchForUser(String userId) =>
      _visible(userId).watch().map((rows) => rows.map(_fromRow).toList());
  @override
  Future<List<LedgerBook>> getForUser(String userId) async =>
      (await _visible(userId).get()).map(_fromRow).toList();

  @override
  Future<LedgerBook> create({
    required String name,
    required BookType type,
  }) async {
    final normalizedName = _validateName(name);
    final membership = await _membership.getCurrent();
    final books = await getForUser(SeedIds.localUser);
    final limit = BookLimitPolicy.forPlan(membership.membership.plan);
    if (books
            .where(
              (b) => !b.isShared || b.ownerUserId == _database.currentActor,
            )
            .length >=
        limit) {
      throw BookLimitReachedException(limit: limit);
    }
    final now = DateTime.now();
    final book = LedgerBook(
      id: 'book-${newEntityId()}',
      name: normalizedName,
      type: type,
      ownerUserId: SeedIds.localUser,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
    );
    await _database.transaction(() async {
      await _database.familyDao.upsertBook(_toCompanion(book));
      await DatabaseSeeder(_database).seedBookDefaults(book.id, type: type);
    });
    return book;
  }

  @override
  Future<void> rename(String id, String name) async {
    final normalizedName = _validateName(name);
    final book = await _database.familyDao.findBook(id);
    if (book == null || book.isArchived) throw StateError('账本不存在');
    await _database.familyDao.renameBook(id, normalizedName, DateTime.now());
  }

  @override
  Future<void> changeType(String id, BookType type) async {
    final book = await _database.familyDao.findBook(id);
    if (book == null || book.isArchived) throw StateError('账本不存在');
    if (id == SeedIds.personalBook || book.familyId != null)
      throw StateError('默认账本或共享账本不能修改类型');
    await _database.transaction(() async {
      await (_database.update(
        _database.bookEntries,
      )..where((b) => b.id.equals(id))).write(
        BookEntriesCompanion(
          type: Value(type.name),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await DatabaseSeeder(_database).ensureBookDefaults(
        id,
        type: type,
        previousType: BookType.values.byName(book.type),
        restoreTarget: true,
      );
    });
  }

  @override
  Future<void> archive(String id) async {
    final book = await _database.familyDao.findBook(id);
    if (book == null || book.isArchived) return;
    if (book.id == SeedIds.personalBook) {
      throw StateError('个人账本不能删除');
    }
    final books = await getForUser(SeedIds.localUser);
    if (books.length <= 1) throw StateError('至少保留一个账本');
    await _database.familyDao.archiveBook(id, DateTime.now());
  }

  String _validateName(String name) {
    final value = name.trim();
    if (value.isEmpty || value.length > 40) {
      throw ArgumentError('账本名称需为 1-40 个字符');
    }
    return value;
  }

  LedgerBook _fromEntity(BookEntity row, {String? role, String? phase}) {
    return LedgerBook(
      id: row.id,
      name: row.name,
      type: BookType.values.byName(row.type),
      ownerUserId: row.ownerUserId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isArchived: row.isArchived,
      sharedId: row.familyId,
      role: role,
      sharedPhase: phase,
    );
  }

  BookEntriesCompanion _toCompanion(LedgerBook book) {
    return BookEntriesCompanion(
      id: Value(book.id),
      name: Value(book.name),
      type: Value(book.type.name),
      ownerUserId: Value(book.ownerUserId),
      createdAt: Value(book.createdAt),
      updatedAt: Value(book.updatedAt),
      isArchived: Value(book.isArchived),
    );
  }
}

class BookLimitReachedException implements Exception {
  const BookLimitReachedException({required this.limit});

  final int limit;

  @override
  String toString() => 'BookLimitReachedException(limit: $limit)';
}

const activeBookIdSettingKey = 'active_book_id';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return DriftBookRepository(
    ref.watch(databaseProvider),
    ref.watch(membershipRepositoryProvider),
  );
});

final booksProvider = StreamProvider<List<LedgerBook>>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  final repository = ref.watch(bookRepositoryProvider);
  final saved = await ref
      .read(appSettingsRepositoryProvider)
      .get(activeBookIdSettingKey);
  var first = true;
  await for (final books in repository.watchForUser(SeedIds.localUser)) {
    final controller = ref.read(activeBookIdProvider.notifier);
    if (first && saved != null && books.any((book) => book.id == saved))
      controller.restore(saved);
    first = false;
    if (books.isNotEmpty &&
        !books.any((book) => book.id == ref.read(activeBookIdProvider)))
      await controller.restoreAvailable(books.first.id);
    yield books;
  }
});

class ActiveBookIdController extends Notifier<String> {
  var _hasExplicitSelection = false;

  @override
  String build() => SeedIds.personalBook;

  Future<void> select(String id) async {
    final books = await ref
        .read(bookRepositoryProvider)
        .getForUser(SeedIds.localUser);
    if (!books.any((b) => b.id == id)) throw StateError('账本不可用');
    _hasExplicitSelection = true;
    await ref
        .read(appSettingsRepositoryProvider)
        .set(activeBookIdSettingKey, id);
    state = id;
  }

  Future<void> restoreAvailable(String id) async {
    state = id;
    await ref
        .read(appSettingsRepositoryProvider)
        .set(activeBookIdSettingKey, id);
  }

  void restore(String id) {
    if (!_hasExplicitSelection && id.isNotEmpty) state = id;
  }
}

final activeBookIdProvider = NotifierProvider<ActiveBookIdController, String>(
  ActiveBookIdController.new,
);

final activeBookProvider = Provider<LedgerBook?>((ref) {
  final books = ref.watch(booksProvider).value ?? const <LedgerBook>[];
  final id = ref.watch(activeBookIdProvider);
  return books.where((book) => book.id == id).firstOrNull;
});
