import 'dart:convert';
import 'dart:io';
import 'dart:async';

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
          (baseUrl ??
                  const String.fromEnvironment(
                    'SHARED_API_BASE_URL',
                    defaultValue: 'http://127.0.0.1:8787',
                  ))
              .trim()
              .replaceFirst(RegExp(r'/+$'), '') {
    final uri = Uri.parse(this.baseUrl);
    if (uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.host.isEmpty) {
      throw ArgumentError('共享服务地址不能包含登录信息、查询参数或片段');
    }
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
  String? installationId;
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? body,
    String? bearerToken,
  }) async {
    try {
      return await _request(
        path,
        method: method,
        body: body,
        bearerToken: bearerToken,
      );
    } on TimeoutException {
      throw const SharedApiException(0, '请求超时，请稍后重试');
    } on SocketException {
      throw const SharedApiException(0, '无法连接服务，请检查网络后重试');
    } on HandshakeException {
      throw const SharedApiException(0, '无法建立安全连接，请稍后重试');
    } on HttpException {
      throw const SharedApiException(0, '连接中断，请稍后重试');
    }
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    required String method,
    Object? body,
    String? bearerToken,
  }) async {
    final request = await _client.openUrl(
      method,
      Uri.parse('$baseUrl/api/v1$path'),
    );
    final token = bearerToken ?? sessionToken;
    if (token != null)
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (installationId != null) {
      request.headers.set('X-App-Installation-Id', installationId!);
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 20));
    final raw = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 20));
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw SharedApiException(response.statusCode, '服务返回了无效响应，请稍后重试');
    }
    if (decoded is! Map<String, dynamic>) {
      throw SharedApiException(response.statusCode, '服务返回了无效响应，请稍后重试');
    }
    final data = decoded;
    if (response.statusCode >= 400)
      throw SharedApiException(
        response.statusCode,
        data['message'] is String ? data['message'] as String : '共享服务请求失败',
        data['details'] is Map
            ? (data['details'] as Map).cast<String, dynamic>()
            : null,
      );
    return data;
  }

  void close() => _client.close(force: true);
}
