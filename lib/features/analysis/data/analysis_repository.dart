import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/analysis.dart';
import '../../../core/models/transaction_record.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/statistical_analysis_service.dart';

abstract interface class AnalysisRepository {
  AnalysisSnapshot analyze({
    required AnalysisPeriod period,
    DateTime? now,
    DateTime? month,
    String currency = 'CNY',
  });
}

class LocalAnalysisRepository implements AnalysisRepository {
  const LocalAnalysisRepository(this._transactions, this._service);

  final List<TransactionRecord> _transactions;
  final StatisticalAnalysisService _service;

  @override
  AnalysisSnapshot analyze({
    required AnalysisPeriod period,
    DateTime? now,
    DateTime? month,
    String currency = 'CNY',
  }) {
    return _service.analyze(
      _transactions,
      period: period,
      now: now,
      month: month,
      currency: currency,
    );
  }
}

enum AnalysisScope { currentBook, allBooks }

extension AnalysisScopeLabel on AnalysisScope {
  String get label => switch (this) {
    AnalysisScope.currentBook => '当前账本',
    AnalysisScope.allBooks => '全部账本',
  };
}

class AnalysisScopeController extends Notifier<AnalysisScope> {
  @override
  AnalysisScope build() => AnalysisScope.currentBook;

  void select(AnalysisScope value) => state = value;
}

final analysisScopeProvider =
    NotifierProvider<AnalysisScopeController, AnalysisScope>(
      AnalysisScopeController.new,
    );

typedef AnalysisDataKey = ({
  AnalysisScope scope,
  AnalysisPeriod period,
  DateTime? month,
});

final analysisTransactionsForKeyProvider =
    StreamProvider.family<List<TransactionRecord>, AnalysisDataKey>((
      ref,
      key,
    ) async* {
      await ref.watch(databaseBootstrapProvider.future);
      final now = DateTime.now();
      var start = DateTime(now.year - 1);
      final selectedMonth = key.month;
      if (selectedMonth != null) {
        final comparisonStart = DateTime(
          selectedMonth.year,
          selectedMonth.month - 1,
        );
        if (comparisonStart.isBefore(start)) start = comparisonStart;
      }
      final endExclusive = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      final repository = key.scope == AnalysisScope.allBooks
          ? DriftTransactionRepository(ref.watch(databaseProvider))
          : ref.watch(transactionRepositoryProvider);
      yield* repository.watchRange(
        start: start,
        endExclusive: endExclusive,
      );
    });

final analysisTransactionsProvider =
    Provider<AsyncValue<List<TransactionRecord>>>((ref) {
      return ref.watch(
        analysisTransactionsForKeyProvider((
          scope: ref.watch(analysisScopeProvider),
          period: ref.watch(analysisPeriodProvider),
          month: null,
        )),
      );
    });

class AnalysisPeriodController extends Notifier<AnalysisPeriod> {
  @override
  AnalysisPeriod build() => AnalysisPeriod.currentMonth;

  void select(AnalysisPeriod value) => state = value;
}

final analysisPeriodProvider =
    NotifierProvider<AnalysisPeriodController, AnalysisPeriod>(
      AnalysisPeriodController.new,
    );

final statisticalAnalysisServiceProvider = Provider(
  (ref) => const StatisticalAnalysisService(),
);

typedef AnalysisRepositoryKey = ({
  AnalysisPeriod period,
  DateTime? month,
});

final analysisRepositoryForKeyProvider =
    Provider.family<AnalysisRepository, AnalysisRepositoryKey>((ref, key) {
      final transactions =
          ref
              .watch(
                analysisTransactionsForKeyProvider((
                  scope: ref.watch(analysisScopeProvider),
                  period: key.period,
                  month: key.month,
                )),
              )
              .value ??
          const <TransactionRecord>[];
      return LocalAnalysisRepository(
        transactions,
        ref.watch(statisticalAnalysisServiceProvider),
      );
    });

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return ref.watch(
    analysisRepositoryForKeyProvider((
      period: ref.watch(analysisPeriodProvider),
      month: null,
    )),
  );
});

typedef AnalysisSnapshotKey = ({AnalysisPeriod period, String currency});

final analysisSnapshotForPeriodProvider =
    Provider.family<AnalysisSnapshot, AnalysisSnapshotKey>((ref, key) {
      return ref
          .watch(
            analysisRepositoryForKeyProvider((
              period: key.period,
              month: null,
            )),
          )
          .analyze(period: key.period, currency: key.currency);
    });

final analysisSnapshotProvider = Provider<AnalysisSnapshot>((ref) {
  return ref.watch(
    analysisSnapshotForPeriodProvider((
      period: ref.watch(analysisPeriodProvider),
      currency: ref.watch(analysisCurrencyProvider),
    )),
  );
});

class AnalysisCurrencyController extends Notifier<String> {
  @override
  String build() => 'CNY';
  void select(String value) => state = value;
}

final analysisCurrencyProvider =
    NotifierProvider<AnalysisCurrencyController, String>(
      AnalysisCurrencyController.new,
    );
