import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/transaction_record.dart';

class ProfileActivity {
  factory ProfileActivity(
    List<TransactionRecord> transactions,
    DateTime now,
  ) {
    return ProfileActivity.fromDates(
      transactions
          .where((t) => t.deletedAt == null && !t.occurredAt.isAfter(now))
          .map((t) => t.occurredAt),
      now,
    );
  }

  ProfileActivity.fromDates(Iterable<DateTime> occurredDates, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final dates = occurredDates
        .map((value) => DateTime(value.year, value.month, value.day))
        .where((value) => !value.isAfter(today))
        .toSet();
    monthDays = DateTime(now.year, now.month + 1, 0).day;
    recordedDays = dates
        .where((d) => d.year == now.year && d.month == now.month)
        .length;
    final firstRecordedDay = dates.isEmpty
        ? null
        : dates.reduce((a, b) => a.isBefore(b) ? a : b);
    bookkeepingDays = firstRecordedDay == null
        ? 0
        : today.difference(firstRecordedDay).inDays + 1;
    var cursor = dates.contains(today)
        ? today
        : DateTime(today.year, today.month, today.day - 1);
    while (dates.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
  }

  int streak = 0;
  late final int monthDays;
  late final int recordedDays;
  late final int bookkeepingDays;
}

typedef ProfileMonthSummary = ({
  double income,
  double expense,
});

final profileActivityProvider =
    StreamProvider.family<ProfileActivity, String?>((ref, bookId) async* {
      await ref.watch(databaseBootstrapProvider.future);
      yield* ref
          .watch(databaseProvider)
          .transactionDao
          .watchActiveOccurredDays(bookId: bookId)
          .map((dates) => ProfileActivity.fromDates(dates, DateTime.now()));
    });

typedef ProfileMonthSummaryKey = ({
  String bookId,
  int year,
  int month,
});

final profileMonthSummaryProvider =
    StreamProvider.family<ProfileMonthSummary, ProfileMonthSummaryKey>((
      ref,
      key,
    ) async* {
      await ref.watch(databaseBootstrapProvider.future);
      final now = DateTime.now();
      yield* ref
          .watch(databaseProvider)
          .transactionDao
          .watchMonthSummary(
            bookId: key.bookId,
            start: DateTime(key.year, key.month),
            endExclusive: DateTime(key.year, key.month + 1),
            now: now,
          )
          .map(
            (value) => (
              income: value.incomeCents / 100,
              expense: value.personalExpenseCents / 100,
            ),
          );
    });

final profilePhotoCountProvider = StreamProvider<int>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  final db = ref.watch(databaseProvider);
  final raw = db.customSelect(
    '''
    SELECT COUNT(*) AS photo_count
    FROM transaction_attachments AS a
    INNER JOIN transactions AS t
      ON t.id = a.transaction_id
      AND t.book_id = a.book_id
    WHERE a.deleted_at IS NULL
      AND t.deleted_at IS NULL
      AND a.mime_type LIKE 'image/%'
    ''',
    readsFrom: {
      db.transactionAttachmentEntries,
      db.transactionEntries,
    },
  );
  yield* raw.watchSingle().map((row) => row.read<int>('photo_count'));
});

// Join to live transactions so soft-deleted records never inflate the photo count.
final profilePhotosProvider = StreamProvider<List<TransactionAttachmentEntity>>(
  (ref) async* {
    await ref.watch(databaseBootstrapProvider.future);
    final db = ref.watch(databaseProvider);
    final a = db.transactionAttachmentEntries;
    final t = db.transactionEntries;
    final query =
        db.select(a).join([
          innerJoin(
            t,
            t.id.equalsExp(a.transactionId) & t.bookId.equalsExp(a.bookId),
          ),
        ])..where(
          a.deletedAt.isNull() &
              t.deletedAt.isNull() &
              a.mimeType.like('image/%'),
        );
    yield* query.watch().map(
      (rows) => rows.map((row) => row.readTable(a)).toList(),
    );
  },
);
