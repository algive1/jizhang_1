import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/app_settings_repository.dart';
import 'account_session_controller.dart';
import 'dataset_binding_service.dart';

String cloudAutoBackupKey(String userId, String datasetId) =>
    'cloud.backup.auto.$userId.$datasetId';

/// Opt-in belongs to this account and dataset, never to a different login.
final cloudAutoBackupEnabledProvider = FutureProvider<bool>((ref) async {
  final session = await ref.watch(accountSessionProvider.future);
  final userId = session.user?.id;
  if (!session.isAuthenticated || userId == null) return false;
  final binding = await ref.watch(datasetBindingProvider.future);
  if (binding.boundUserId != userId) return false;
  return await ref
          .watch(appSettingsRepositoryProvider)
          .get(cloudAutoBackupKey(userId, binding.datasetId)) ==
      'true';
});
