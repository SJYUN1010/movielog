import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'tmdb_logging_interceptor.dart';

class TmdbClient {
  TmdbClient({required String accessToken, Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Authorization': 'Bearer $accessToken',
                'accept': 'application/json',
              },
              queryParameters: {'language': 'ko-KR'},
            ),
          ) {
    if (kDebugMode) {
      this.dio.interceptors.add(TmdbLoggingInterceptor());
    }
  }

  static const baseUrl = 'https://api.themoviedb.org/3';
  static const imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  final Dio dio;
}
