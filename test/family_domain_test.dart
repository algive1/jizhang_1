import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/family/domain/family_access_policy.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  const policy = FamilyAccessPolicy();

  test('private transactions are visible only to their creator', () {
    expect(
      policy.canViewTransaction(
        viewerUserId: 'owner',
        createdBy: 'owner',
        visibility: TransactionVisibility.private,
      ),
      isTrue,
    );
    expect(
      policy.canViewTransaction(
        viewerUserId: 'partner',
        createdBy: 'owner',
        visibility: TransactionVisibility.private,
      ),
      isFalse,
    );
    expect(
      policy.canViewTransaction(
        viewerUserId: 'partner',
        createdBy: 'owner',
        visibility: TransactionVisibility.shared,
      ),
      isTrue,
    );
  });

  test('totals-only budgets reveal aggregate but not line details', () {
    expect(
      policy.canViewBudgetTotal(FamilyBudgetVisibility.totalsOnly),
      isTrue,
    );
    expect(
      policy.canViewBudgetDetails(
        viewerUserId: 'partner',
        ownerUserId: 'owner',
        visibility: FamilyBudgetVisibility.totalsOnly,
      ),
      isFalse,
    );
  });

  test('owner/admin manage members and stale versions conflict', () {
    expect(policy.canManageMembers(FamilyRole.owner), isTrue);
    expect(policy.canManageMembers(FamilyRole.admin), isTrue);
    expect(policy.canManageMembers(FamilyRole.member), isFalse);
    expect(
      () => policy.requireExpectedVersion(expectedVersion: 2, actualVersion: 3),
      throwsA(isA<VersionConflictException>()),
    );
  });

  test('invitation cannot be accepted after expiry', () {
    final now = DateTime(2026, 8, 31);
    final invitation = FamilyInvitation(
      id: 'invite',
      familyId: 'family',
      code: 'ABC123',
      invitedBy: 'owner',
      status: FamilyInvitationStatus.pending,
      expiresAt: now.add(const Duration(hours: 1)),
      createdAt: now,
    );
    expect(invitation.canAcceptAt(now), isTrue);
    expect(invitation.canAcceptAt(now.add(const Duration(hours: 2))), isFalse);
  });

  test('sharing fields and versions persist with a transaction', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final repository = DriftTransactionRepository(database);
    final now = DateTime.now();
    await repository.create(
      TransactionRecord(
        id: 'shared-transaction',
        bookId: SeedIds.personalBook,
        userId: SeedIds.localUser,
        type: TransactionType.expense,
        amount: 88,
        accountId: SeedIds.cashAccount,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        visibility: TransactionVisibility.shared,
        createdBy: SeedIds.localUser,
        updatedBy: SeedIds.localUser,
        version: 4,
      ),
    );

    final stored = (await repository.getAll()).firstWhere(
      (item) => item.id == 'shared-transaction',
    );
    expect(stored.visibility, TransactionVisibility.shared);
    expect(stored.createdBy, SeedIds.localUser);
    expect(stored.version, 4);
    expect(await database.familyDao.findBook(SeedIds.personalBook), isNotNull);
  });
}
