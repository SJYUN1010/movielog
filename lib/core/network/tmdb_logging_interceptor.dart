import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TmdbLoggingInterceptor extends Interceptor {
  TmdbLoggingInterceptor({this.tag = 'TMDB'});

  static const _maxBodyLength = 600;

  /// 로그 접두어입니다. 워크북 백엔드 Client는 'MovieLog'를 넘겨 TMDB 로그와 구분합니다.
  final String tag;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[$tag →] ${options.method} ${options.uri}');
    debugPrint('[$tag →] query: ${options.queryParameters}');
    debugPrint('[$tag →] headers: ${_maskHeaders(options.headers)}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[$tag ←] ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri}',
    );
    // 로그인 응답의 accessToken처럼 민감한 값은 로그에 남기지 않습니다.
    debugPrint('[$tag ←] body: ${_truncate(redactSensitive(response.data).toString())}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    debugPrint(
      '[$tag ✕] ${err.response?.statusCode ?? err.type.name} '
      '${request.method} ${request.uri}',
    );
    debugPrint('[$tag ✕] query: ${request.queryParameters}');
    debugPrint('[$tag ✕] message: ${err.message}');
    handler.next(err);
  }

  Map<String, dynamic> _maskHeaders(Map<String, dynamic> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: entry.key.toLowerCase() == 'authorization'
            ? 'Bearer ****'
            : entry.value,
    };
  }

  /// 로그에 남기면 안 되는 key입니다. 값은 `****`로 바꿉니다.
  static const _sensitiveKeys = {'accesstoken', 'refreshtoken', 'token', 'password'};

  /// JSON 응답 안의 토큰·비밀번호 값을 가립니다. 원본 객체는 바꾸지 않습니다.
  @visibleForTesting
  static Object? redactSensitive(Object? data) {
    if (data is Map) {
      return {
        for (final entry in data.entries)
          entry.key: _sensitiveKeys.contains(entry.key.toString().toLowerCase())
              ? '****'
              : redactSensitive(entry.value),
      };
    }
    if (data is List) return [for (final item in data) redactSensitive(item)];
    return data;
  }

  String _truncate(String text) {
    if (text.length <= _maxBodyLength) return text;
    return '${text.substring(0, _maxBodyLength)}... (${text.length} chars)';
  }
}
