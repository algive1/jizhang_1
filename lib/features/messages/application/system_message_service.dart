import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sharing/data/shared_api.dart';
import '../../sharing/data/session_repository.dart';

class SystemMessage {
  const SystemMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    required this.isRead,
    this.route,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String? route;
  final DateTime publishedAt;
  final bool isRead;
  final DateTime? readAt;

  static SystemMessage? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    final id = json['id'];
    final title = json['title'];
    final body = json['body'];
    final publishedAt = json['publishedAt'];
    if (id is! String ||
        title is! String ||
        body is! String ||
        publishedAt is! int) {
      return null;
    }
    final rawReadAt = json['readAt'];
    return SystemMessage(
      id: id,
      title: title,
      body: body,
      route: json['route'] as String?,
      publishedAt: DateTime.fromMillisecondsSinceEpoch(publishedAt * 1000),
      isRead: json['isRead'] == true || json['isRead'] == 1,
      readAt: rawReadAt is int
          ? DateTime.fromMillisecondsSinceEpoch(rawReadAt * 1000)
          : null,
    );
  }
}

class SystemMessageInbox {
  const SystemMessageInbox({
    required this.messages,
    required this.unread,
  });

  final List<SystemMessage> messages;
  final int unread;
}

class SystemMessageService {
  const SystemMessageService(this._api);

  final SharedApi _api;

  Future<SystemMessageInbox> load() async {
    final data = await _api.request('/messages');
    final raw = data['messages'];
    final messages = raw is List
        ? raw
            .map(SystemMessage.fromJson)
            .whereType<SystemMessage>()
            .toList(growable: false)
        : const <SystemMessage>[];
    return SystemMessageInbox(
      messages: messages,
      unread: data['unread'] is int ? data['unread'] as int : 0,
    );
  }

  Future<void> markRead(String id) async {
    await _api.request('/messages/$id/read', method: 'POST', body: const {});
  }

  Future<void> markAllRead() async {
    await _api.request('/messages/read-all', method: 'POST', body: const {});
  }
}

final systemMessageServiceProvider = Provider<SystemMessageService>(
  (ref) => SystemMessageService(ref.watch(sharedApiProvider)),
);


final systemUnreadCountProvider = FutureProvider<int>((ref) async {
  final session = ref.read(sessionRepositoryProvider);
  await session.initialize();
  if (session.userId == null) return 0;
  try {
    return (await ref.read(systemMessageServiceProvider).load()).unread;
  } on Object {
    return 0;
  }
});
