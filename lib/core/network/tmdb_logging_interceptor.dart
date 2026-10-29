import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TmdbLoggingInterceptor extends Interceptor {
  static const _maxBodyLength = 600;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[TMDB →] ${options.method} ${options.uri}');
    debugPrint('[TMDB →] query: ${options.queryParameters}');
    debugPrint('[TMDB →] headers: ${_maskHeaders(options.headers)}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[TMDB ←] ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri}',
    );
    debugPrint('[TMDB ←] body: ${_truncate(response.data.toString())}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    debugPrint(
      '[TMDB ✕] ${err.response?.statusCode ?? err.type.name} '
      '${request.method} ${request.uri}',
    );
    debugPrint('[TMDB ✕] query: ${request.queryParameters}');
    debugPrint('[TMDB ✕] message: ${err.message}');
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
