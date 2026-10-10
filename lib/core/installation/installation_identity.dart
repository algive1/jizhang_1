import '../utils/entity_id.dart';
import '../../features/settings/data/app_settings_repository.dart';

/// One installation identity for rollout, updates and operational heartbeats.
/// Retains the existing key so an upgrade does not move a device between cohorts.
const installationIdentityKey = 'analytics.installation_id.v1';
final _pendingIdentities = Expando<Future<String>>();

Future<String> installationIdentity(AppSettingsRepository settings) {
  final pending = _pendingIdentities[settings];
  if (pending != null) return pending;
  final future = () async {
    final saved = await settings.get(installationIdentityKey);
    if (saved != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(saved))
      return saved;
    final created = newEntityId();
    await settings.set(installationIdentityKey, created);
    return created;
  }();
  _pendingIdentities[settings] = future;
  return future.whenComplete(() => _pendingIdentities[settings] = null);
}
