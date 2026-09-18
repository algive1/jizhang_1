// 账户体系回归测试共用的最小 HTTP 桩。
//
// 它只提供测试真正需要的端点，但会记录**每一条**请求（含 Authorization 头），
// 这样测试才能断言“被 401 拒绝的 Token 之后绝没有再被发出去”、
// “登录本身没有触发任何云同步请求”这类只能用请求流量证明的事实。
//
// 这不是业务代码的替身：客户端一侧走的是真实 SharedApi、真实 HttpClient、
// 真实 SessionRepository 与真实共享同步服务，只有服务端被替换成一个确定性的桩。
import 'dart:convert';
import 'dart:io';

/// 服务器返回的一条应答。
class StubResponse {
  const StubResponse(this.status, [this.body = const {}]);

  final int status;
  final Map<String, dynamic> body;

  /// 服务器明确拒绝：登录态失效。
  static const unauthorized = StubResponse(401, {'message': '登录状态已失效'});

  /// 服务器自己出错：与登录态无关，客户端不得据此退出登录。
  static const unavailable = StubResponse(503, {'message': '服务暂时不可用'});
}

/// 被记录下来的请求。
class StubRequest {
  const StubRequest({
    required this.method,
    required this.path,
    required this.authorization,
  });

  final String method;
  final String path;
  final String? authorization;

  /// `Bearer <token>` 里的 Token；没有 Authorization 头时为 null。
  String? get token => authorization != null && authorization!.startsWith('Bearer ')
      ? authorization!.substring('Bearer '.length)
      : null;

  @override
  String toString() => '$method $path (authorization=$authorization)';
}

/// 绑定在 127.0.0.1 随机端口上的确定性服务端。
class AccountHttpStub {
  AccountHttpStub._(this._server, this._baseUrl);

  final HttpServer _server;

  /// 启动时固定下来的地址：服务器关闭后仍可读取，测试才能重建一个
  /// 指向同一个（已经下线的）地址的客户端。
  final String _baseUrl;

  final requests = <StubRequest>[];

  /// 由测试设置的应答函数；未设置的路径返回 404。
  StubResponse Function(StubRequest request) respond = (_) =>
      const StubResponse(404, {'message': '未配置的端点'});

  String get baseUrl => _baseUrl;

  static Future<AccountHttpStub> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final stub = AccountHttpStub._(server, 'http://127.0.0.1:${server.port}');
    server.listen((request) async {
      final recorded = StubRequest(
        method: request.method,
        path: request.uri.path,
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
      );
      stub.requests.add(recorded);
      final response = stub.respond(recorded);
      request.response.statusCode = response.status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response.body));
      await request.response.close();
    });
    return stub;
  }

  /// 关掉服务器：之后的请求会以连接失败（SocketException）告终。
  Future<void> stop() async {
    await _server.close(force: true);
  }

  /// 带上某个 Token 的请求，用来证明它是否真的被复用。
  List<StubRequest> requestsWithToken(String token) =>
      requests.where((request) => request.token == token).toList();

  List<String> get paths => requests.map((request) => request.path).toList();
}

/// 标准账户端点：登录/注册成功、登出成功，`/books` 由调用方决定如何应答。
StubResponse Function(StubRequest request) accountRoutes({
  StubResponse books = StubResponse.unauthorized,
  String userId = 'server-user-id',
  String username = 'lu_2026',
  String? displayName,
  String token = 'server-token-1',
  int validDays = 30,
}) => (request) => switch (request.path) {
  '/api/v1/auth/login' || '/api/v1/auth/register' => StubResponse(200, {
    'token': token,
    'expiresAt':
        DateTime.now().add(Duration(days: validDays)).millisecondsSinceEpoch ~/
        1000,
    'user': {
      'id': userId,
      'username': username,
      'displayName': displayName,
    },
  }),
  '/api/v1/auth/logout' => const StubResponse(200),
  '/api/v1/books' => books,
  _ => const StubResponse(404, {'message': '未配置的端点'}),
};
