import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';

void main() {
  test('API base normalizes trailing slashes and rejects credentials and remote plaintext', () {
    final api = SharedApi(baseUrl: ' http://127.0.0.1:8787/ ');
    addTearDown(api.close);
    expect(api.baseUrl, 'http://127.0.0.1:8787');
    expect(
      () => SharedApi(baseUrl: 'https://user:secret@example.com'),
      throwsArgumentError,
    );
    expect(
      () => SharedApi(baseUrl: 'https://example.com?token=secret'),
      throwsArgumentError,
    );
    expect(() => SharedApi(baseUrl: 'http://example.com'), throwsArgumentError);
  });
  test('API preserves captured authentication and operational identity across real HTTP', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = SharedApi(baseUrl: 'http://127.0.0.1:${server.port}/')
      ..sessionToken = 'new-session'
      ..installationId = 'a' * 32;
    addTearDown(api.close);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.uri.path, '/api/v1/app/heartbeat');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer captured-session',
      );
      expect(request.headers.value('x-app-installation-id'), 'a' * 32);
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'backupEnabled': false,
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":true}');
      await request.response.close();
    });
    expect(
      await api.request(
        '/app/heartbeat',
        method: 'POST',
        bearerToken: 'captured-session',
        body: {'backupEnabled': false},
      ),
      {'ok': true},
    );
  });
  test('HTML proxy errors do not expose raw response content', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = SharedApi(baseUrl: 'http://127.0.0.1:${server.port}');
    addTearDown(api.close);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = 502;
      request.response.write('<html>internal proxy details</html>');
      await request.response.close();
    });
    await expectLater(
      api.request('/app/config'),
      throwsA(
        isA<SharedApiException>()
            .having((e) => e.status, 'status', 502)
            .having((e) => e.message, 'message', '服务返回了无效响应，请稍后重试'),
      ),
    );
  });
}
