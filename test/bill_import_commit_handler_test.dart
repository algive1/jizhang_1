import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/bill_import/application/bill_import_commit_handler.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';

void main() {
  test('committed bookkeeping failures refresh imported transaction views', () {
    var refreshCount = 0;
    final record = TransactionRecord(
      id: 'already-saved',
      bookId: 'book',
      type: TransactionType.expense,
      amount: 88,
      accountId: 'cash',
      occurredAt: DateTime(2026, 9, 24),
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
      source: TransactionSource.import,
    );

    final recovery = handleCommittedBillImportFailure(
      BookkeepingCommittedException(
        records: [record],
        cause: StateError('secondary write failed'),
        stage: 'secondary local processing',
        stackTrace: StackTrace.current,
      ),
      refresh: () => refreshCount++,
    );

    expect(refreshCount, 1);
    expect(recovery?.importedCount, 1);
    expect(recovery?.notice, contains('请勿重复导入'));
  });

  test('uncommitted failures do not refresh imported transaction views', () {
    var refreshCount = 0;

    final recovery = handleCommittedBillImportFailure(
      StateError('transaction write failed'),
      refresh: () => refreshCount++,
    );

    expect(refreshCount, 0);
    expect(recovery, isNull);
  });
}
