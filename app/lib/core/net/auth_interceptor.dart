import 'dart:async';

import 'package:dio/dio.dart';

import 'token_store.dart';

/// Adds `Authorization: Bearer` and refreshes once on 401 (single-flight), then retries.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.dio, required this.tokens, this.onSessionLost});
  final Dio dio;
  final TokenStore tokens;
  final void Function()? onSessionLost;
  Future<bool>? _refreshing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['auth'] != false && !options.path.startsWith('/auth/')) {
      final access = await tokens.read(TokenKeys.access);
      if (access != null) options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    if (!is401 || req.path.startsWith('/auth/') || req.extra['retried'] == true) return handler.next(err);
    final ok = await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));
    if (!ok) return handler.next(err);
    try {
      final access = await tokens.read(TokenKeys.access);
      req.headers['Authorization'] = 'Bearer $access';
      req.extra['retried'] = true;
      final r = await dio.fetch<dynamic>(req);
      return handler.resolve(r);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Refresh goes through a bare client (same base URL + adapter) so it never re-enters this interceptor.
  Dio get _bare => Dio(dio.options)..httpClientAdapter = dio.httpClientAdapter;

  Future<bool> _refresh() async {
    final refresh = await tokens.read(TokenKeys.refresh);
    if (refresh == null) {
      await _lost();
      return false;
    }
    try {
      final r = await _bare.post<dynamic>('/auth/refresh', data: {'refreshToken': refresh});
      final d = (r.data as Map).cast<String, dynamic>();
      await tokens.write(TokenKeys.access, d['accessToken'] as String);
      await tokens.write(TokenKeys.refresh, d['refreshToken'] as String);
      return true;
    } on DioException {
      await _lost();
      return false;
    }
  }

  Future<void> _lost() async {
    await tokens.clear();
    onSessionLost?.call();
  }
}
