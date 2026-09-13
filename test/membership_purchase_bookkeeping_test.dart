import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/bookkeeping/application/quick_bookkeeping_service.dart';
import 'package:jizhang_app/features/membership/application/membership_purchase_bookkeeping.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/recurring/data/recurring_bill_repository.dart';
import 'package:jizhang_app/core/models/recurring_bill.dart';

void main() {
  test('the same verified membership order creates only one expense', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final bookkeeping = QuickBookkeepingService(
      transactions,
      DriftAppSettingsRepository(database),
    );
    final service = MembershipPurchaseBookkeepingService(
      transactions: transactions,
      bookkeeping: bookkeeping,
    );
    final purchase = VerifiedMembershipPurchase(
      orderId: 'order-20260908-001',
      productId: 'pro_monthly',
      amount: 18,
      currency: 'CNY',
      accountId: SeedIds.alipayAccount,
      paidAt: DateTime(2026, 9, 8, 10),
      provider: 'wechatPay',
    );

    final first = await service.record(purchase);
    final retry = await service.record(purchase);

    expect(first.created, isTrue);
    expect(retry.created, isFalse);
    expect(retry.transaction.id, first.transaction.id);
    expect(
      (await transactions.getAll())
          .where((item) => item.merchant == '好好记账会员')
          .length,
      1,
    );
  });

  test('auto-renew membership creates one monthly recurring bill', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final transactions = DriftTransactionRepository(database);
    final service = MembershipPurchaseBookkeepingService(
      transactions: transactions,
      bookkeeping: QuickBookkeepingService(
        transactions,
        DriftAppSettingsRepository(database),
      ),
      recurringBills: DriftRecurringBillRepository(
        database,
        bookId: SeedIds.personalBook,
      ),
    );
    await service.record(
      VerifiedMembershipPurchase(
        orderId: 'order-auto-renew',
        productId: 'pro_monthly',
        amount: 18,
        currency: 'CNY',
        accountId: SeedIds.alipayAccount,
        paidAt: DateTime(2026, 9, 8),
        provider: 'wechatPay',
        autoRenew: true,
      ),
    );
    expect(
      (await service.recurringBills!.getAll()).single.cycle.name,
      'monthly',
    );

    await service.record(
      VerifiedMembershipPurchase(
        orderId: 'order-permanent',
        productId: 'pro_lifetime',
        amount: 199,
        currency: 'CNY',
        accountId: SeedIds.alipayAccount,
        paidAt: DateTime(2026, 9, 8),
        provider: 'wechatPay',
        isPermanent: true,
      ),
    );
    expect((await service.recurringBills!.getAll()), hasLength(1));

    await service.record(
      VerifiedMembershipPurchase(
        orderId: 'order-month-end',
        productId: 'pro_monthly_month_end',
        amount: 18,
        currency: 'CNY',
        accountId: SeedIds.alipayAccount,
        paidAt: DateTime(2026, 1, 31),
        provider: 'wechatPay',
        autoRenew: true,
      ),
    );
    final monthEndBill = (await service.recurringBills!.getAll()).firstWhere(
      (bill) => bill.nextDate == DateTime(2026, 2, 28),
    );
    expect(monthEndBill.nextDate, DateTime(2026, 2, 28));

    expect(await service.stopAutoRenewForProduct('pro_monthly'), isTrue);
    expect(
      (await service.recurringBills!.getAll())
          .firstWhere(
            (bill) =>
                bill.id ==
                'membership-recurring-${stableAutoKey('pro_monthly')}',
          )
          .status,
      RecurringBillStatus.ended,
    );
    expect(await service.stopAutoRenewForProduct('pro_monthly'), isFalse);
  });
}
