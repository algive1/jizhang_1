import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/account.dart';
import '../../../core/models/budget.dart';
import '../../../core/models/goal.dart';
import '../../../core/models/recurring_bill.dart';
import '../../../core/models/transaction_record.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../domain/insight_models.dart';

class RemoteInsightRepository {
  const RemoteInsightRepository(this._api, this._session);

  final SharedApi _api;
  final SessionRepository _session;

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
      final response = await _api.request(
        '/insights/analyze',
        method: 'POST',
        body: {
          'bookId': bookId,
          'currency': currency,
          'generatedAt': DateTime.now().millisecondsSinceEpoch,
          'transactions': [
            for (final item in transactions)
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
}

final remoteInsightRepositoryProvider = Provider<RemoteInsightRepository>((ref) {
  return RemoteInsightRepository(
    ref.watch(sharedApiProvider),
    ref.watch(sessionRepositoryProvider),
  );
});
