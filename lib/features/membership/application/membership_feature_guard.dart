import '../../../core/models/membership.dart';
import '../domain/commercial_service_contracts.dart';

class MembershipFeatureDenied implements Exception {
  const MembershipFeatureDenied(this.access);
  final MembershipFeatureAccess access;
  @override
  String toString() => access.requiresUpgrade
      ? '${access.feature.label}需要有效会员'
      : '${access.feature.label}暂未开放';
}

Future<void> requireMembershipFeature(
  MembershipFeatureAccessService service,
  MembershipFeature feature,
) async {
  final access = await service.accessFor(feature);
  if (!access.allowed) throw MembershipFeatureDenied(access);
}
