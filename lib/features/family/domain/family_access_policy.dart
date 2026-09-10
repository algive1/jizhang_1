import '../../../core/models/family.dart';

class FamilyAccessPolicy {
  const FamilyAccessPolicy();

  bool canManageMembers(FamilyRole role) =>
      role == FamilyRole.owner || role == FamilyRole.admin;

  bool canCreateSharedTransaction(FamilyRole role) =>
      FamilyRole.values.contains(role);

  bool canViewTransaction({
    required String viewerUserId,
    required String createdBy,
    required TransactionVisibility visibility,
  }) {
    return visibility == TransactionVisibility.shared ||
        viewerUserId == createdBy;
  }

  bool canViewBudgetDetails({
    required String viewerUserId,
    required String ownerUserId,
    required FamilyBudgetVisibility visibility,
  }) {
    return visibility == FamilyBudgetVisibility.shared ||
        viewerUserId == ownerUserId;
  }

  bool canViewBudgetTotal(FamilyBudgetVisibility visibility) =>
      visibility != FamilyBudgetVisibility.private;

  void requireExpectedVersion({
    required int expectedVersion,
    required int actualVersion,
  }) {
    if (expectedVersion != actualVersion) {
      throw VersionConflictException(
        expectedVersion: expectedVersion,
        actualVersion: actualVersion,
      );
    }
  }
}
