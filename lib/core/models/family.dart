enum FamilyRole { owner, admin, member }

enum BookType { personal, family, enterprise }

extension BookTypeLabel on BookType {
  String get label => switch (this) {
    BookType.personal => '个人账本',
    BookType.family => '家庭账本',
    BookType.enterprise => '企业账本',
  };
  String get spendingLabel => switch (this) {
    BookType.personal => '今日安心可花',
    BookType.family => '家庭今日可花',
    BookType.enterprise => '今日支出额度',
  };
}

enum TransactionVisibility { private, shared }

enum FamilyBudgetVisibility { private, totalsOnly, shared }

enum FamilyInvitationStatus { pending, accepted, expired, revoked }

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  final String id;
  final String familyId;
  final String userId;
  final FamilyRole role;
  final DateTime joinedAt;
}

class SharedBook {
  const SharedBook({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.familyId,
  });

  final String id;
  final String name;
  final BookType type;
  final String ownerUserId;
  final String? familyId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.familyId,
    required this.code,
    required this.invitedBy,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String code;
  final String invitedBy;
  final FamilyInvitationStatus status;
  final DateTime expiresAt;
  final DateTime createdAt;

  bool canAcceptAt(DateTime now) =>
      status == FamilyInvitationStatus.pending && now.isBefore(expiresAt);
}

class FamilyOperationLog {
  const FamilyOperationLog({
    required this.id,
    required this.familyId,
    required this.actorUserId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String actorUserId;
  final String entityType;
  final String entityId;
  final String action;
  final DateTime createdAt;
}

class VersionConflictException implements Exception {
  const VersionConflictException({
    required this.expectedVersion,
    required this.actualVersion,
  });

  final int expectedVersion;
  final int actualVersion;

  @override
  String toString() =>
      'VersionConflictException(expected: $expectedVersion, actual: $actualVersion)';
}
