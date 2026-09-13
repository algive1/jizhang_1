import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/entity_id.dart';
import '../../books/data/book_repository.dart';
import '../../intelligence/data/bill_inbox_repository.dart';
import '../../notifications/application/payment_notification_service.dart';
import '../../settings/data/app_settings_repository.dart';
import 'assistant_engine.dart';
import 'assistant_policy.dart';

class AssistantMessage {
  AssistantMessage({
    required this.id,
    required this.text,
    required this.time,
    this.isUser = false,
    this.transactionId,
    this.route,
    this.requiresMembership = false,
    this.read = false,
  });
  final String id, text;
  final DateTime time;
  final bool isUser, read;
  final String? transactionId, route;
  final bool requiresMembership;
  String get type => isUser
      ? 'user_text'
      : transactionId != null
      ? 'assistant_record_success_card'
      : route == '/profile/budgets'
      ? 'assistant_budget_summary'
      : 'assistant_text';
  Map<String, Object?> toJson({bool? read}) => {
    'id': id,
    'type': type,
    'text': text,
    'time': time.toIso8601String(),
    'isUser': isUser,
    'transactionId': transactionId,
    'route': route,
    'read': read ?? this.read,
    'requiresMembership': requiresMembership,
  };
  factory AssistantMessage.fromJson(Map<String, dynamic> json) =>
      AssistantMessage(
        id: json['id'] as String,
        text: json['text'] as String,
        time: DateTime.parse(json['time'] as String),
        isUser: json['isUser'] as bool,
        transactionId: json['transactionId'] as String?,
        route: json['route'] as String?,
        requiresMembership: json['requiresMembership'] as bool? ?? false,
        read: json['read'] as bool? ?? false,
      );
}

final assistantConversationProvider =
    AsyncNotifierProvider<AssistantConversation, List<AssistantMessage>>(
      AssistantConversation.new,
    );
final assistantUnreadProvider = Provider<bool>((ref) {
  final messages = ref.watch(assistantConversationProvider).value ?? [];
  return messages.any((m) => !m.isUser && !m.read) ||
      (ref.watch(pendingInboxProvider).value?.isNotEmpty ?? false) ||
      ref.watch(notificationProcessingErrorProvider) != null;
});

class AssistantConversation extends AsyncNotifier<List<AssistantMessage>> {
  late AppSettingsRepository _settings;
  late String _key;
  bool sending = false;
  int viewers = 0;
  AssistantAuthorizationResult? lastAuthorization;
  @override
  Future<List<AssistantMessage>> build() async {
    final book = ref.watch(activeBookIdProvider);
    _settings = ref.read(appSettingsRepositoryProvider);
    _key = 'assistant_conversation_v1_$book';
    await ref.watch(databaseBootstrapProvider.future);
    final raw = await _settings.get('assistant_conversation_v1_$book');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => AssistantMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<AssistantMessage> messages, {String? key}) async {
    final destination = key ?? _key;
    await _settings.set(
      destination,
      jsonEncode(messages.map((m) => m.toJson()).toList()),
    );
    if (destination == _key) state = AsyncData(messages);
  }

  Future<void> markRead() async {
    if (sending) return;
    final messages = await future;
    await _save(
      messages
          .map((m) => AssistantMessage.fromJson(m.toJson(read: true)))
          .toList(),
    );
  }

  Future<void> clear() async {
    if (!sending) await _save([]);
  }

  Future<void> send(String text) async {
    if (sending || text.trim().isEmpty) return;
    sending = true;
    try {
      final messages = await future;
      final key = _key;
      final engine = ref.read(assistantEngineProvider);
      final authorization = await ref
          .read(assistantPolicyServiceProvider)
          .authorize(text: text.trim());
      lastAuthorization = authorization;
      final user = AssistantMessage(
        id: newEntityId(),
        text: text.trim(),
        time: DateTime.now(),
        isUser: true,
        read: true,
      );
      await _save([...messages, user], key: key);
      AssistantReply reply;
      try {
        reply = authorization.allowed
            ? await engine.sendMessage(
                text.trim(),
                requestId: authorization.requestId,
              )
            : AssistantReply(authorization.message);
      } on Object catch (error, stack) {
        debugPrint('Assistant request failed: $error\n$stack');
        reply = const AssistantReply('处理失败，请检查当前账本和账户后重试。如已看到流水，请勿重复提交。');
      }
      final response = AssistantMessage(
        id: newEntityId(),
        text: reply.text,
        time: DateTime.now(),
        transactionId: reply.transactionId,
        route: reply.route,
        requiresMembership: authorization.requiresMembership,
        read: viewers > 0 && key == _key,
      );
      final updated = [...messages, user, response];
      // Show the committed record even if saving conversation history fails.
      if (key == _key) state = AsyncData(updated);
      await _save(updated, key: key);
    } finally {
      sending = false;
    }
  }
}
