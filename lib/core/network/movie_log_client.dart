import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'tmdb_logging_interceptor.dart';

/// 워크북 백엔드 주소입니다. 서버에 쓰기 요청을 보내지 않고 화면 흐름만 확인할 때
/// `--dart-define=MOVIELOG_BASE_URL=http://localhost:8080`처럼 로컬 서버로 바꿉니다.
const movieLogBaseUrl = String.fromEnvironment(
  'MOVIELOG_BASE_URL',
  defaultValue: 'https://workbook.devnoco.com',
);

/// 화면 캡처용 지연(ms)입니다. 통신 중(Loading) 화면이 너무 빨리 지나갈 때만
/// `--dart-define=API_DELAY_MS=1500`처럼 켭니다. 기본값 0은 지연이 없다는 뜻입니다.
const int apiDelayMs = int.fromEnvironment('API_DELAY_MS', defaultValue: 0);

/// 요청을 서버로 보내기 전에 [delay]만큼 기다립니다.
class ApiDelayInterceptor extends Interceptor {
  ApiDelayInterceptor(this.delay);

  final Duration delay;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await Future<void>.delayed(delay);
    handler.next(options);
  }
}

/// 워크북 자체 백엔드(/v6)용 Client입니다. TMDB Client와 baseUrl, 헤더가 달라 합치지 않습니다.
/// 요청 body(비밀번호 포함)는 로그에 남기지 않습니다.
Dio createMovieLogClient({Dio? dio}) {
  final client =
      dio ??
      Dio(
        BaseOptions(
          baseUrl: movieLogBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'accept': 'application/json'},
        ),
      );
  if (kDebugMode) {
    if (apiDelayMs > 0) {
      client.interceptors.add(ApiDelayInterceptor(Duration(milliseconds: apiDelayMs)));
    }
    client.interceptors.add(TmdbLoggingInterceptor(tag: 'MovieLog'));
  }
  return client;
}

/// Provider로 앱 전체에 한 번만 등록해 서비스들이 같은 Dio를 공유합니다.
class MovieLogClient {
  MovieLogClient({Dio? dio}) : dio = createMovieLogClient(dio: dio);

  final Dio dio;
}
