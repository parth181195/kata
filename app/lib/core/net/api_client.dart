import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_interceptor.dart';
import 'token_store.dart';

/// Base URL; override with --dart-define=KATA_API=http://10.0.2.2:5090 for local dev.
const kApiBase = String.fromEnvironment('KATA_API', defaultValue: 'https://api.kata.parthjansari.dev');

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.body, this.isNetwork = false});
  final String message;
  final int? status;
  final Object? body;
  final bool isNetwork;
  @override
  String toString() => 'ApiException(${status ?? 'net'}): $message';

  static ApiException from(DioException e) {
    final r = e.response;
    if (r != null) {
      final b = r.data;
      final msg = b is Map && b['message'] != null ? '${b['message']}' : (r.statusMessage ?? 'HTTP ${r.statusCode}');
      return ApiException(msg, status: r.statusCode, body: b);
    }
    return ApiException(e.message ?? 'Network error', isNetwork: true);
  }
}

class ApiClient {
  ApiClient({required TokenStore tokens, String base = kApiBase, HttpClientAdapter? adapter, void Function()? onSessionLost}) : _tokens = tokens {
    dio = Dio(BaseOptions(baseUrl: base, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20), headers: {'Accept': 'application/json'}));
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(dio: dio, tokens: tokens, onSessionLost: onSessionLost));
  }

  late final Dio dio;
  final TokenStore _tokens;
  TokenStore get tokens => _tokens;

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await dio.get<dynamic>(path, queryParameters: query);
      return _asMap(r.data);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body, {bool auth = true}) async {
    try {
      final r = await dio.post<dynamic>(path, data: body, options: Options(extra: {'auth': auth}));
      return _asMap(r.data);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body) async {
    try {
      final r = await dio.patch<dynamic>(path, data: body);
      return _asMap(r.data);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> put(String path, {Map<String, dynamic>? body}) async {
    try {
      await dio.put<dynamic>(path, data: body);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await dio.delete<dynamic>(path);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  static Map<String, dynamic> _asMap(dynamic d) => d is Map<String, dynamic> ? d : (d is Map ? d.cast<String, dynamic>() : <String, dynamic>{});
}

final tokenStoreProvider = Provider<TokenStore>((_) => SecureTokenStore());
final sessionLostProvider = StateProvider<int>((_) => 0); // bumped by the interceptor when refresh fails
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(tokens: ref.watch(tokenStoreProvider), onSessionLost: () => ref.read(sessionLostProvider.notifier).state++));
