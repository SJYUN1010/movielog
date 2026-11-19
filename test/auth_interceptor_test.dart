import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/core/network/tmdb_logging_interceptor.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';

import 'support/fakes.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'isSuccess': true, 'code': 'COMMON200', 'message': 'ok', 'result': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _client(MemoryTokenStorage storage, _RecordingAdapter adapter, {String base = 'https://workbook.devnoco.com'}) {
  final dio = Dio(BaseOptions(baseUrl: base))..httpClientAdapter = adapter;
  dio.interceptors.add(AuthInterceptor(storage, protectedHost: 'workbook.devnoco.com'));
  return dio;
}

void main() {
  group('AuthInterceptor', () {
    test('adds the Bearer token only to the protected workbook paths', () async {
      final adapter = _RecordingAdapter();
      final dio = _client(MemoryTokenStorage('jwt-1'), adapter);

      await dio.get<dynamic>('/v7/members/me');
      await dio.post<dynamic>('/v7/ratings', data: {'movieId': 1, 'score': 3});
      await dio.patch<dynamic>('/v7/ratings/9', data: {'score': 2});
      await dio.delete<dynamic>('/v7/ratings/9');

      for (final request in adapter.requests) {
        expect(request.headers['Authorization'], 'Bearer jwt-1', reason: request.path);
      }
    });

    test('does not add a token to public workbook requests', () async {
      final adapter = _RecordingAdapter();
      final dio = _client(MemoryTokenStorage('jwt-1'), adapter);

      await dio.post<dynamic>('/v7/auth/login', data: {'email': 'a@b.com', 'password': 'x'});
      await dio.post<dynamic>('/v7/members', data: {});
      await dio.get<dynamic>('/v7/members/nickname/abc');
      await dio.get<dynamic>('/v7/members/email/a@b.com');
      await dio.get<dynamic>('/v7/members/3/ratings');

      for (final request in adapter.requests) {
        expect(request.headers.containsKey('Authorization'), isFalse, reason: request.path);
      }
    });

    test('never sends the MovieLog token to another host, such as TMDB or an image CDN', () async {
      final adapter = _RecordingAdapter();
      final dio = _client(MemoryTokenStorage('jwt-1'), adapter, base: 'https://api.themoviedb.org/3');

      await dio.get<dynamic>('/v7/members/me'); // path가 같아도 host가 다릅니다.
      await dio.get<dynamic>('https://image.tmdb.org/t/p/w500/poster.jpg');

      for (final request in adapter.requests) {
        expect(request.headers.containsKey('Authorization'), isFalse, reason: request.uri.toString());
      }
    });

    test('a header copied from an earlier request is replaced by the current token', () async {
      final adapter = _RecordingAdapter();
      final storage = MemoryTokenStorage('new-token');
      final dio = _client(storage, adapter);

      await dio.get<dynamic>(
        '/v7/members/me',
        options: Options(headers: {'Authorization': 'Bearer stale-token'}),
      );
      expect(adapter.requests.single.headers['Authorization'], 'Bearer new-token');

      storage.token = null; // 토큰이 없으면 이전 헤더도 남기지 않습니다.
      await dio.get<dynamic>(
        '/v7/members/me',
        options: Options(headers: {'Authorization': 'Bearer stale-token'}),
      );
      expect(adapter.requests.last.headers.containsKey('Authorization'), isFalse);
    });

    test('reads the token on every request, so a token saved after login is used', () async {
      final adapter = _RecordingAdapter();
      final storage = MemoryTokenStorage();
      final dio = _client(storage, adapter);

      await dio.get<dynamic>('/v7/members/me');
      storage.token = 'after-login';
      await dio.get<dynamic>('/v7/members/me');

      expect(adapter.requests.first.headers.containsKey('Authorization'), isFalse);
      expect(adapter.requests.last.headers['Authorization'], 'Bearer after-login');
    });

    test('a storage failure aborts the request instead of sending it without a token', () async {
      final adapter = _RecordingAdapter();
      final storage = MemoryTokenStorage('jwt-1')..failRead = true;
      final dio = _client(storage, adapter);

      await expectLater(
        dio.get<dynamic>('/v7/members/me'),
        throwsA(
          isA<DioException>()
              .having((e) => e.error, 'error', isA<StateError>())
              .having((e) => e.response, 'response', isNull),
        ),
      );
      expect(adapter.requests, isEmpty);
    });

    test('createAuthMovieLogClient protects the host of its own base URL', () async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))..httpClientAdapter = adapter;
      final client = createAuthMovieLogClient(MemoryTokenStorage('jwt-1'), dio: dio);

      await client.get<dynamic>('/v7/members/me');
      await client.get<dynamic>('/v7/members/nickname/abc');

      expect(adapter.requests.first.headers['Authorization'], 'Bearer jwt-1');
      expect(adapter.requests.last.headers.containsKey('Authorization'), isFalse);
    });

    test('the public client has no auth interceptor at all', () {
      final publicDio = createMovieLogClient(dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080')));

      expect(publicDio.interceptors.whereType<AuthInterceptor>(), isEmpty);
    });
  });

  group('log redaction', () {
    test('hides accessToken and password values in a logged response body', () {
      final redacted = TmdbLoggingInterceptor.redactSensitive({
        'isSuccess': true,
        'result': {'nickname': '무비러버', 'accessToken': 'eyJhbGciOi.secret'},
        'password': 'Umc1234!',
      });

      final text = redacted.toString();
      expect(text, contains('무비러버'));
      expect(text, isNot(contains('eyJhbGciOi')));
      expect(text, isNot(contains('Umc1234!')));
      expect(text, contains('****'));
    });

    test('LoginResult and LoginRequest never print the token or password', () {
      const result = LoginResult(nickname: '무비러버', accessToken: 'eyJhbGciOi.secret');
      const request = LoginRequest(email: 'a@b.com', password: 'Umc1234!');

      expect('$result', isNot(contains('eyJhbGciOi')));
      expect('$request', isNot(contains('Umc1234!')));
    });
  });

  group('api error helpers', () {
    test('reads code and message from the common error body', () {
      final error = commonFailure(401, 'AUTH401_4', '토큰이 만료되었습니다.');

      expect(apiErrorCode(error), 'AUTH401_4');
      expect(apiErrorMessage(error), '토큰이 만료되었습니다.');
    });

    test('returns null for network failures and bodies of another shape', () {
      expect(apiErrorCode(dioFailure('/x')), isNull);
      expect(apiErrorMessage(dioFailure('/x', statusCode: 500, data: 'oops')), isNull);
      expect(apiErrorCode(dioFailure('/x', statusCode: 400, data: {'code': 3})), isNull);
    });

    test('only AUTH401_2/3/4 count as an expired session; AUTH401_1 and 403 do not', () {
      expect(isSessionExpiredCode('AUTH401_2'), isTrue);
      expect(isSessionExpiredCode('AUTH401_3'), isTrue);
      expect(isSessionExpiredCode('AUTH401_4'), isTrue);
      expect(isSessionExpiredCode('AUTH401_1'), isFalse);
      expect(isSessionExpiredCode('RATING403_1'), isFalse);
      expect(isSessionExpiredCode(null), isFalse);
    });
  });

  group('authRedirect', () {
    test('keeps the splash while initializing or when the check needs a retry', () {
      for (final status in [AuthStatus.initializing, AuthStatus.retryRequired]) {
        expect(authRedirect(status, '/start'), isNull);
        expect(authRedirect(status, '/login'), '/start');
        expect(authRedirect(status, '/home'), '/start');
        expect(authRedirect(status, '/my/ratings'), '/start');
      }
    });

    test('signed out users can only see the public screens', () {
      for (final status in [AuthStatus.signedOut, AuthStatus.authenticating]) {
        expect(authRedirect(status, '/login'), isNull);
        expect(authRedirect(status, '/signup'), isNull);
        expect(authRedirect(status, '/home'), '/login');
        expect(authRedirect(status, '/my'), '/login');
        expect(authRedirect(status, '/my/profile/edit'), '/login');
        expect(authRedirect(status, '/movies/550'), '/login');
        expect(authRedirect(status, '/start'), '/login');
      }
    });

    test('signed in users are sent home from the splash and the login screens', () {
      expect(authRedirect(AuthStatus.signedIn, '/start'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/login'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/signup'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/my'), isNull);
      expect(authRedirect(AuthStatus.signedIn, '/my/ratings'), isNull);
    });
  });
}
