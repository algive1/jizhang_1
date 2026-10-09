import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/voice/application/remote_ai_parsing_gateway.dart';

void main() {
  test('失败重试保持请求时间和标识，新解析实例使用不同标识', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <Map<String, dynamic>>[];
    server.listen((request) async {
      requests.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response.headers.contentType = ContentType.json;
      request.response.statusCode = requests.length == 1 ? 503 : 200;
      request.response.write(
        jsonEncode(
          requests.length == 1 ? {'message': 'test outage'} : {'json': '[]'},
        ),
      );
      await request.response.close();
    });
    final api = SharedApi(baseUrl: 'http://127.0.0.1:${server.port}');
    addTearDown(api.close);
    final gateway = RemoteAiParsingGateway(api, _Session(), source: 'ocr');
    await expectLater(
      gateway.parseToJson(
        text: '咖啡12元微信',
        schemaVersion: 'voice_transaction_v1',
      ),
      throwsA(isA<SharedApiException>()),
    );
    await gateway.parseToJson(
      text: '咖啡12元微信',
      schemaVersion: 'voice_transaction_v1',
    );
    expect(requests[1], requests[0]);
    expect(requests[0]['source'], 'ocr');
    await RemoteAiParsingGateway(
      api,
      _Session(),
      source: 'ocr',
    ).parseToJson(text: '咖啡12元微信', schemaVersion: 'voice_transaction_v1');
    expect(requests[2]['requestId'], isNot(requests[0]['requestId']));
    final reference = DateTime(2026, 10, 7, 12);
    for (var attempt = 0; attempt < 2; attempt++) {
      await RemoteAiParsingGateway(
        api,
        _Session(),
        source: 'natural-language',
        requestId: 'persisted-review-id',
        referenceTime: reference,
      ).parseToJson(text: '咖啡12元微信', schemaVersion: 'voice_transaction_v1');
    }
    expect(requests[3], requests[4]);
  });
}

class _Session implements SessionRepository {
  @override
  SessionUser get user => const SessionUser('test-user', 'test-user');
  @override
  Future<void> initialize() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
