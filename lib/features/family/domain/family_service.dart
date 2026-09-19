import '../../../core/models/family.dart';

abstract interface class FamilyService {
  Future<void> enableSharing(String bookId);
  Future<FamilyInvitation> createInvitation({
    required String familyId,
    Duration validFor = const Duration(days: 7),
  });
  Future<FamilyMember> acceptInvitation(String code);
  Future<void> revokeInvitation(String familyId, String invitationId);
  Future<List<FamilyMember>> members(String familyId);
  Future<List<FamilyInvitation>> invitations(String familyId);
  Future<void> changeRole(String familyId, String userId, FamilyRole role);
  Future<void> removeMember(String familyId, String userId);
  Future<void> transferOwnership(String familyId, String userId);
  Future<void> disband(String familyId);
}
