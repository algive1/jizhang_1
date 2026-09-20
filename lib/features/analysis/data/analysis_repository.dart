import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/analysis.dart';
import '../../../core/models/transaction_record.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../intelligence/application/financial_truth_provider.dart';
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
    this.excludedTransactionIds = const {},
  });

  final List<TransactionRecord> _transactions;
  final StatisticalAnalysisService _service;
  final Set<String> excludedTransactionIds;

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
      excludedTransactionIds: excludedTransactionIds,
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

final analysisTransactionsProvider =
    Provider<AsyncValue<List<TransactionRecord>>>((ref) {
      return ref.watch(analysisScopeProvider) == AnalysisScope.allBooks
          ? ref.watch(allTransactionsProvider)
          : ref.watch(transactionsProvider);
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

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  final transactions =
      ref.watch(analysisTransactionsProvider).value ?? const <TransactionRecord>[];
  return LocalAnalysisRepository(
    transactions,
    ref.watch(statisticalAnalysisServiceProvider),
    excludedTransactionIds:
        ref.watch(financialTruthSuppressedTransactionIdsProvider),
  );
});

final analysisSnapshotProvider = Provider<AnalysisSnapshot>((ref) {
  return ref
      .watch(analysisRepositoryProvider)
      .analyze(
        period: ref.watch(analysisPeriodProvider),
        currency: ref.watch(analysisCurrencyProvider),
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
