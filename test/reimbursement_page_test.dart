import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/reimbursements/presentation/reimbursement_page.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  testWidgets('reimbursement card shows human readable ledger and account', (
    tester,
  ) async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    });
    final occurredAt = DateTime.now();
    await DriftTransactionRepository(database).create(
      TransactionRecord(
        id: 'reimbursement-page-source',
        bookId: SeedIds.personalBook,
        type: TransactionType.expense,
        amount: 500,
        accountId: SeedIds.bankAccount,
        occurredAt: occurredAt,
        createdAt: occurredAt,
        updatedAt: occurredAt,
        reimbursementStatus: ReimbursementStatus.pending,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ReimbursementPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('账本：个人账本 · 账户：银行卡-7777'), findsOneWidget);
    expect(find.text('待报销'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
