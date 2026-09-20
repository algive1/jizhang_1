import '../../../core/database/app_database.dart';
import '../../../core/models/transaction_intelligence.dart';
import '../../../core/models/transaction_record.dart';
import '../domain/transaction_fingerprint_service.dart';

class EconomicEventRepository {
  const EconomicEventRepository(this._database, this._fingerprints);

  final AppDatabase _database;
  final TransactionFingerprintService _fingerprints;

  Future<EconomicEvent> createCandidate(
    TransactionRecord first,
    TransactionRecord second,
  ) async {
    if (first.bookId != second.bookId || first.amount != second.amount) {
      throw ArgumentError('Economic event records must share book and amount');
    }
    final now = DateTime.now();
    final event = EconomicEvent(
      id: 'event-${now.microsecondsSinceEpoch}',
      bookId: first.bookId,
      amount: first.amount,
      occurredAt: first.occurredAt.isBefore(second.occurredAt)
          ? first.occurredAt
          : second.occurredAt,
      status: EconomicEventStatus.candidate,
      transactionIds: [first.id, second.id],
      createdAt: now,
      updatedAt: now,
    );
    await _database.transaction(() async {
      await _database.intelligenceDao.insertEconomicEvent(
        EconomicEventEntriesCompanion.insert(
          id: event.id,
          bookId: event.bookId,
          amountInCents: (event.amount * 100).round(),
          occurredAt: event.occurredAt,
          createdAt: now,
          updatedAt: now,
        ),
      );
      for (final transaction in [first, second]) {
        await _database.intelligenceDao.insertEventRecord(
          EconomicEventRecordEntriesCompanion.insert(
            id: '${event.id}-${transaction.id}',
            eventId: event.id,
            transactionId: transaction.id,
            fingerprint: _fingerprints.create(transaction).canonical,
            createdAt: now,
          ),
        );
      }
    });
    return event;
  }

  Future<bool> areLinked(
    String firstTransactionId,
    String secondTransactionId,
  ) async {
    final event = await _database.intelligenceDao
        .findEconomicEventByTransactionId(firstTransactionId);
    if (event == null) return false;
    final records = await _database.intelligenceDao.getEventRecords(event.id);
    return records.any(
      (record) => record.transactionId == secondTransactionId,
    );
  }

  Future<void> resolveCandidateForTransaction(
    String transactionId, {
    required EconomicEventStatus status,
  }) async {
    final event = await _database.intelligenceDao
        .findEconomicEventByTransactionId(transactionId);
    if (event == null) {
      throw StateError('No economic event is linked to $transactionId');
    }
    await _database.intelligenceDao.updateEconomicEventStatus(
      event.id,
      status.name,
      DateTime.now(),
    );
  }
}
