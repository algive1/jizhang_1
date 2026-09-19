import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../domain/transaction_parser.dart';

/// Real AI fallback for voice/text bookkeeping.
///
/// Authentication, membership, quotas, model credentials and strict response
/// validation all live on the app server. The client receives only the
/// normalized JSON array expected by [AiTransactionJsonDecoder].
class RemoteAiParsingGateway implements AiParsingGateway {
  RemoteAiParsingGateway(this._api, this._session);

  final SharedApi _api;
  final SessionRepository _session;

  @override
  Future<String> parseToJson({
    required String text,
    required String schemaVersion,
  }) async {
    await _session.initialize();
    if (_session.user == null) {
      throw StateError('AI解析需要先登录账号');
    }
    final now = DateTime.now();
    final data = await _api.request(
      '/assistant/parse-transaction',
      method: 'POST',
      body: {
        'requestId': _requestId(text, schemaVersion, now),
        'text': text,
        'schemaVersion': schemaVersion,
        'now': now.toUtc().toIso8601String(),
        'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      },
    );
    final raw = data['json'];
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('AI解析响应缺少交易 JSON');
    }
    return raw;
  }

  String _requestId(String text, String schemaVersion, DateTime now) {
    // Retrying within the same five-minute bucket reuses the idempotency key,
    // so a timeout does not consume the model quota twice.
    final bucket = now.millisecondsSinceEpoch ~/ const Duration(minutes: 5).inMilliseconds;
    var hash = 0x811c9dc5;
    for (final unit in '$schemaVersion|$text'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'voice-${bucket.toRadixString(16).padLeft(12, '0')}-${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
