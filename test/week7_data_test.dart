import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
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

  group('SignUpService (v6)', () {
    test('checks use /v6 paths', () async {
      final nickname = _StubAdapter(200, {'available': true});
      expect(await SignUpService(_dio(nickname)).checkNickname('movielover'), isTrue);
      expect(nickname.requests.single.uri.path, '/v6/members/nickname/movielover');

      final email = _StubAdapter(200, {'available': false});
      expect(await SignUpService(_dio(email)).checkEmail('movie@umc.com'), isFalse);
      expect(email.requests.single.uri.toString(), endsWith('/v6/members/email/movie%40umc.com'));
    });

    test('signUp posts the request body to /v6/members and reads memberId from the result', () async {
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
      expect(request.uri.path, '/v6/members');
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

  group('RatingApiService writes (v6)', () {
    test('createRating posts movieId, score and comment and accepts 201 with any result', () async {
      final adapter = _StubAdapter(201, {
        'isSuccess': true,
        'code': 'COMMON201',
        'message': '평점이 등록되었습니다.',
        'result': null, // Swagger 설명(숫자)과 예시(null)가 달라 파싱하지 않습니다.
      });

      await RatingApiService(_dio(adapter)).createRating(
        memberId: 12,
        request: const CreateRatingRequest(movieId: 550, score: 5, comment: '최고'),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v6/members/12/ratings');
      expect(request.data, {'movieId': 550, 'score': 5, 'comment': '최고'});
    });

    test('createRating throws StateError for a success status other than 201', () async {
      final adapter = _StubAdapter(200, {'isSuccess': true});

      await expectLater(
        RatingApiService(_dio(adapter)).createRating(
          memberId: 12,
          request: const CreateRatingRequest(movieId: 550, score: 5),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('updateRating always sends score and comment, with null when the comment is cleared', () async {
      final adapter = _StubAdapter(200, {
        'isSuccess': true,
        'code': 'COMMON200',
        'message': '수정',
        'result': null,
      });
      final service = RatingApiService(_dio(adapter));

      await service.updateRating(memberId: 12, ratingId: 3, score: 4, comment: '수정 후기');
      await service.updateRating(memberId: 12, ratingId: 3, score: 4);

      expect(adapter.requests.first.method, 'PATCH');
      expect(adapter.requests.first.uri.path, '/v6/members/12/ratings/3');
      expect(adapter.requests.first.data, {'score': 4, 'comment': '수정 후기'});
      expect(adapter.requests.last.data, {'score': 4, 'comment': null});
    });

    test('deleteRating treats 204 without a body as success and never parses JSON', () async {
      final adapter = _StubAdapter(204);

      await RatingApiService(_dio(adapter)).deleteRating(memberId: 12, ratingId: 3);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.path, '/v6/members/12/ratings/3');
    });

    test('deleteRating throws DioException with the common error for 403 and 404', () async {
      for (final entry in {
        403: ('COMMON403', '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
        404: ('COMMON404', '존재하지 않는 평점입니다.'),
      }.entries) {
        final adapter = _StubAdapter(entry.key, {
          'isSuccess': false,
          'code': entry.value.$1,
          'message': entry.value.$2,
          'result': null,
        });

        Object? caught;
        try {
          await RatingApiService(_dio(adapter)).deleteRating(memberId: 12, ratingId: 3);
        } catch (error) {
          caught = error;
        }

        final error = caught! as DioException;
        expect(error.response?.statusCode, entry.key);
        expect(writeErrorMessage(error), entry.value.$2);
        expect(shouldRefreshAfterRatingError(error), isTrue);
      }
    });
  });

  group('shouldRefreshAfterRatingError', () {
    test('only 403 and 404 need a reload; 400 and 409 do not', () {
      expect(shouldRefreshAfterRatingError(commonFailure(403, 'COMMON403', 'x')), isTrue);
      expect(shouldRefreshAfterRatingError(commonFailure(404, 'COMMON404', 'x')), isTrue);
      expect(shouldRefreshAfterRatingError(commonFailure(400, 'COMMON400', 'x')), isFalse);
      expect(shouldRefreshAfterRatingError(commonFailure(409, 'COMMON409', 'x')), isFalse);
      expect(shouldRefreshAfterRatingError(dioFailure('/x')), isFalse);
    });
  });
}
