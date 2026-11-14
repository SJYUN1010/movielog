import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/data/dto/tmdb_movie_dto.dart';
import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'support/fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final Object body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_StubAdapter adapter, {String baseUrl = movieLogBaseUrl}) {
  return Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
}

void main() {
  group('ApiDelayInterceptor', () {
    test('waits for the delay before the request is sent', () async {
      final adapter = _StubAdapter(200, {'available': true});
      final dio = _dio(adapter)
        ..interceptors.add(ApiDelayInterceptor(const Duration(milliseconds: 120)));
      final stopwatch = Stopwatch()..start();

      await SignUpService(dio).checkNickname('새닉네임');

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(110));
      expect(adapter.requests, hasLength(1));
    });

    test('is off by default', () {
      expect(apiDelayMs, 0);
    });
  });

  group('v5/v6 shared models', () {
    test('CheckResult reads the bare { available } body without a wrapper', () {
      expect(CheckResult.fromJson({'available': true}).available, isTrue);
      expect(CheckResult.fromJson({'available': false}).available, isFalse);
    });

    test('RatingDto keeps a null comment and parses the UTC date', () {
      final rating = RatingDto.fromJson({
        'ratingId': 3,
        'movieId': 13,
        'score': 3,
        'comment': null,
        'createdAt': '2026-10-31T19:00:27.994Z',
        'updatedAt': '2026-10-31T19:00:27.994Z',
      });

      expect(rating.ratingId, 3);
      expect(rating.movieId, 13);
      expect(rating.score, 3);
      expect(rating.comment, isNull);
      expect(rating.createdAt.isUtc, isTrue);
      expect(rating.createdAt.year, 2026);
    });
  });

  group('SignUpService', () {
    test('calls the nickname path and percent-encodes Korean text once', () async {
      final adapter = _StubAdapter(200, {'available': false});
      final service = SignUpService(_dio(adapter));

      final available = await service.checkNickname('  영화광  ');

      expect(available, isFalse);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(
        request.uri.toString(),
        'https://workbook.devnoco.com/v6/members/nickname/'
        '${Uri.encodeComponent('영화광')}',
      );
      expect(request.uri.path, contains('%EC%98%81%ED%99%94%EA%B4%91'));
      expect(request.uri.toString(), isNot(contains('%25')));
    });

    test('encodes @ in the email path', () async {
      final adapter = _StubAdapter(200, {'available': true});
      final service = SignUpService(_dio(adapter));

      final available = await service.checkEmail('movie@umc.com');

      expect(available, isTrue);
      expect(adapter.requests.single.uri.toString(), endsWith('/v6/members/email/movie%40umc.com'));
    });

    test('a failure response surfaces as DioException, not as available: false', () async {
      final adapter = _StubAdapter(500, {'message': 'error', 'statusCode': 500});
      final service = SignUpService(_dio(adapter));

      expect(service.checkNickname('영화광'), throwsA(isA<DioException>()));
    });
  });

  group('RatingApiService', () {
    test('parses the array body and calls /v6/members/{id}/ratings', () async {
      final adapter = _StubAdapter(200, [
        {
          'ratingId': 2,
          'movieId': 680,
          'score': 4,
          'comment': '다시 봐도 좋다',
          'createdAt': '2026-10-31T19:00:27.994Z',
          'updatedAt': '2026-10-31T19:00:27.994Z',
        },
        {
          'ratingId': 3,
          'movieId': 13,
          'score': 3,
          'comment': null,
          'createdAt': '2026-10-31T19:00:27.994Z',
          'updatedAt': '2026-10-31T19:00:27.994Z',
        },
      ]);
      final service = RatingApiService(_dio(adapter));

      final ratings = await service.fetchMyRatings(1);

      expect(adapter.requests.single.uri.path, '/v6/members/1/ratings');
      expect(ratings.map((r) => r.movieId), [680, 13]);
      expect(ratings.last.comment, isNull);
    });

    test('an empty array is an empty list, not a failure', () async {
      final service = RatingApiService(_dio(_StubAdapter(200, <dynamic>[])));

      expect(await service.fetchMyRatings(3), isEmpty);
    });

    test('shows the server message when the body is a common response, else a fallback', () {
      expect(
        writeErrorMessage(commonFailure(404, 'COMMON404', '존재하지 않는 유저입니다.')),
        '존재하지 않는 유저입니다.',
      );
      const fallback = '평점을 불러오지 못했습니다.';
      expect(writeErrorMessage(dioFailure('/x'), fallback: fallback), fallback);
      expect(writeErrorMessage(dioFailure('/x', statusCode: 500), fallback: fallback), fallback);
      // 본문이 공통 응답 모양이 아니면 서버 문구로 착각하지 않고 fallback을 씁니다.
      expect(
        writeErrorMessage(
          dioFailure('/x', statusCode: 400, data: {'message': 'Bad', 'statusCode': 400}),
          fallback: fallback,
        ),
        fallback,
      );
    });

    test('a 404 body is thrown as DioException with the status code', () async {
      final adapter = _StubAdapter(404, {
        'isSuccess': false,
        'code': 'COMMON404',
        'message': '존재하지 않는 유저입니다.',
        'result': null,
      });
      final service = RatingApiService(_dio(adapter));

      await expectLater(
        service.fetchMyRatings(999999),
        throwsA(
          isA<DioException>().having((e) => e.response?.statusCode, 'status', 404),
        ),
      );
    });
  });

  group('TmdbMovieService movie detail', () {
    final detailJson = {
      'id': 550,
      'title': '파이트 클럽',
      'overview': '줄거리',
      'poster_path': '/poster.jpg',
      'genres': [
        {'id': 18, 'name': '드라마'},
        {'id': 53, 'name': '스릴러'},
      ],
      'release_date': '1999-10-15',
      'vote_average': 8.4,
      'vote_count': 30000,
    };

    test('fetchMovieDetail calls /movie/{id} and reads genres into genreIds', () async {
      final adapter = _StubAdapter(200, detailJson);
      final service = TmdbMovieService(_dio(adapter, baseUrl: TmdbClient.baseUrl));

      final movie = await service.fetchMovieDetail(550);

      expect(adapter.requests.single.uri.path, '/3/movie/550');
      expect(movie.id, 550);
      expect(movie.genreIds, [18, 53]);
    });

    test('list responses still read genre_ids', () {
      final movie = TmdbMovieDto.fromJson({
        'id': 1,
        'title': 'a',
        'overview': '',
        'genre_ids': [28, 12],
      });

      expect(movie.genreIds, [28, 12]);
    });

    test('findMovieById turns only 404 into null', () async {
      final notFound = TmdbMovieService(
        _dio(_StubAdapter(404, {'success': false}), baseUrl: TmdbClient.baseUrl),
      );
      expect(await notFound.findMovieById(13), isNull);

      final serverError = TmdbMovieService(
        _dio(_StubAdapter(500, {'success': false}), baseUrl: TmdbClient.baseUrl),
      );
      await expectLater(serverError.findMovieById(13), throwsA(isA<DioException>()));
    });
  });
}
