import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/entity_id.dart';
import '../../../core/models/membership.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../../membership/data/membership_repository.dart';
import 'assistant_input_policy.dart';
import 'assistant_scope.dart';

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
    inputPolicy: ref.watch(assistantInputPolicyServiceProvider),
    isMember: () =>
        (ref.read(membershipProvider).value?.membership.effectivePlan ??
            MembershipPlan.free) !=
        MembershipPlan.free,
    hasFeature: (feature) =>
        ref
            .read(membershipProvider)
            .value
            ?.has(
              feature == 'voice'
                  ? EntitlementKey.voiceAi
                  : feature == 'ocr'
                  ? EntitlementKey.ocr
                  : EntitlementKey.dataExport,
            ) ??
        false,
    dailyLimit: () => ref
        .read(membershipProvider)
        .value
        ?.quotaFor(EntitlementKey.voiceAi)
        ?.limit,
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
  LocalAssistantPolicyService(
    this.settings, {
    this.inputPolicy,
    this.isMember,
    this.hasFeature,
    this.dailyLimit,
  });
  final AppSettingsRepository settings;
  final AssistantInputPolicyService? inputPolicy;
  final bool Function()? isMember;
  final bool Function(String)? hasFeature;
  final int? Function()? dailyLimit;

  static const maxInputLength = 300;
  static const freeDailyLimit = 30;
  static const memberDailyLimit = 300;
  static const requestsPerMinute = 10;

  @override
  Future<AssistantAuthorizationResult> authorize({
    String? text,
    String? feature,
  }) async {
    final policy = await (inputPolicy ?? AssistantInputPolicyService(settings))
        .load();
    if (!policy.enabled)
      return const AssistantAuthorizationResult(
        allowed: false,
        message: '记账助手暂时停用',
      );
    final requestedFeature =
        feature ?? (text == null ? null : assistantQueryFeature(text));
    if (requestedFeature != null &&
        policy.memberFeatures.contains(requestedFeature) &&
        !(requestedFeature == 'summary'
            ? isMember?.call() ?? false
            : hasFeature?.call(requestedFeature) ?? false)) {
      return const AssistantAuthorizationResult(
        allowed: false,
        message: '该功能需要对应会员权益。',
        requiresMembership: true,
      );
    }
    if (text == null) return const AssistantAuthorizationResult(allowed: true);
    final value = text.trim();
    if (value.runes.length > policy.maxInputLength) {
      return AssistantAuthorizationResult(
        allowed: false,
        message: '单条消息最多 ${policy.maxInputLength} 字。',
      );
    }
    final day = _day();
    final usedKey = 'assistant.local.usage.$day';
    final used = int.tryParse(await settings.get(usedKey) ?? '0') ?? 0;
    final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final minuteKey = 'assistant.local.rate.$minute';
    final minuteUsed = int.tryParse(await settings.get(minuteKey) ?? '0') ?? 0;
    if (minuteUsed >= policy.requestsPerMinute) {
      return const AssistantAuthorizationResult(
        allowed: false,
        message: '发送太快，请稍后再试。',
      );
    }
    await settings.set(minuteKey, '${minuteUsed + 1}');
    if (assistantOutOfScope(value))
      return AssistantAuthorizationResult(
        allowed: false,
        message: policy.boundaryReply,
      );
    final limit = isMember?.call() == true
        ? dailyLimit?.call() ?? policy.memberDailyLimit
        : policy.freeDailyLimit;
    if (used >= limit) {
      return AssistantAuthorizationResult(
        allowed: false,
        message: '今日助手次数已用完（$limit 次）。',
        requiresMembership: isMember?.call() != true,
      );
    }
    await settings.set(usedKey, '${used + 1}');
    return AssistantAuthorizationResult(
      allowed: true,
      remaining: limit - used - 1,
    );
  }

  String _day() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
