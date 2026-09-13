import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/entity_id.dart';
import '../domain/transaction_attachment.dart';

abstract interface class TransactionAttachmentRepository {
  Stream<List<TransactionAttachment>> watchForTransaction(
    String transactionId, {
    required String bookId,
  });

  Future<List<TransactionAttachment>> getForTransaction(
    String transactionId, {
    required String bookId,
  });

  Future<void> replaceForTransaction({
    required String transactionId,
    required String bookId,
    required List<String> paths,
  });
}

class DriftTransactionAttachmentRepository
    implements TransactionAttachmentRepository {
  DriftTransactionAttachmentRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<TransactionAttachment>> watchForTransaction(
    String transactionId, {
    required String bookId,
  }) {
    return _database.transactionAttachmentDao
        .watchActiveForTransaction(transactionId, bookId: bookId)
        .map(_mapEntities);
  }

  @override
  Future<List<TransactionAttachment>> getForTransaction(
    String transactionId, {
    required String bookId,
  }) async {
    final entities = await _database.transactionAttachmentDao.getForTransaction(
      transactionId,
      bookId: bookId,
    );
    return _mapEntities(entities);
  }

  @override
  Future<void> replaceForTransaction({
    required String transactionId,
    required String bookId,
    required List<String> paths,
  }) async {
    final normalizedPaths = <String>[];
    for (final path in paths) {
      final normalized = path.trim();
      if (normalized.isNotEmpty && !normalizedPaths.contains(normalized)) {
        normalizedPaths.add(normalized);
      }
    }
    if (normalizedPaths.length > 4) {
      throw ArgumentError('一笔流水最多保留 4 个附件');
    }

    await _database.transaction(() async {
      final transaction = await _database.transactionDao.findActiveById(
        transactionId,
        bookId: bookId,
      );
      if (transaction == null) {
        throw StateError('流水不存在或不属于当前账本');
      }
      final existing = await _database.transactionAttachmentDao
          .getForTransaction(
            transactionId,
            bookId: bookId,
            includeDeleted: true,
          );
      final existingByPath = <String, TransactionAttachmentEntity>{};
      for (final entity in existing) {
        existingByPath.putIfAbsent(entity.path, () => entity);
      }

      final now = DateTime.now();
      for (final entity in existing.where(
        (item) =>
            item.deletedAt == null && !normalizedPaths.contains(item.path),
      )) {
        await _database.transactionAttachmentDao.replaceOne(
          _toCompanion(entity, deletedAt: now, updatedAt: now),
        );
      }
      for (var index = 0; index < normalizedPaths.length; index++) {
        final path = normalizedPaths[index];
        final entity = existingByPath[path];
        if (entity == null) {
          await _database.transactionAttachmentDao.insertOne(
            _newCompanion(
              transactionId: transactionId,
              bookId: bookId,
              path: path,
              sortOrder: index,
              now: now.add(Duration(microseconds: index)),
            ),
          );
        } else if (entity.deletedAt != null || entity.sortOrder != index) {
          await _database.transactionAttachmentDao.replaceOne(
            _toCompanion(
              entity,
              deletedAt: null,
              sortOrder: index,
              updatedAt: now,
            ),
          );
        }
      }
    });
  }

  List<TransactionAttachment> _mapEntities(
    List<TransactionAttachmentEntity> entities,
  ) {
    return List.unmodifiable(
      entities.map(
        (entity) => TransactionAttachment(
          id: entity.id,
          bookId: entity.bookId,
          transactionId: entity.transactionId,
          path: entity.path,
          displayName: entity.name,
          mimeType: entity.mimeType,
          sortOrder: entity.sortOrder,
          sizeInBytes: entity.sizeInBytes,
          checksum: entity.checksum,
          createdAt: entity.createdAt,
          updatedAt: entity.updatedAt,
        ),
      ),
    );
  }

  TransactionAttachmentEntriesCompanion _newCompanion({
    required String transactionId,
    required String bookId,
    required String path,
    required int sortOrder,
    required DateTime now,
  }) {
    return TransactionAttachmentEntriesCompanion(
      id: Value('attachment-${newEntityId()}'),
      bookId: Value(bookId),
      transactionId: Value(transactionId),
      path: Value(path),
      name: Value(_name(path)),
      mimeType: Value(attachmentMimeType(path)),
      sortOrder: Value(sortOrder),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }

  TransactionAttachmentEntriesCompanion _toCompanion(
    TransactionAttachmentEntity entity, {
    required DateTime? deletedAt,
    int? sortOrder,
    required DateTime updatedAt,
  }) {
    return TransactionAttachmentEntriesCompanion(
      id: Value(entity.id),
      bookId: Value(entity.bookId),
      transactionId: Value(entity.transactionId),
      path: Value(entity.path),
      name: Value(entity.name),
      mimeType: Value(entity.mimeType),
      sortOrder: Value(sortOrder ?? entity.sortOrder),
      sizeInBytes: Value(entity.sizeInBytes),
      checksum: Value(entity.checksum),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: Value(deletedAt),
    );
  }

  String _name(String path) {
    final value = p.basename(path).trim();
    return value.isEmpty || value == '.' ? '未命名附件' : value;
  }
}

final transactionAttachmentRepositoryProvider =
    Provider<TransactionAttachmentRepository>((ref) {
      return DriftTransactionAttachmentRepository(ref.watch(databaseProvider));
    });
