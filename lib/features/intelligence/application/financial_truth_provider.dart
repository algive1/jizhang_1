import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/financial_truth_service.dart';

final confirmedEconomicEventTransactionIdsProvider =
    StreamProvider<Map<String, List<String>>>((ref) async* {
      await ref.watch(databaseBootstrapProvider.future);
      yield* ref
          .watch(databaseProvider)
          .intelligenceDao
          .watchConfirmedEconomicEventRecords()
          .map((records) {
            final groups = <String, List<String>>{};
            for (final record in records) {
              groups
                  .putIfAbsent(record.eventId, () => <String>[])
                  .add(record.transactionId);
            }
            return groups;
          });
    });

final financialTruthSuppressedTransactionIdsProvider = Provider<Set<String>>((
  ref,
) {
  final groups =
      ref.watch(confirmedEconomicEventTransactionIdsProvider).value ??
      const <String, List<String>>{};
  if (groups.isEmpty) return const {};
  final transactions =
      ref.watch(allTransactionsProvider).value ?? const [];
  return const FinancialTruthService().confirmedDuplicateSuppressionIds(
    records: transactions,
    confirmedEventTransactionIds: groups,
  );
});
