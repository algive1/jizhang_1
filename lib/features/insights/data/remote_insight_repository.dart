import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/account.dart';
import '../../../core/models/budget.dart';
import '../../../core/models/goal.dart';
import '../../../core/models/recurring_bill.dart';
import '../../../core/models/transaction_record.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../domain/insight_models.dart';

class InsightRemotePolicy {
  const InsightRemotePolicy({
    required this.historyDays,
    required this.aiEnabled,
    required this.aiAvailable,
  });

  final int historyDays;
  final bool aiEnabled;
  final bool aiAvailable;
}

class RemoteInsightRepository {
  RemoteInsightRepository(this._api, this._session);

  final SharedApi _api;
  final SessionRepository _session;
  InsightRemotePolicy? _cachedPolicy;
  DateTime? _policyLoadedAt;

  Future<InsightRemotePolicy?> policy({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _cachedPolicy != null &&
        _policyLoadedAt != null &&
        now.difference(_policyLoadedAt!) < const Duration(minutes: 5)) {
      return _cachedPolicy;
    }
    await _session.initialize();
    if (_session.userId == null || _api.sessionToken == null) return null;
    try {
      final response = await _api.request('/insights/policy');
      final value = InsightRemotePolicy(
        historyDays: (response['historyDays'] as num?)?.toInt() ?? 90,
        aiEnabled: response['aiEnabled'] == true,
        aiAvailable: response['aiAvailable'] == true,
      );
      _cachedPolicy = value;
      _policyLoadedAt = now;
      return value;
    } on SharedApiException catch (error) {
      if (error.status == 401) await _session.markSessionExpired();
      return null;
    } on Object {
      return null;
    }
  }

  Future<InsightFeed?> analyze({
    required String bookId,
    required List<TransactionRecord> transactions,
    required List<Account> accounts,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<RecurringBill> recurringBills,
    String currency = 'CNY',
  }) async {
    await _session.initialize();
    if (_session.userId == null || _api.sessionToken == null) return null;
    try {
      final remotePolicy = await policy();
      final historyDays = remotePolicy?.historyDays ?? 90;
      final cutoff = DateTime.now().subtract(Duration(days: historyDays));
      final scopedTransactions = transactions
          .where((item) => !item.occurredAt.isBefore(cutoff))
          .toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      if (scopedTransactions.length > 6000) {
        scopedTransactions.removeRange(6000, scopedTransactions.length);
      }
      final response = await _api.request(
        '/insights/analyze',
        method: 'POST',
        body: {
          'bookId': bookId,
          'currency': currency,
          'generatedAt': DateTime.now().millisecondsSinceEpoch,
          'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
          'transactions': [
            for (final item in scopedTransactions)
              if (item.deletedAt == null)
                {
                  'id': item.id,
                  'type': item.type.name,
                  'amount': item.amount,
                  'currency': item.currency.toUpperCase(),
                  'categoryId': item.categoryId,
                  'categoryName': item.categoryName,
                  'merchant': item.merchant,
                  'note': item.note,
                  'occurredAt': item.occurredAt.millisecondsSinceEpoch,
                  'source': item.source.name,
                  'aiConfidence': item.aiConfidence,
                  'userCorrected': item.userCorrected,
                  'duplicateConfidence': item.duplicateConfidence,
                  'reimbursementStatus': item.reimbursementStatus.name,
                  'reimbursementAmount': item.reimbursementAmount,
                  'refundAmount': item.refundAmount,
                  'isRecurring': item.isRecurring,
                },
          ],
          'accounts': [
            for (final item in accounts)
              {
                'id': item.id,
                'name': item.name,
                'type': item.type.name,
                'balance': item.balance,
                'currency': item.currency.toUpperCase(),
                'assetForm': item.assetForm.name,
                'isArchived': item.isArchived,
              },
          ],
          'budgets': [
            for (final item in budgets)
              {
                'id': item.id,
                'monthKey': item.monthKey,
                'categoryId': item.categoryId,
                'amount': item.amount,
              },
          ],
          'goals': [
            for (final item in goals)
              {
                'id': item.id,
                'name': item.name,
                'targetAmount': item.targetAmount,
                'currentAmount': item.currentAmount,
                'createdAt': item.createdAt.millisecondsSinceEpoch,
                'targetDate': item.targetDate.millisecondsSinceEpoch,
                'status': item.status.name,
                'monthlyReservation': item.monthlyReservation,
              },
          ],
          'recurringBills': [
            for (final item in recurringBills)
              {
                'id': item.id,
                'name': item.name,
                'type': item.type.name,
                'amount': item.amount,
                'cycle': item.cycle.name,
                'nextDate': item.nextDate.millisecondsSinceEpoch,
                'status': item.status.name,
              },
          ],
        },
      );
      return InsightFeed.fromJson(response);
    } on SharedApiException catch (error) {
      if (error.status == 401) await _session.markSessionExpired();
      return null;
    } on Object {
      return null;
    }
  }

  Future<String?> interpret(FinancialInsightItem item) async {
    await _session.initialize();
    if (_session.userId == null || _api.sessionToken == null) return null;
    final remotePolicy = await policy();
    if (remotePolicy?.aiAvailable != true) return null;
    try {
      final response = await _api.request(
        '/insights/interpret',
        method: 'POST',
        body: {
          'insightId': item.id,
          'kind': item.kind.name,
          'title': item.title,
          'summary': item.summary,
          'analysis': item.analysis,
          'meaning': item.meaning,
          'suggestion': item.suggestion,
          'evidence': [
            for (final evidence in item.evidence)
              {
                'label': evidence.label,
                'value': evidence.value,
                'baselineValue': evidence.baselineValue,
                'unit': evidence.unit,
              },
          ],
        },
      );
      return response['message'] as String?;
    } on SharedApiException catch (error) {
      if (error.status == 401) await _session.markSessionExpired();
      rethrow;
    }
  }
}

final remoteInsightRepositoryProvider = Provider<RemoteInsightRepository>((ref) {
  return RemoteInsightRepository(
    ref.watch(sharedApiProvider),
    ref.watch(sessionRepositoryProvider),
  );
});
