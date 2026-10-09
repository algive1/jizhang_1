import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../domain/transaction_parser.dart';
import '../../../core/utils/entity_id.dart';

/// Real AI fallback for voice/text bookkeeping.
///
/// Authentication, membership, quotas, model credentials and strict response
/// validation all live on the app server. The client receives only the
/// normalized JSON array expected by [AiTransactionJsonDecoder].
class RemoteAiParsingGateway implements AiParsingGateway {
  RemoteAiParsingGateway(
    this._api,
    this._session, {
    this.source = 'voice',
    this.requestId,
    this.referenceTime,
  });

  final SharedApi _api;
  final SessionRepository _session;
  final String source;
  final String? requestId;
  final DateTime? referenceTime;
  final Map<String, Map<String, Object?>> _requests = {};

  @override
  Future<String> parseToJson({
    required String text,
    required String schemaVersion,
  }) async {
    await _session.initialize();
    if (_session.user == null) {
      throw StateError('AI解析需要先登录账号');
    }
    final now = referenceTime ?? DateTime.now();
    final key =
        '$schemaVersion|$text|${now.millisecondsSinceEpoch ~/ const Duration(minutes: 5).inMilliseconds}';
    final body = _requests.putIfAbsent(
      key,
      () => {
        'requestId': requestId ?? newEntityId(),
        'text': text,
        'source': source,
        'schemaVersion': schemaVersion,
        'now': now.toUtc().toIso8601String(),
        'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      },
    );
    final data = await _api.request(
      '/assistant/parse-transaction',
      method: 'POST',
      body: body,
    );
    final raw = data['json'];
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('AI解析响应缺少交易 JSON');
    }
    return raw;
  }
}
