import 'dart:convert';
import 'dart:io';

class SharedApiException implements Exception {
  const SharedApiException(this.status, this.message, [this.details]);
  final int status;
  final String message;
  final Map<String, dynamic>? details;
  @override
  String toString() => message;
}

class SharedApi {
  SharedApi({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'SHARED_API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8787',
          ) {
    final uri = Uri.parse(this.baseUrl);
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host))) {
      throw ArgumentError('共享服务仅允许 HTTPS 或本机联调地址');
    }
  }
  final String baseUrl;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  String? sessionToken;
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    final request = await _client.openUrl(
      method,
      Uri.parse('$baseUrl/api/v1$path'),
    );
    if (sessionToken != null)
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $sessionToken',
      );
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 20));
    final raw = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(raw);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'message': raw};
    if (response.statusCode >= 400)
      throw SharedApiException(
        response.statusCode,
        data['message'] as String? ?? '共享服务请求失败',
        data['details'] is Map
            ? (data['details'] as Map).cast<String, dynamic>()
            : null,
      );
    return data;
  }

  void close() => _client.close(force: true);
}
