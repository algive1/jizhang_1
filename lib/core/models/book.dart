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
    this.assetSourceBookId,
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

  /// Null means this book owns its asset accounts. A non-null value points to
  /// the primary asset book shared by this ledger.
  final String? assetSourceBookId;

  final String? sharedId;
  final String? role;
  final String? sharedPhase;
  bool get isShared => sharedId != null;
  bool get canManage => !isShared || role == 'owner' || role == 'admin';

  bool get isPersonal => type == BookType.personal;
  String get assetBookId => assetSourceBookId ?? id;
  bool get usesPrimaryAssets => assetSourceBookId != null;
}
