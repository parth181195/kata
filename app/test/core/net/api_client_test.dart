import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/net/api_client.dart';
import 'package:kata/core/net/token_store.dart';

/// Scripted HTTP adapter: queue of (matcher, response) + request log.
class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<(bool Function(RequestOptions), ResponseBody Function(RequestOptions))> script = [];
  void on(bool Function(RequestOptions) m, ResponseBody Function(RequestOptions) r) => script.add((m, r));
  static ResponseBody json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: ['application/json']});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    for (var i = 0; i < script.length; i++) {
      if (script[i].$1(options)) {
        final r = script.removeAt(i);
        return r.$2(options);
      }
    }
    throw DioException.connectionError(requestOptions: options, reason: 'no script for ${options.path}');
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeAdapter http;
  late MemoryTokenStore store;
  var lost = 0;
  late ApiClient api;

  setUp(() async {
    http = FakeAdapter();
    store = MemoryTokenStore();
    lost = 0;
    await store.write(TokenKeys.access, 'A1');
    await store.write(TokenKeys.refresh, 'R1');
    api = ApiClient(tokens: store, base: 'https://t', adapter: http, onSessionLost: () => lost++);
  });

  test('adds bearer token', () async {
    http.on((o) => o.path == '/me', (_) => FakeAdapter.json(200, {'email': 'p@x'}));
    final r = await api.getJson('/me');
    expect(r['email'], 'p@x');
    expect(http.requests.single.headers['Authorization'], 'Bearer A1');
  });

  test('401 → refresh → retry with new token', () async {
    http.on((o) => o.path == '/me' && o.headers['Authorization'] == 'Bearer A1', (_) => FakeAdapter.json(401, {'message': 'Unauthorized'}));
    http.on((o) => o.path == '/auth/refresh', (_) => FakeAdapter.json(200, {'accessToken': 'A2', 'refreshToken': 'R2', 'expiresIn': 900}));
    http.on((o) => o.path == '/me' && o.headers['Authorization'] == 'Bearer A2', (_) => FakeAdapter.json(200, {'email': 'p@x'}));
    final r = await api.getJson('/me');
    expect(r['email'], 'p@x');
    expect(await store.read(TokenKeys.access), 'A2');
    expect(await store.read(TokenKeys.refresh), 'R2');
    expect(http.requests.map((r) => r.path).toList(), ['/me', '/auth/refresh', '/me']);
    expect(lost, 0);
  });

  test('refresh failure → session lost, store cleared, 401 surfaces', () async {
    http.on((o) => o.path == '/me', (_) => FakeAdapter.json(401, {'message': 'Unauthorized'}));
    http.on((o) => o.path == '/auth/refresh', (_) => FakeAdapter.json(401, {'message': 'Unauthorized'}));
    await expectLater(api.getJson('/me'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(lost, 1);
    expect(await store.read(TokenKeys.access), isNull);
  });

  test('network error → ApiException.isNetwork', () async {
    await expectLater(api.getJson('/recipes'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
  });
}
