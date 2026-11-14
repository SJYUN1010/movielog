import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

import 'support/fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, [this.body]);

  final int status;
  final Object? body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        if (body != null) Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_StubAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
    ..httpClientAdapter = adapter;
}

void main() {
  group('CommonResponse<T>', () {
    test('parses isSuccess, code, message and a typed result', () {
      final response = CommonResponse<SignUpResult>.fromJson(
        {
          'isSuccess': true,
          'code': 'COMMON201',
          'message': '회원가입에 성공했습니다.',
          'result': {'memberId': 7, 'email': 'a@b.com', 'nickname': '무비러버'},
        },
        (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
      );

      expect(response.isSuccess, isTrue);
      expect(response.code, 'COMMON201');
      expect(response.result?.memberId, 7);
      expect(response.result?.nickname, '무비러버');
    });

    test('a null result stays null and the parser is not called', () {
      final response = CommonResponse<int>.fromJson(
        {'isSuccess': false, 'code': 'COMMON409', 'message': '중복', 'result': null},
        (value) => throw StateError('should not be called'),
      );

      expect(response.isSuccess, isFalse);
      expect(response.result, isNull);
    });
  });

  group('request models', () {
    test('CreateMemberRequest trims email and nickname but never the password', () {
      const request = CreateMemberRequest(
        email: '  new@umc.com ',
        password: ' Pass word1! ',
        nickname: '  무비러버 ',
      );

      expect(request.toJson(), {
        'email': 'new@umc.com',
        'password': ' Pass word1! ',
        'nickname': '무비러버',
      });
    });

    test('CreateRatingRequest omits a blank comment and trims a real one', () {
      expect(const CreateRatingRequest(movieId: 550, score: 4).toJson(), {
        'movieId': 550,
        'score': 4,
      });
      expect(const CreateRatingRequest(movieId: 550, score: 4, comment: '   ').toJson(), {
        'movieId': 550,
        'score': 4,
      });
      expect(const CreateRatingRequest(movieId: 550, score: 4, comment: ' 좋아요 ').toJson(), {
        'movieId': 550,
        'score': 4,
        'comment': '좋아요',
      });
    });

    test('validateServerScore only accepts whole numbers from 1 to 5', () {
      expect(validateServerScore(1.0), 1);
      expect(validateServerScore(5.0), 5);
      expect(() => validateServerScore(0.5), throwsArgumentError);
      expect(() => validateServerScore(2.5), throwsArgumentError);
      expect(() => validateServerScore(0), throwsArgumentError);
      expect(() => validateServerScore(6), throwsArgumentError);
    });
  });

  group('SignUpService (v7)', () {
    test('checks use /v7 paths', () async {
      final nickname = _StubAdapter(200, {'available': true});
      expect(await SignUpService(_dio(nickname)).checkNickname('movielover'), isTrue);
      expect(nickname.requests.single.uri.path, '/v7/members/nickname/movielover');

      final email = _StubAdapter(200, {'available': false});
      expect(await SignUpService(_dio(email)).checkEmail('movie@umc.com'), isFalse);
      expect(email.requests.single.uri.toString(), endsWith('/v7/members/email/movie%40umc.com'));
    });

    test('signUp posts the request body to /v7/members and reads memberId from the result', () async {
      final adapter = _StubAdapter(201, {
        'isSuccess': true,
        'code': 'COMMON201',
        'message': '회원가입에 성공했습니다.',
        'result': {'memberId': 31, 'email': 'new@umc.com', 'nickname': '무비러버'},
      });

      final response = await SignUpService(_dio(adapter)).signUp(
        const CreateMemberRequest(email: 'new@umc.com', password: 'Passw0rd!', nickname: '무비러버'),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v7/members');
      expect(request.data, {
        'email': 'new@umc.com',
        'password': 'Passw0rd!',
        'nickname': '무비러버',
      });
      expect(response.result?.memberId, 31);
    });

    test('a 409 is thrown as DioException and its server message is what the user sees', () async {
      final adapter = _StubAdapter(409, {
        'isSuccess': false,
        'code': 'COMMON409',
        'message': '이미 사용 중인 이메일입니다.',
        'result': null,
      });

      Object? caught;
      try {
        await SignUpService(_dio(adapter)).signUp(
          const CreateMemberRequest(email: 'a@b.com', password: 'Passw0rd!', nickname: '무비러버'),
        );
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<DioException>());
      final error = caught! as DioException;
      expect(error.response?.statusCode, 409);
      expect(writeSignUpErrorMessage(error), '이미 사용 중인 이메일입니다.');
    });

    test('writeSignUpErrorMessage falls back for network failures and odd bodies', () {
      const fallback = '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      expect(writeSignUpErrorMessage(dioFailure('/x')), fallback);
      expect(writeSignUpErrorMessage(dioFailure('/x', statusCode: 500, data: 'oops')), fallback);
      expect(
        writeSignUpErrorMessage(dioFailure('/x', statusCode: 400, data: {'message': 3})),
        fallback,
      );
    });
  });

  group('AuthApiService.login (v7)', () {
    test('posts the trimmed email and password and parses nickname and accessToken', () async {
      final adapter = _StubAdapter(200, {
        'isSuccess': true,
        'code': 'COMMON200',
        'message': '로그인에 성공했습니다.',
        'result': {'nickname': '무비러버', 'accessToken': 'jwt.value'},
      });

      final result = await AuthApiService(_dio(adapter)).login(
        const LoginRequest(email: ' movie@umc.com ', password: 'Umc1234!'),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v7/auth/login');
      expect(request.data, {'email': 'movie@umc.com', 'password': 'Umc1234!'});
      expect(result.nickname, '무비러버');
      expect(result.accessToken, 'jwt.value');
    });

    test('there is no memberId in the result and none is invented', () {
      final result = LoginResult.fromJson({'nickname': 'a', 'accessToken': 't'});

      expect(result.toString(), isNot(contains('memberId')));
    });

    test('AUTH401_1 is a DioException with its own code, separate from the expiry codes', () async {
      final adapter = _StubAdapter(401, {
        'isSuccess': false,
        'code': 'AUTH401_1',
        'message': '이메일 또는 비밀번호가 올바르지 않습니다.',
        'result': null,
      });

      Object? caught;
      try {
        await AuthApiService(_dio(adapter)).login(
          const LoginRequest(email: 'a@b.com', password: 'x'),
        );
      } catch (error) {
        caught = error;
      }

      final error = caught! as DioException;
      expect(apiErrorCode(error), 'AUTH401_1');
      expect(isSessionExpiredError(error), isFalse);
    });

    test('a malformed login body is a StateError, not a crash', () async {
      final adapter = _StubAdapter(200, {'isSuccess': true, 'code': 'x', 'message': 'm', 'result': null});

      await expectLater(
        AuthApiService(_dio(adapter)).login(const LoginRequest(email: 'a@b.com', password: 'x')),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('MemberApiService (v7)', () {
    const meBody = {
      'isSuccess': true,
      'code': 'COMMON200',
      'message': '회원 정보를 조회했습니다.',
      'result': {'email': 'movie@umc.com', 'nickname': '영화광', 'createdAt': '2026-10-10T03:00:00.000Z'},
    };

    test('fetchMe calls GET /v7/members/me and parses email, nickname and createdAt', () async {
      final adapter = _StubAdapter(200, meBody);

      final member = await MemberApiService(_dio(adapter)).fetchMe();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/v7/members/me');
      expect(member.email, 'movie@umc.com');
      expect(member.nickname, '영화광');
      expect(member.createdAt, DateTime.utc(2026, 10, 10, 3));
    });

    test('updateNickname sends only the nickname with PATCH and returns the new member', () async {
      final adapter = _StubAdapter(200, meBody);

      final member = await MemberApiService(_dio(adapter)).updateNickname('영화광');

      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.uri.path, '/v7/members/me');
      expect(adapter.requests.single.data, {'nickname': '영화광'});
      expect(member.nickname, '영화광');
    });

    test('a non-object result is a StateError', () {
      expect(() => parseMemberInfo('nope'), throwsA(isA<StateError>()));
      expect(
        () => parseMemberInfo({'isSuccess': true, 'code': 'c', 'message': 'm', 'result': null}),
        throwsA(isA<StateError>()),
      );
    });

    test('the 401 codes keep their code so callers can tell none/invalid/expired apart', () async {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        final adapter = _StubAdapter(401, {'isSuccess': false, 'code': code, 'message': 'm', 'result': null});

        Object? caught;
        try {
          await MemberApiService(_dio(adapter)).fetchMe();
        } catch (error) {
          caught = error;
        }

        expect(apiErrorCode(caught! as DioException), code);
        expect(isSessionExpiredError(caught as DioException), isTrue);
      }
    });
  });

  group('RatingApiService writes (v7)', () {
    const ratingResult = {
      'ratingId': 12,
      'movieId': 550,
      'score': 5,
      'comment': '최고',
      'createdAt': '2026-11-14T03:00:00.000Z',
      'updatedAt': '2026-11-14T03:00:00.000Z',
    };

    Map<String, dynamic> ok(int code, Object? result) => {
      'isSuccess': true,
      'code': 'COMMON$code',
      'message': 'ok',
      'result': result,
    };

    test('createRating posts to /v7/ratings with the auth client only, no memberId, and parses the Rating', () async {
      final publicAdapter = _StubAdapter(200, null);
      final authAdapter = _StubAdapter(201, ok(201, ratingResult));
      final service = RatingApiService(_dio(publicAdapter), _dio(authAdapter));

      final rating = await service.createRating(
        const CreateRatingRequest(movieId: 550, score: 5, comment: '최고'),
      );

      final request = authAdapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v7/ratings');
      expect(request.data, {'movieId': 550, 'score': 5, 'comment': '최고'});
      expect(publicAdapter.requests, isEmpty);
      expect(rating.ratingId, 12);
      expect(rating.movieId, 550); // TMDB 영화 id
      expect(rating.updatedAt, DateTime.utc(2026, 11, 14, 3));
    });

    test('createRating throws StateError for a success status other than 201', () async {
      final service = RatingApiService(
        _dio(_StubAdapter(200, null)),
        _dio(_StubAdapter(200, ok(200, ratingResult))),
      );

      await expectLater(
        service.createRating(const CreateRatingRequest(movieId: 550, score: 5)),
        throwsA(isA<StateError>()),
      );
    });

    test('updateRating always sends score and comment and returns the updated Rating', () async {
      final adapter = _StubAdapter(200, ok(200, {...ratingResult, 'score': 4, 'comment': null}));
      final service = RatingApiService(_dio(_StubAdapter(200, null)), _dio(adapter));

      final first = await service.updateRating(ratingId: 3, score: 4, comment: '수정 후기');
      await service.updateRating(ratingId: 3, score: 4);

      expect(adapter.requests.first.method, 'PATCH');
      expect(adapter.requests.first.uri.path, '/v7/ratings/3');
      expect(adapter.requests.first.data, {'score': 4, 'comment': '수정 후기'});
      expect(adapter.requests.last.data, {'score': 4, 'comment': null});
      expect(first.score, 4);
      expect(first.comment, isNull);
    });

    test('deleteRating accepts 200 with result null (not 204) and parses nothing', () async {
      final adapter = _StubAdapter(200, ok(200, null));

      await RatingApiService(_dio(_StubAdapter(200, null)), _dio(adapter)).deleteRating(3);

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.uri.path, '/v7/ratings/3');
    });

    test('deleteRating treats the old v6 204 as an unexpected response', () async {
      final service = RatingApiService(_dio(_StubAdapter(200, null)), _dio(_StubAdapter(204, null)));

      await expectLater(service.deleteRating(3), throwsA(isA<StateError>()));
    });

    test('403 and 404 keep their domain codes and server messages', () async {
      for (final entry in {
        403: ('RATING403_1', '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
        404: ('RATING404_1', '해당 평점을 찾을 수 없습니다.'),
      }.entries) {
        final adapter = _StubAdapter(entry.key, {
          'isSuccess': false,
          'code': entry.value.$1,
          'message': entry.value.$2,
          'result': null,
        });

        Object? caught;
        try {
          await RatingApiService(_dio(_StubAdapter(200, null)), _dio(adapter)).deleteRating(3);
        } catch (error) {
          caught = error;
        }

        final error = caught! as DioException;
        expect(error.response?.statusCode, entry.key);
        expect(apiErrorCode(error), entry.value.$1);
        expect(writeErrorMessage(error), entry.value.$2);
      }
    });

    test('the old v6 result shapes are not accepted as a Rating', () {
      expect(
        () => parseRatingResult({'isSuccess': true, 'code': 'c', 'message': 'm', 'result': 12}),
        throwsA(anything),
      );
      expect(
        () => parseRatingResult({'isSuccess': true, 'code': 'c', 'message': 'm', 'result': null}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
