import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// 보호 대상 워크북 요청에만 `Authorization: Bearer {accessToken}`을 붙입니다.
///
/// - 이 Interceptor는 보호용 Client에만 등록합니다. 로그인·중복 확인 같은 공개 요청의 Client와
///   TMDB Client에는 등록하지 않습니다(TMDB 요청에 MovieLog JWT가 실리면 안 됩니다).
/// - Client에 등록해도 host와 path가 보호 대상이 아니면 토큰을 붙이지 않습니다.
/// - BuildContext를 쓰지 않습니다. 만료 안내와 화면 이동은 ViewModel과 Router가 맡습니다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {required this.protectedHost});

  final TokenStorage _storage;

  /// 토큰을 보낼 워크북 서버 host입니다(예: `workbook.devnoco.com`).
  final String protectedHost;

  bool _isProtected(RequestOptions options) {
    final uri = options.uri;
    final path = uri.path;
    return uri.host == protectedHost &&
        (path == '/v7/members/me' ||
            path == '/v7/ratings' ||
            path.startsWith('/v7/ratings/'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isProtected(options)) {
      handler.next(options);
      return;
    }

    // 이전 요청에서 복사된 헤더가 있어도 현재 저장소의 토큰만 사용합니다.
    options.headers.remove('Authorization');
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      // 서버 401과 기기 저장소 읽기 실패는 다른 문제입니다. 토큰 없이 보내지 않고 요청을 중단합니다.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}
