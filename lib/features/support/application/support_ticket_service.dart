import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/entity_id.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';

class SupportTicketService {
  SupportTicketService({
    required SharedApi api,
    required AppSettingsRepository settings,
    required SessionRepository session,
  })  : _api = api,
        _settings = settings,
        _session = session;

  static const _installationKey = 'support.installation_id.v1';
  static const _appInfoChannel = MethodChannel('jizhang/app_update');

  final SharedApi _api;
  final AppSettingsRepository _settings;
  final SessionRepository _session;

  Future<String> submit({
    required String subject,
    required String message,
    String? contact,
  }) async {
    await _session.initialize();
    var installationId = (await _settings.get(_installationKey))?.trim();
    if (installationId == null ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(installationId)) {
      installationId = newEntityId();
      await _settings.set(_installationKey, installationId);
    }
    String? version;
    try {
      final info = await _appInfoChannel.invokeMapMethod<String, dynamic>('appInfo');
      final name = info?['version'];
      final build = info?['build'];
      if (name is String) version = build == null ? name : '$name+$build';
    } on PlatformException {
      // Version is useful metadata but never blocks feedback.
    } on MissingPluginException {
      // Desktop/tests may not provide the native channel.
    }

    final response = await _api.request(
      '/support/tickets',
      method: 'POST',
      body: {
        'installationId': installationId,
        'subject': subject.trim(),
        'message': message.trim(),
        if (contact?.trim().isNotEmpty == true) 'contact': contact!.trim(),
        if (version != null) 'appVersion': version,
      },
    );
    final id = response['id'];
    if (id is! String || id.isEmpty) {
      throw const SharedApiException(0, '反馈提交成功但服务器未返回工单号');
    }
    return id;
  }
}

final supportTicketServiceProvider = Provider<SupportTicketService>((ref) {
  return SupportTicketService(
    api: ref.watch(sharedApiProvider),
    settings: ref.watch(appSettingsRepositoryProvider),
    session: ref.read(sessionRepositoryProvider),
  );
});
