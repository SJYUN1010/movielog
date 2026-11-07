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
    debugPrint('[$tag ←] body: ${_truncate(response.data.toString())}');
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

  String _truncate(String text) {
    if (text.length <= _maxBodyLength) return text;
    return '${text.substring(0, _maxBodyLength)}... (${text.length} chars)';
  }
}
