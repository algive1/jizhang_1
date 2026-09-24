import '../../bookkeeping/application/quick_bookkeeping_service.dart';

class BillImportCommitRecovery {
  const BillImportCommitRecovery({required this.importedCount});

  final int importedCount;

  String get notice =>
      '已导入 $importedCount 笔，但后续处理未全部完成。'
      '流水已保存，请勿重复导入。';
}

/// Refreshes import views when a secondary bookkeeping step failed after the
/// transaction rows were committed. Ordinary write failures remain untouched.
BillImportCommitRecovery? handleCommittedBillImportFailure(
  Object error, {
  required void Function() refresh,
}) {
  if (error is! BookkeepingCommittedException || error.records.isEmpty) {
    return null;
  }
  refresh();
  return BillImportCommitRecovery(importedCount: error.records.length);
}
