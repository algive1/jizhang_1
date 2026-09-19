import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/family.dart';
import '../../sharing/application/shared_book_sync_service.dart';
import '../domain/family_service.dart';

class SharedFamilyService implements FamilyService {
  SharedFamilyService(this.sync);
  final SharedBookSyncService sync;
  @override
  Future<void> enableSharing(String bookId) => sync.enableSharing(bookId);
  Future<Json> _request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    await sync.session.initialize();
    return sync.api.request(path, method: method, body: body);
  }

  FamilyInvitation _invitation(Json data) => FamilyInvitation(
    id: data['id'] as String,
    familyId: data['book_id'] as String,
    code: data['code'] as String,
    invitedBy: data['invited_by'] as String,
    status:
        (data['status'] == 'pending' &&
            (data['expires_at'] as int) * 1000 <
                DateTime.now().millisecondsSinceEpoch)
        ? FamilyInvitationStatus.expired
        : FamilyInvitationStatus.values.byName(data['status'] as String),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      (data['expires_at'] as int) * 1000,
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      ((data['expires_at'] as int) - 7 * 86400) * 1000,
    ),
  );
  @override
  Future<FamilyInvitation> createInvitation({
    required String familyId,
    Duration validFor = const Duration(days: 7),
  }) async {
    if (validFor != const Duration(days: 7)) throw ArgumentError('本轮邀请统一为七天有效');
    return _invitation(
      await _request(
        '/books/$familyId/invitations',
        method: 'POST',
        body: {},
      ),
    );
  }

  @override
  Future<FamilyMember> acceptInvitation(String code) async {
    final snapshot = await _request(
      '/invitations/accept',
      method: 'POST',
      body: {'code': code.trim()},
    );
    await sync.sync();
    return FamilyMember(
      id: sync.session.user!.id,
      familyId: snapshot['book']['id'] as String,
      userId: sync.session.user!.id,
      role: FamilyRole.values.byName(snapshot['role'] as String),
      joinedAt: DateTime.now(),
    );
  }

  @override
  Future<List<FamilyMember>> members(String familyId) async =>
      (await memberDetails(familyId))
          .map(
            (r) => FamilyMember(
              id: r['user_id'] as String,
              familyId: familyId,
              userId: r['user_id'] as String,
              role: FamilyRole.values.byName(r['role'] as String),
              joinedAt: DateTime.fromMillisecondsSinceEpoch(
                (r['joined_at'] as int) * 1000,
              ),
            ),
          )
          .toList();
  Future<List<Json>> memberDetails(String familyId) async =>
      (await _request(
        '/books/$familyId/members',
      ))['members'].cast<Json>();
  @override
  Future<List<FamilyInvitation>> invitations(String familyId) async =>
      ((await _request('/books/$familyId/invitations'))['invitations']
              as List)
          .cast<Json>()
          .map(_invitation)
          .toList();
  @override
  Future<void> revokeInvitation(String familyId, String invitationId) async {
    await _request(
      '/books/$familyId/invitations/$invitationId',
      method: 'DELETE',
    );
  }

  @override
  Future<void> changeRole(
    String familyId,
    String userId,
    FamilyRole role,
  ) async {
    if (role == FamilyRole.owner) throw ArgumentError('当前不支持所有权转让');
    await _request(
      '/books/$familyId/members/$userId',
      method: 'PATCH',
      body: {'role': role.name},
    );
    await sync.sync();
  }

  @override
  Future<void> transferOwnership(String familyId, String userId) async {
    await _request('/books/$familyId/transfer-ownership', method: 'POST', body: {'userId': userId});
    await sync.sync();
  }

  @override
  Future<void> disband(String familyId) async {
    await _request('/books/$familyId/disband', method: 'POST', body: {});
    await sync.sync();
  }

  @override
  Future<void> removeMember(String familyId, String userId) async {
    await _request(
      '/books/$familyId/members/$userId',
      method: 'DELETE',
    );
    await sync.sync();
  }
}

final familyServiceProvider = Provider<SharedFamilyService>(
  (ref) => SharedFamilyService(ref.watch(sharedBookSyncProvider)),
);
