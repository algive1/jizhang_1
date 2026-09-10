import 'family.dart';

class LedgerBook {
  const LedgerBook({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    this.sharedId,
    this.role,
    this.sharedPhase,
  });

  final String id;
  final String name;
  final BookType type;
  final String ownerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  final String? sharedId;
  final String? role;
  final String? sharedPhase;
  bool get isShared => sharedId != null;
  bool get canManage => !isShared || role == 'owner' || role == 'admin';

  bool get isPersonal => type == BookType.personal;
}
