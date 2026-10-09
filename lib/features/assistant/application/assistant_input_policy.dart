import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';

class AssistantInputPolicy {
  const AssistantInputPolicy({
    this.enabled = true,
    this.maxInputLength = 300,
    this.freeDailyLimit = 30,
    this.memberDailyLimit = 300,
    this.requestsPerMinute = 10,
    this.maxTransactions = 30,
    this.maxImageMb = 10,
    this.maxImportFileMb = 20,
    this.maxImportRows = 10000,
    this.memberFeatures = const ['voice'],
    this.boundaryReply = '我只处理记账、预算、收支查询、导入导出和会员权益。',
  });
  final bool enabled;
  final int maxInputLength,
      freeDailyLimit,
      memberDailyLimit,
      requestsPerMinute,
      maxTransactions,
      maxImageMb,
      maxImportFileMb,
      maxImportRows;
  final List<String> memberFeatures;
  final String boundaryReply;
  factory AssistantInputPolicy.fromJson(Map<String, dynamic> json) {
    int number(String key, int fallback, int min, int max) =>
        json[key] is int &&
            (json[key] as int) >= min &&
            (json[key] as int) <= max
        ? json[key] as int
        : fallback;
    return AssistantInputPolicy(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      maxInputLength: number('maxInputLength', 300, 20, 2000),
      freeDailyLimit: number('freeDailyLimit', 30, 0, 10000),
      memberDailyLimit: number('memberDailyLimit', 300, 0, 10000),
      requestsPerMinute: number('requestsPerMinute', 10, 1, 60),
      maxTransactions: number('maxTransactions', 30, 1, 30),
      maxImageMb: number('maxImageMb', 10, 1, 20),
      maxImportFileMb: number('maxImportFileMb', 20, 1, 50),
      maxImportRows: number('maxImportRows', 10000, 1, 10000),
      memberFeatures: json['memberFeatures'] is List
          ? (json['memberFeatures'] as List)
                .whereType<String>()
                .where(
                  (v) =>
                      const ['voice', 'ocr', 'summary', 'export'].contains(v),
                )
                .toList()
          : const ['voice'],
      boundaryReply: json['boundaryReply'] is String
          ? json['boundaryReply'] as String
          : '我只处理记账、预算、收支查询、导入导出和会员权益。',
    );
  }
}

final assistantInputPolicyServiceProvider = Provider(
  (ref) => AssistantInputPolicyService(
    ref.watch(appSettingsRepositoryProvider),
    api: const String.fromEnvironment('SHARED_API_BASE_URL').isEmpty
        ? null
        : ref.watch(sharedApiProvider),
  ),
);

class AssistantInputPolicyService {
  AssistantInputPolicyService(this.settings, {this.api});
  final AppSettingsRepository settings;
  final SharedApi? api;
  AssistantInputPolicy? _cached;
  DateTime? _loadedAt;
  Future<AssistantInputPolicy>? _pending;
  Future<AssistantInputPolicy> load() {
    if (_cached != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 5))
      return Future.value(_cached);
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<AssistantInputPolicy> _load() async {
    var value = _cached ?? const AssistantInputPolicy();
    try {
      final raw = await settings.get('assistant.public-policy.v1');
      if (raw != null)
        value = AssistantInputPolicy.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
    } on Object {
      /* A damaged cache falls back to conservative defaults. */
    }
    if (api != null) {
      try {
        final json = await api!.request('/assistant/config');
        value = AssistantInputPolicy.fromJson(json);
        await settings.set('assistant.public-policy.v1', jsonEncode(json));
      } on Object {
        /* Offline input checks retain the last public policy. */
      }
    }
    _loadedAt = DateTime.now();
    return _cached = value;
  }
}
