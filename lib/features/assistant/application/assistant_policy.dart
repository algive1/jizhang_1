import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/entity_id.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';

class AssistantAuthorizationResult {
  const AssistantAuthorizationResult({
    required this.allowed,
    this.requestId,
    this.message = '',
    this.requiresMembership = false,
    this.remaining = 0,
  });

  final bool allowed;
  final String? requestId;
  final String message;
  final bool requiresMembership;
  final int remaining;
}

abstract interface class AssistantPolicyService {
  Future<AssistantAuthorizationResult> authorize({
    String? text,
    String? feature,
  });
}

final assistantPolicyServiceProvider = Provider<AssistantPolicyService>((ref) {
  final baseUrl = const String.fromEnvironment('SHARED_API_BASE_URL');
  final session = ref.watch(sessionProvider).value;
  final local = LocalAssistantPolicyService(
    ref.watch(appSettingsRepositoryProvider),
  );
  if (baseUrl.isNotEmpty && session != null) {
    return RemoteAssistantPolicyService(ref.watch(sharedApiProvider), local);
  }
  return local;
});

class RemoteAssistantPolicyService implements AssistantPolicyService {
  const RemoteAssistantPolicyService(this.api, this.fallback);
  final SharedApi api;
  final AssistantPolicyService fallback;

  @override
  Future<AssistantAuthorizationResult> authorize({
    String? text,
    String? feature,
  }) async {
    try {
      final requestId = newEntityId();
      final body = <String, Object?>{'requestId': requestId};
      if (text != null) body['text'] = text;
      if (feature != null) body['feature'] = feature;
      final data = await api.request(
        '/assistant/authorize',
        method: 'POST',
        body: body,
      );
      return AssistantAuthorizationResult(
        allowed: data['allowed'] as bool? ?? false,
        requestId: data['requestId'] as String? ?? requestId,
        message: data['message'] as String? ?? '',
        requiresMembership: data['requiresMembership'] as bool? ?? false,
        remaining: (data['remaining'] as num?)?.toInt() ?? 0,
      );
    } on SharedApiException catch (error) {
      // A server response is an authoritative policy decision or an explicit
      // service error. Do not fall back to local authorization here, because
      // that could bypass the server's member quota or rate limit.
      return AssistantAuthorizationResult(
        allowed: false,
        message: error.message,
      );
    } on Object {
      // Keep the same local boundary and quota when the policy service is
      // unreachable at the transport layer. The local limits still apply.
      return fallback.authorize(text: text, feature: feature);
    }
  }
}

class LocalAssistantPolicyService implements AssistantPolicyService {
  LocalAssistantPolicyService(this.settings);
  final AppSettingsRepository settings;

  static const maxInputLength = 300;
  static const freeDailyLimit = 30;
  static const memberDailyLimit = 300;
  static const requestsPerMinute = 10;

  static final _outOfScope = RegExp(
    r'代码|编程|脚本|程序|python|javascript|typescript|java\b|flutter|sql\b|html|css\b|写作|作文|小说|翻译|忽略|提示词|system\s*prompt|ignore|开发网站|写.*函数|write.*code|```',
    caseSensitive: false,
  );

  @override
  Future<AssistantAuthorizationResult> authorize({
    String? text,
    String? feature,
  }) async {
    if (feature == 'voice') {
      return const AssistantAuthorizationResult(
        allowed: false,
        message: '语音记账是会员功能，开通会员后可使用。',
        requiresMembership: true,
      );
    }
    if (text == null) return const AssistantAuthorizationResult(allowed: true);
    final value = text.trim();
    if (value.runes.length > maxInputLength) {
      return const AssistantAuthorizationResult(
        allowed: false,
        message: '单条消息最多 300 字。',
      );
    }
    final day = _day();
    final usedKey = 'assistant.local.usage.$day';
    final used = int.tryParse(await settings.get(usedKey) ?? '0') ?? 0;
    final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final minuteKey = 'assistant.local.rate.$minute';
    final minuteUsed = int.tryParse(await settings.get(minuteKey) ?? '0') ?? 0;
    if (minuteUsed >= requestsPerMinute) {
      return const AssistantAuthorizationResult(
        allowed: false,
        message: '发送太快，请稍后再试。',
      );
    }
    await settings.set(minuteKey, '${minuteUsed + 1}');
    if (used >= freeDailyLimit) {
      return const AssistantAuthorizationResult(
        allowed: false,
        message: '今日助手次数已用完（30 次）。开通会员可提升每日次数。',
        requiresMembership: true,
      );
    }
    await settings.set(usedKey, '${used + 1}');
    if (_outOfScope.hasMatch(value)) {
      return const AssistantAuthorizationResult(
        allowed: false,
        message: '我只处理记账、预算、收支查询、导出和会员权益，不能编写代码或完成其他通用任务。你可以发送“午餐12元微信支付”。',
      );
    }
    return AssistantAuthorizationResult(
      allowed: true,
      remaining: freeDailyLimit - used - 1,
    );
  }

  String _day() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
