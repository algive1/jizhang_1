import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/analysis.dart';
import '../../../core/models/transaction_record.dart';
import '../../books/data/book_repository.dart';
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
  const LocalAnalysisRepository(
    this._transactions,
    this._service, {
    this.largeExpenseThreshold,
  });

  final List<TransactionRecord> _transactions;
  final StatisticalAnalysisService _service;
  final double? largeExpenseThreshold;

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
      largeExpenseThreshold: largeExpenseThreshold,
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
      final service = ref.watch(statisticalAnalysisServiceProvider);
      final now = DateTime.now();
      final sourceRanges = service.sourceRangesFor(
        period: key.period,
        now: now,
        month: key.month,
      );
      final repository = key.scope == AnalysisScope.allBooks
          ? DriftTransactionRepository(ref.watch(databaseProvider))
          : ref.watch(transactionRepositoryProvider);
      yield* repository.watchRanges(
        ranges: [
          for (final range in sourceRanges)
            (start: range.start, endExclusive: range.endExclusive),
        ],
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

final analysisCurrenciesProvider =
    StreamProvider.family<List<String>, AnalysisScope>((ref, scope) async* {
      await ref.watch(databaseBootstrapProvider.future);
      final bookId = scope == AnalysisScope.currentBook
          ? ref.watch(activeBookIdProvider)
          : null;
      yield* ref
          .watch(databaseProvider)
          .transactionDao
          .watchActiveCurrencies(bookId: bookId);
    });

typedef AnalysisThresholdKey = ({
  AnalysisScope scope,
  String currency,
});

final analysisLargeExpenseThresholdProvider =
    StreamProvider.family<double, AnalysisThresholdKey>((ref, key) async* {
      await ref.watch(databaseBootstrapProvider.future);
      final bookId = key.scope == AnalysisScope.currentBook
          ? ref.watch(activeBookIdProvider)
          : null;
      yield* ref
          .watch(databaseProvider)
          .transactionDao
          .watchLargeExpenseThresholdInCents(
            bookId: bookId,
            currency: key.currency,
          )
          .map((cents) => cents / 100);
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
  String currency,
});

final analysisRepositoryForKeyProvider =
    Provider.family<AnalysisRepository, AnalysisRepositoryKey>((ref, key) {
      final scope = ref.watch(analysisScopeProvider);
      final transactions =
          ref
              .watch(
                analysisTransactionsForKeyProvider((
                  scope: scope,
                  period: key.period,
                  month: key.month,
                )),
              )
              .value ??
          const <TransactionRecord>[];
      final threshold = ref
          .watch(
            analysisLargeExpenseThresholdProvider((
              scope: scope,
              currency: key.currency,
            )),
          )
          .value;
      return LocalAnalysisRepository(
        transactions,
        ref.watch(statisticalAnalysisServiceProvider),
        largeExpenseThreshold: threshold,
      );
    });

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return ref.watch(
    analysisRepositoryForKeyProvider((
      period: ref.watch(analysisPeriodProvider),
      month: null,
      currency: ref.watch(analysisCurrencyProvider),
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
              currency: key.currency,
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
