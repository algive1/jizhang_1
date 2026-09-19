import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/entity_id.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';

class SupportTicketSummary {
  const SupportTicketSummary({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.resolvedAt,
    this.lastMessageAt,
  });

  final String id;
  final String subject;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? lastMessageAt;
  final int messageCount;

  static SupportTicketSummary? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    final id = json['id'];
    final subject = json['subject'];
    final status = json['status'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    if (id is! String ||
        subject is! String ||
        status is! String ||
        createdAt is! int ||
        updatedAt is! int) {
      return null;
    }
    DateTime? time(Object? raw) => raw is int
        ? DateTime.fromMillisecondsSinceEpoch(raw * 1000)
        : null;
    return SupportTicketSummary(
      id: id,
      subject: subject,
      status: status,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000),
      resolvedAt: time(json['resolvedAt']),
      lastMessageAt: time(json['lastMessageAt']),
      messageCount: json['messageCount'] is int ? json['messageCount'] as int : 0,
    );
  }
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.authorType,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorType;
  final String body;
  final DateTime createdAt;

  bool get fromSupport => authorType == 'admin';

  static SupportTicketMessage? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    final id = json['id'];
    final authorType = json['authorType'];
    final body = json['body'];
    final createdAt = json['createdAt'];
    if (id is! String ||
        authorType is! String ||
        body is! String ||
        createdAt is! int) {
      return null;
    }
    return SupportTicketMessage(
      id: id,
      authorType: authorType,
      body: body,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    );
  }
}

class SupportTicketDetail {
  const SupportTicketDetail({
    required this.ticket,
    required this.messages,
  });

  final SupportTicketSummary ticket;
  final List<SupportTicketMessage> messages;
}

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

  Future<bool> get isLoggedIn async {
    await _session.initialize();
    return _session.userId != null;
  }

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
      final info =
          await _appInfoChannel.invokeMapMethod<String, dynamic>('appInfo');
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

  Future<List<SupportTicketSummary>> listMine() async {
    await _session.initialize();
    if (_session.userId == null) return const [];
    final data = await _api.request('/support/tickets');
    final rows = data['tickets'];
    if (rows is! List) return const [];
    return rows
        .map(SupportTicketSummary.fromJson)
        .whereType<SupportTicketSummary>()
        .toList(growable: false);
  }

  Future<SupportTicketDetail> detail(String id) async {
    await _session.initialize();
    if (_session.userId == null) {
      throw const SharedApiException(401, '请先登录后查看工单');
    }
    final data = await _api.request('/support/tickets/$id');
    final rawTicket = data['ticket'];
    if (rawTicket is! Map) {
      throw const SharedApiException(0, '工单详情响应无效');
    }
    final ticketJson = rawTicket.cast<String, dynamic>();
    final summary = SupportTicketSummary.fromJson({
      ...ticketJson,
      'messageCount': (data['messages'] as List?)?.length ?? 0,
      'lastMessageAt': (data['messages'] as List?)?.isNotEmpty == true
          ? ((data['messages'] as List).last as Map)['createdAt']
          : ticketJson['updatedAt'],
    });
    if (summary == null) {
      throw const SharedApiException(0, '工单详情响应无效');
    }
    final messages = (data['messages'] as List? ?? const [])
        .map(SupportTicketMessage.fromJson)
        .whereType<SupportTicketMessage>()
        .toList(growable: false);
    return SupportTicketDetail(ticket: summary, messages: messages);
  }

  Future<SupportTicketMessage> reply(String id, String body) async {
    await _session.initialize();
    if (_session.userId == null) {
      throw const SharedApiException(401, '请先登录后回复工单');
    }
    final data = await _api.request(
      '/support/tickets/$id/messages',
      method: 'POST',
      body: {'body': body.trim()},
    );
    final message = SupportTicketMessage.fromJson(data);
    if (message == null) {
      throw const SharedApiException(0, '工单回复响应无效');
    }
    return message;
  }
}

final supportTicketServiceProvider = Provider<SupportTicketService>((ref) {
  return SupportTicketService(
    api: ref.watch(sharedApiProvider),
    settings: ref.watch(appSettingsRepositoryProvider),
    session: ref.read(sessionRepositoryProvider),
  );
});
